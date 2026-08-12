#!/bin/sh

source /koolshare/scripts/base.sh

ENABLE="$(dbus get lanmac_enable)"
MAC="$(dbus get lanmac_mac | tr 'a-f' 'A-F')"

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

if [ "$ENABLE" = "1" ]; then
	if ! is_valid_unicast_mac "$MAC"; then
		dbus set lanmac_enable="0"
		dbus set lanmac_last_status="配置未启用：MAC 地址无效"
		rm -f /koolshare/init.d/S99lanmac.sh
		http_response "配置未启用：MAC 地址无效"
		exit 1
	fi

	dbus set lanmac_mac="$MAC"
	if ln -sf /koolshare/scripts/lanmac_boot.sh /koolshare/init.d/S99lanmac.sh; then
		dbus set lanmac_last_status="配置已保存，等待路由器重启后生效"
		http_response "配置已保存，等待路由器重启后生效"
		exit 0
	fi

	dbus set lanmac_enable="0"
	dbus set lanmac_last_status="保存失败：无法创建启动项"
	rm -f /koolshare/init.d/S99lanmac.sh
	http_response "保存失败：无法创建启动项"
	exit 1
fi

rm -f /koolshare/init.d/S99lanmac.sh
dbus set lanmac_last_status="插件已关闭；当前 MAC 不会被立即更改"
http_response "插件已关闭；当前 MAC 不会被立即更改"
exit 0
