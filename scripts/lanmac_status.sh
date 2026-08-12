#!/bin/sh

source /koolshare/scripts/base.sh

normalize_mac() {
	printf '%s\n' "$1" | tr 'a-f' 'A-F'
}

read_interface_mac() {
	local ADDRESS_FILE="$1"
	local MAC_VALUE

	[ -r "$ADDRESS_FILE" ] || return 1
	MAC_VALUE="$(normalize_mac "$(cat "$ADDRESS_FILE" 2>/dev/null)")"
	printf '%s\n' "$MAC_VALUE" | grep -Eq '^([0-9A-F]{2}:){5}[0-9A-F]{2}$' || return 1
	printf '%s\n' "$MAC_VALUE"
}

CURRENT_BR0=""
OTHER_BRIDGES=""

CURRENT_BR0="$(read_interface_mac /sys/class/net/br0/address 2>/dev/null)"

# 只读取 Linux bridge 的 sysfs 信息，不修改、启停或刷新任何网络接口。
for INTERFACE_PATH in /sys/class/net/*; do
	[ -d "${INTERFACE_PATH}/bridge" ] || continue
	BRIDGE_NAME="${INTERFACE_PATH##*/}"
	[ "$BRIDGE_NAME" = "br0" ] && continue
	printf '%s\n' "$BRIDGE_NAME" | grep -Eq '^[A-Za-z0-9_.:-]{1,15}$' || continue
	BRIDGE_MAC="$(read_interface_mac "${INTERFACE_PATH}/address" 2>/dev/null)" || continue
	if [ -n "$OTHER_BRIDGES" ]; then
		OTHER_BRIDGES="${OTHER_BRIDGES}|"
	fi
	OTHER_BRIDGES="${OTHER_BRIDGES}${BRIDGE_NAME}=${BRIDGE_MAC}"
done

dbus set lanmac_current_br0="$CURRENT_BR0"
dbus set lanmac_other_bridges="$OTHER_BRIDGES"
http_response "网桥 MAC 信息已刷新"
exit 0
