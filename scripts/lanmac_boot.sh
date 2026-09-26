#!/bin/sh

source /koolshare/scripts/base.sh

ENABLE="$(dbus get lanmac_enable)"
MAC="$(dbus get lanmac_mac | tr 'a-f' 'A-F')"
BRIDGE="br0"
TAG="lanmac"
LOCK_DIR="/tmp/lanmac_boot.lock"
# 等待固件跑完 start_wl / lanaccess_wl / start_vlan / start_wan 等开机流程的最长时间（秒）。
BOOT_WAIT_MAX=300
# 开机流程结束后再留出的缓冲时间，避开 acsd、bsd、AiMesh 等守护进程的初始化。
SETTLE_DELAY=20

is_valid_unicast_mac() {
	local value="$1"
	local first_octet
	local first_value

	echo "$value" | grep -Eq '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' || return 1
	[ "$value" != "00:00:00:00:00:00" ] || return 1
	[ "$value" != "FF:FF:FF:FF:FF:FF" ] || return 1

	first_octet="${value%%:*}"
	first_value=$((0x${first_octet}))
	[ $((first_value & 1)) -eq 0 ] || return 1
	return 0
}

read_bridge_mac() {
	[ -r "/sys/class/net/${BRIDGE}/address" ] || return 1
	tr 'a-f' 'A-F' < "/sys/class/net/${BRIDGE}/address"
}

set_bridge_mac() {
	# Linux bridge 支持在 UP 状态下直接改地址，不需要 down/up。
	# 关闭 br0 会让所有有线/无线端口进入 disabled 状态，并清掉 br0 上的 IPv6 地址和非直连路由，
	# 还可能打断绑定在 br0 上的 eapd/nas/hostapd/wlceventd 等无线守护进程。
	if command -v ip >/dev/null 2>&1; then
		ip link set dev "$BRIDGE" address "$1" >/dev/null 2>&1 && return 0
	fi
	ifconfig "$BRIDGE" hw ether "$1" >/dev/null 2>&1
}

wait_boot_ready() {
	local waited=0

	# success_start_service 在 init 跑完整个开机流程后置 1；wlready 在无线就绪后置 1。
	# 个别固件没有 wlready，读到空值时视为已就绪。
	while [ "$waited" -lt "$BOOT_WAIT_MAX" ]; do
		if [ "$(nvram get success_start_service)" = "1" ] && [ "$(nvram get wlready)" != "0" ]; then
			return 0
		fi
		sleep 5
		waited=$((waited + 5))
	done
	return 1
}

announce_new_mac() {
	local lan_ip

	lan_ip="$(nvram get lan_ipaddr)"
	[ -n "$lan_ip" ] || return 0
	command -v arping >/dev/null 2>&1 || return 0
	# 广播免费 ARP，让客户端立即改用新地址，而不是等各自 ARP 缓存过期后陆续切换。
	arping -q -U -c 2 -I "$BRIDGE" "$lan_ip" >/dev/null 2>&1
}

apply_mac() {
	local original_mac
	local applied_mac

	if ! ifconfig "$BRIDGE" >/dev/null 2>&1; then
		logger -t "$TAG" "未找到 LAN 网桥 $BRIDGE，未修改网络"
		dbus set lanmac_last_status="开机应用失败：未找到 LAN 网桥 br0"
		return 1
	fi

	original_mac="$(read_bridge_mac)"
	if [ "$original_mac" = "$MAC" ]; then
		logger -t "$TAG" "LAN 网桥已经使用目标 MAC $MAC，无需重复修改"
		dbus set lanmac_applied_mac="$original_mac"
		dbus set lanmac_last_status="已生效：$MAC"
		return 0
	fi

	if ! set_bridge_mac "$MAC"; then
		logger -t "$TAG" "内核拒绝在线修改 $BRIDGE 地址，未做 down/up，网络未受影响"
		dbus set lanmac_last_status="开机应用失败：无法在线修改 br0 地址（网络未受影响）"
		return 1
	fi

	applied_mac="$(read_bridge_mac)"
	if [ "$applied_mac" != "$MAC" ]; then
		# 读回不一致时恢复原地址，避免停留在未知状态。
		if [ -n "$original_mac" ]; then
			set_bridge_mac "$original_mac"
		fi
		logger -t "$TAG" "修改后读回 ${applied_mac:-未知}，与目标 $MAC 不一致，已尝试恢复 $original_mac"
		dbus remove lanmac_applied_mac
		dbus set lanmac_last_status="开机应用失败：读回 ${applied_mac:-未知}（目标：$MAC），已尝试恢复"
		return 1
	fi

	announce_new_mac
	dbus set lanmac_applied_mac="$applied_mac"
	dbus set lanmac_last_status="已生效：$applied_mac"
	logger -t "$TAG" "LAN 网桥 MAC 已在线修改：$original_mac -> $applied_mac"
	return 0
}

case "$1" in
	stop|kill) exit 0 ;;
esac

[ "$ENABLE" = "1" ] || exit 0

if ! is_valid_unicast_mac "$MAC"; then
	logger -t "$TAG" "拒绝应用无效的 LAN MAC 地址"
	dbus set lanmac_last_status="开机应用失败：MAC 地址无效"
	exit 1
fi

# 软件中心可能在多个时机调用 S* 脚本；同一时间只允许一个应用任务。
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
	logger -t "$TAG" "已有应用任务在运行，跳过本次调用"
	exit 0
fi

# 实验选项（无界面）：dbus set lanmac_apply_early=1 时在当前阶段立即应用，
# 让之后才初始化的无线组件直接看到新地址，用于排查无线兼容性问题。
if [ "$(dbus get lanmac_apply_early)" = "1" ]; then
	apply_mac
	RESULT=$?
	rmdir "$LOCK_DIR" 2>/dev/null
	exit "$RESULT"
fi

# 等固件真正完成开机流程再改，而不是固定 sleep；后台执行，避免阻塞其它开机插件。
(
	trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

	if ! wait_boot_ready; then
		logger -t "$TAG" "等待 ${BOOT_WAIT_MAX} 秒后固件仍未报告开机完成，继续尝试应用"
	fi
	sleep "$SETTLE_DELAY"
	apply_mac
) &

exit 0
