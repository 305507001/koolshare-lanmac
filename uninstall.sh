#!/bin/sh

# 仅删除 LAN MAC 插件明确拥有的文件和配置。
rm -f /koolshare/init.d/S99lanmac.sh
rm -f /koolshare/scripts/lanmac_boot.sh
rm -f /koolshare/scripts/lanmac_config.sh
rm -f /koolshare/scripts/lanmac_status.sh
rm -f /koolshare/scripts/uninstall_lanmac.sh
rm -f /koolshare/webs/Module_lanmac.asp
rm -f /koolshare/res/icon-lanmac.png

dbus remove lanmac_enable
dbus remove lanmac_mac
dbus remove lanmac_oui
dbus remove lanmac_version
dbus remove lanmac_last_status
dbus remove lanmac_current_br0
dbus remove lanmac_other_bridges
dbus remove lanmac_applied_mac
dbus remove softcenter_module_lanmac_install
dbus remove softcenter_module_lanmac_name
dbus remove softcenter_module_lanmac_title
dbus remove softcenter_module_lanmac_description
dbus remove softcenter_module_lanmac_version
dbus remove softcenter_module_lanmac_author
dbus remove softcenter_module_lanmac_tags
