#!/bin/sh

source /koolshare/scripts/base.sh

ENABLE="$(dbus get lanmac_enable)"
MAC="$(dbus get lanmac_mac | tr 'a-f' 'A-F')"
BRIDGE="br0"
TAG="lanmac"

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

[ "$ENABLE" = "1" ] || exit 0

if ! is_valid_unicast_mac "$MAC"; then
	logger -t "$TAG" "拒绝应用无效的 LAN MAC 地址"
	dbus set lanmac_last_status="开机应用失败：MAC 地址无效"
	exit 1
fi

if ! ifconfig "$BRIDGE" >/dev/null 2>&1; then
	logger -t "$TAG" "未找到 LAN 网桥 $BRIDGE，未修改网络"
	dbus set lanmac_last_status="开机应用失败：未找到 LAN 网桥 br0"
	exit 1
fi

# 让固件先完成网络初始化；后台执行，避免阻塞其它开机插件。
(
	sleep 45
	ORIGINAL_MAC=""

	if ! ifconfig "$BRIDGE" >/dev/null 2>&1; then
		logger -t "$TAG" "等待后仍未找到 LAN 网桥 $BRIDGE，未修改网络"
		dbus set lanmac_last_status="开机应用失败：未找到 LAN 网桥 br0"
		exit 1
	fi

	if [ -r "/sys/class/net/${BRIDGE}/address" ]; then
		ORIGINAL_MAC="$(tr 'a-f' 'A-F' < "/sys/class/net/${BRIDGE}/address")"
	fi
	if [ "$ORIGINAL_MAC" = "$MAC" ]; then
		logger -t "$TAG" "LAN 网桥已经使用目标 MAC $MAC，无需重复修改"
		dbus set lanmac_applied_mac="$ORIGINAL_MAC"
		dbus set lanmac_last_status="已生效：$MAC"
		exit 0
	fi

	if ! ifconfig "$BRIDGE" down; then
		logger -t "$TAG" "无法关闭 $BRIDGE，未修改 MAC"
		dbus set lanmac_last_status="开机应用失败：无法临时关闭 br0"
		exit 1
	fi

	if ifconfig "$BRIDGE" hw ether "$MAC"; then
		if ifconfig "$BRIDGE" up; then
			APPLIED_MAC=""
			if [ -r "/sys/class/net/${BRIDGE}/address" ]; then
				APPLIED_MAC="$(tr 'a-f' 'A-F' < "/sys/class/net/${BRIDGE}/address")"
			fi
			if is_valid_unicast_mac "$APPLIED_MAC"; then
				dbus set lanmac_applied_mac="$APPLIED_MAC"
				if [ "$APPLIED_MAC" = "$MAC" ]; then
					dbus set lanmac_last_status="已生效：$APPLIED_MAC"
				else
					dbus set lanmac_last_status="执行后读取：$APPLIED_MAC（目标：$MAC）"
				fi
			else
				dbus remove lanmac_applied_mac
				dbus set lanmac_last_status="已执行目标 MAC：$MAC；实际地址读取失败"
			fi
			logger -t "$TAG" "LAN 网桥 MAC 已应用，目标 $MAC，读取值 ${APPLIED_MAC:-未知}"
			exit 0
		fi
	fi

	# 失败时优先恢复原 MAC，再尝试拉起 LAN 网桥。
	if [ -n "$ORIGINAL_MAC" ]; then
		ifconfig "$BRIDGE" hw ether "$ORIGINAL_MAC" >/dev/null 2>&1
	fi
	ifconfig "$BRIDGE" up >/dev/null 2>&1
	logger -t "$TAG" "应用 LAN MAC 失败，已尝试恢复 $BRIDGE"
	dbus set lanmac_last_status="开机应用失败：已尝试恢复 br0"
	exit 1
) &

exit 0
