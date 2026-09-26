#!/bin/sh

source /koolshare/scripts/base.sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'

MODEL=""
FW_TYPE_NAME=""
DIR="$(cd "$(dirname "$0")" && pwd)"
module="${DIR##*/}"

get_model() {
	local ODMPID
	local PRODUCTID
	ODMPID="$(nvram get odmpid)"
	PRODUCTID="$(nvram get productid)"
	if [ -n "$ODMPID" ]; then
		MODEL="$ODMPID"
	else
		MODEL="$PRODUCTID"
	fi
}

get_fw_type() {
	local KS_TAG
	KS_TAG="$(nvram get extendno | grep koolshare)"
	if [ -n "$KS_TAG" ]; then
		FW_TYPE_NAME="koolshare官改固件"
	else
		FW_TYPE_NAME="koolshare梅林改版固件"
	fi
}

exit_install() {
	local state="$1"
	case "$state" in
		1)
			echo_date "本插件适用于【koolshare 梅林改/官改 hnd/axhnd/axhnd.675x】固件平台！"
			echo_date "当前固件平台不符合安装要求，退出安装！"
			rm -rf "/tmp/${module}"
			exit 1
			;;
		*)
			rm -rf "/tmp/${module}"
			exit 0
			;;
	esac
}

platform_test() {
	local LINUX_VER
	LINUX_VER="$(uname -r | awk -F'.' '{print $1$2}')"
	if [ -d /koolshare ] && [ -f /usr/bin/skipd ] && [ "$LINUX_VER" -ge 41 ] 2>/dev/null; then
		echo_date "机型：${MODEL} ${FW_TYPE_NAME} 符合安装要求，开始安装插件！"
	else
		exit_install 1
	fi
}

normalize_mac() {
	printf '%s\n' "$1" | tr 'a-f' 'A-F'
}

is_valid_unicast_mac() {
	local MAC_VALUE
	MAC_VALUE="$(normalize_mac "$1")"

	printf '%s\n' "$MAC_VALUE" | grep -Eq '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' || return 1
	[ "$MAC_VALUE" = "00:00:00:00:00:00" ] && return 1
	[ "$MAC_VALUE" = "FF:FF:FF:FF:FF:FF" ] && return 1
	case "$MAC_VALUE" in
		?[13579BDF]:*) return 1 ;;
	esac
	return 0
}

detect_router_oui() {
	local CANDIDATE
	local SAVED_OUI

	# lan_hwaddr 由固件在 start_lan 时按 br0 实际地址写入，插件在其后才修改 br0，
	# 所以这里读到的仍是原始地址；et0macaddr 是出厂基础 MAC。优先读取它们，
	# 避免 br0 已被旧配置修改时误把伪装地址当作原始 OUI。
	for CANDIDATE in "$(nvram get lan_hwaddr 2>/dev/null)" "$(nvram get et0macaddr 2>/dev/null)"; do
		CANDIDATE="$(normalize_mac "$CANDIDATE")"
		if is_valid_unicast_mac "$CANDIDATE"; then
			printf '%s\n' "$CANDIDATE" | cut -d: -f1-3
			return 0
		fi
	done

	# 升级时保留此前可靠识别的 OUI；最后才回退到当前 br0 地址。
	SAVED_OUI="$(dbus get lanmac_oui 2>/dev/null | tr 'a-f' 'A-F')"
	if printf '%s\n' "$SAVED_OUI" | grep -Eq '^([0-9A-F]{2}:){2}[0-9A-F]{2}$'; then
		case "$SAVED_OUI" in
			?[13579BDF]:*) ;;
			*) printf '%s\n' "$SAVED_OUI"; return 0 ;;
		esac
	fi

	if [ -r /sys/class/net/br0/address ]; then
		CANDIDATE="$(normalize_mac "$(cat /sys/class/net/br0/address 2>/dev/null)")"
		if is_valid_unicast_mac "$CANDIDATE"; then
			printf '%s\n' "$CANDIDATE" | cut -d: -f1-3
			return 0
		fi
	fi

	return 1
}

install_now() {
	local TITLE="LAN MAC 伪装"
	local DESCR="保留路由器 OUI，随机或自定义 LAN MAC，并显示网桥当前与重启后状态"
	local PLVER="1.6.1"
	local ROUTER_OUI

	# 仅移除本插件自己的启动项，避免影响其它插件或系统服务。
	rm -f /koolshare/init.d/S99lanmac.sh

	echo_date "安装插件相关文件..."
	cp -f "${DIR}/scripts/lanmac_boot.sh" /koolshare/scripts/lanmac_boot.sh || exit_install 1
	cp -f "${DIR}/scripts/lanmac_config.sh" /koolshare/scripts/lanmac_config.sh || exit_install 1
	cp -f "${DIR}/scripts/lanmac_status.sh" /koolshare/scripts/lanmac_status.sh || exit_install 1
	cp -f "${DIR}/webs/Module_lanmac.asp" /koolshare/webs/Module_lanmac.asp || exit_install 1
	cp -f "${DIR}/res/icon-lanmac.png" /koolshare/res/icon-lanmac.png || exit_install 1
	cp -f "${DIR}/uninstall.sh" /koolshare/scripts/uninstall_lanmac.sh || exit_install 1

	chmod 755 /koolshare/scripts/lanmac_boot.sh
	chmod 755 /koolshare/scripts/lanmac_config.sh
	chmod 755 /koolshare/scripts/lanmac_status.sh
	chmod 755 /koolshare/scripts/uninstall_lanmac.sh
	chmod 644 /koolshare/webs/Module_lanmac.asp
	chmod 644 /koolshare/res/icon-lanmac.png

	echo_date "设置插件参数..."
	if ROUTER_OUI="$(detect_router_oui)"; then
		dbus set lanmac_oui="$ROUTER_OUI"
		echo_date "已识别路由器 OUI：${ROUTER_OUI}（仅供随机生成，不写入 NVRAM）"
	else
		dbus remove lanmac_oui
		echo_date "未能可靠识别路由器 OUI，随机生成功能将保持禁用，仍可手工填写 MAC。"
	fi
	dbus set lanmac_version="$PLVER"
	dbus set softcenter_module_lanmac_version="$PLVER"
	dbus set softcenter_module_lanmac_install="1"
	dbus set softcenter_module_lanmac_name="lanmac"
	dbus set softcenter_module_lanmac_title="$TITLE"
	dbus set softcenter_module_lanmac_description="$DESCR"
	dbus set softcenter_module_lanmac_author="莫非工作室 无敌权号王"
	dbus set softcenter_module_lanmac_tags="系统 工具"

	# 保留升级前的启用状态；配置脚本只校验参数并管理本插件自己的软链接。
	if [ "$(dbus get lanmac_enable)" = "1" ]; then
		if ! sh /koolshare/scripts/lanmac_config.sh >/dev/null 2>&1; then
			echo_date "检测到旧配置中的 MAC 无效，已安全关闭插件，请重新填写。"
		fi
	fi

	echo_date "${TITLE} v${PLVER} 安装完毕！"
	echo_date "插件不会立即修改网络；启用后将在下次重启路由器时生效。"
	exit_install 0
}

get_model
get_fw_type
platform_test
install_now
