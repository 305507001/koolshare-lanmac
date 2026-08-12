# LAN MAC 伪装

适用于 KoolShare/KoolCenter 梅林改版、官改 HND/AXHND/AXHND.675x 平台的软件中心插件。

## 当前版本

- 插件版本：1.6
- 发布标签：v1.6.0
- 作者：莫非工作室 无敌权号王

## 主要功能

- 自定义 LAN 网桥 `br0` 的 MAC 地址，重启路由器后生效。
- 自动识别路由器 OUI，固定前三组并随机生成后三组。
- 显示当前 `br0` 及其它 Linux 网桥的 MAC 地址。
- 显示下次重启目标 MAC 和上次重启实际应用的 MAC。
- 保存配置不会立即修改网络，避免中断当前管理连接。
- 不写入 NVRAM，不修改 WAN、无线接口、防火墙或其它插件配置。

## 安装

1. 从 [Releases](https://github.com/305507001/koolshare-lanmac/releases) 下载最新版 `tar.gz` 安装包。
2. 打开路由器软件中心，进入“手动安装”。
3. 上传安装包并完成安装。
4. 打开“LAN MAC 伪装”，随机生成或手工填写 MAC。
5. 开启插件并保存设置，在方便时重启路由器。

开机后插件会等待约 45 秒，再尝试修改 `br0`。建议路由器启动 60～90 秒后刷新页面查看结果。

## 安全范围

插件仅管理以下自身文件和配置：

- `/koolshare/scripts/lanmac_*.sh`
- `/koolshare/init.d/S99lanmac.sh`
- `/koolshare/webs/Module_lanmac.asp`
- `/koolshare/res/icon-lanmac.png`
- `lanmac_*` 和 `softcenter_module_lanmac_*` DBus 配置

其它网桥信息通过 `/sys/class/net` 只读获取，实际 MAC 修改仅针对 `br0`。

## 卸载和恢复

在插件页面关闭功能并保存，然后重启路由器，即可让固件恢复默认 LAN MAC。也可以卸载插件后重启。

## 免责声明

修改 LAN MAC 会导致局域网连接在开机应用时短暂重连。请确保生成的地址没有与局域网中的其它设备冲突，并自行承担使用风险。
