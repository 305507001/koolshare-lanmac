<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge" />
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache" />
<meta HTTP-EQUIV="Expires" CONTENT="-1" />
<link rel="shortcut icon" href="images/favicon.png" />
<link rel="icon" href="images/favicon.png" />
<title>软件中心 - LAN MAC 伪装</title>
<link rel="stylesheet" type="text/css" href="index_style.css" />
<link rel="stylesheet" type="text/css" href="form_style.css" />
<link rel="stylesheet" type="text/css" href="usp_style.css" />
<link rel="stylesheet" type="text/css" href="/res/softcenter.css" />
<script type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script type="text/javascript" src="/res/softcenter.js"></script>
<style type="text/css">
.lanmac-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    min-height: 58px;
}
.lanmac-title-wrap {
    display: flex;
    align-items: center;
}
.lanmac-icon {
    width: 48px;
    height: 48px;
    margin-right: 12px;
}
.lanmac-subtitle {
    color: #c7d2d8;
    font-size: 13px;
    margin-top: 5px;
}
.lanmac-return {
    border: 1px solid #7c8a90;
    border-radius: 4px;
    background: #303b40;
    color: #fff;
    cursor: pointer;
    padding: 7px 14px;
    font-size: 14px;
}
.lanmac-return:hover {
    background: #1f2a2f;
}
.lanmac-divider {
    height: 1px;
    background: #738087;
    margin: 8px 5px 14px 5px;
    opacity: .8;
}
.lanmac-input {
    width: 250px;
    text-transform: uppercase;
}
.lanmac-random {
    min-width: 104px;
    margin-left: 8px;
    vertical-align: middle;
}
.lanmac-random:disabled {
    cursor: not-allowed;
    opacity: .55;
}
.lanmac-hint {
    color: #c7d2d8;
    font-size: 12px;
    margin: 7px 0 0 2px;
}
.lanmac-status {
    line-height: 1.7;
    word-break: break-all;
}
.lanmac-bridge-list {
    margin: 2px 0 7px 0;
}
.lanmac-refresh {
    margin-top: 5px;
    min-width: 120px;
}
.lanmac-note {
    margin: 16px 5px 4px 5px;
    padding: 12px 14px;
    border: 1px solid #6b8fa3;
    background: rgba(0, 0, 0, .12);
    line-height: 1.8;
}
.lanmac-note h3 {
    margin: 0 0 5px 0;
    font-size: 15px;
}
.lanmac-note ul {
    margin: 0;
    padding-left: 22px;
}
.lanmac-author {
    margin: 24px 5px 6px 5px;
    padding-top: 14px;
    border-top: 1px solid #738087;
    color: #fff;
    font-size: 14px;
    text-align: right;
}
.lanmac-author span {
    color: #ffcc00;
}
#lanmac_enable {
    width: 21px;
    height: 21px;
    vertical-align: middle;
}
</style>
<script type="text/javascript">
var lanmacDbus = {};
var lanmacPageInitialized = false;
var lanmacLoadSerial = 0;

function menu_hook(title, tab) {
    tabtitle[tabtitle.length - 1] = new Array("", "LAN MAC 伪装");
    tablink[tablink.length - 1] = new Array("", "Module_lanmac.asp");
}

function reloadSoftCenter() {
    window.location.href = "/Module_Softcenter.asp";
}

function normalizeMac(value) {
    return $.trim(value || "").replace(/-/g, ":").toUpperCase();
}

function normalizeOui(value) {
    return $.trim(value || "").replace(/-/g, ":").toUpperCase();
}

function isValidOui(value) {
    var oui = normalizeOui(value);
    if (!/^([0-9A-F]{2}:){2}[0-9A-F]{2}$/.test(oui)) {
        return false;
    }
    return (parseInt(oui.substring(0, 2), 16) & 1) === 0;
}

function randomByte() {
    var values;
    if (window.crypto && window.crypto.getRandomValues && typeof Uint8Array !== "undefined") {
        values = new Uint8Array(1);
        window.crypto.getRandomValues(values);
        return values[0];
    }
    return Math.floor(Math.random() * 256);
}

function byteToHex(value) {
    var hex = value.toString(16).toUpperCase();
    return hex.length === 1 ? "0" + hex : hex;
}

function generateRandomMacValue(oui) {
    var normalizedOui = normalizeOui(oui);
    if (!isValidOui(normalizedOui)) {
        return "";
    }
    return normalizedOui + ":" + byteToHex(randomByte()) + ":" + byteToHex(randomByte()) + ":" + byteToHex(randomByte());
}

function generateRandomMac() {
    var oui = normalizeOui(lanmacDbus["lanmac_oui"]);
    var current = normalizeMac($("#lanmac_mac").val());
    var generated = "";
    var attempts;

    if (!isValidOui(oui)) {
        alert("未能可靠识别路由器 OUI，无法自动生成。你仍可手工填写有效的单播 MAC 地址。");
        return;
    }

    for (attempts = 0; attempts < 8; attempts++) {
        generated = generateRandomMacValue(oui);
        if (generated !== current) {
            break;
        }
    }
    if (generated === current) {
        generated = generated.substring(0, 15) + byteToHex((parseInt(generated.substring(15, 17), 16) + 1) % 256);
    }

    $("#lanmac_mac").val(generated).focus();
    $("#lanmac_generate_hint").text("已生成新地址，仅填入输入框；点击“保存设置”后才会保存，重启后生效。");
}

function validateMac(value) {
    if (!/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/.test(value)) {
        return "MAC 地址格式不正确，应为 XX:XX:XX:XX:XX:XX";
    }
    if (value === "00:00:00:00:00:00" || value === "FF:FF:FF:FF:FF:FF") {
        return "不能使用全零地址或广播地址";
    }
    if ((parseInt(value.substring(0, 2), 16) & 1) !== 0) {
        return "不能使用组播 MAC 地址，请使用单播地址";
    }
    return "";
}

function renderState() {
    var enabled = lanmacDbus["lanmac_enable"] === "1";
    var savedMac = normalizeMac(lanmacDbus["lanmac_mac"]);
    var status = lanmacDbus["lanmac_last_status"] || (enabled ? "配置已启用，等待路由器重启后生效" : "插件未启用");
    var version = lanmacDbus["lanmac_version"] || "1.6";
    var oui = normalizeOui(lanmacDbus["lanmac_oui"]);
    var ouiAvailable = isValidOui(oui);
    var currentBr0 = normalizeMac(lanmacDbus["lanmac_current_br0"]);
    var appliedMac = normalizeMac(lanmacDbus["lanmac_applied_mac"]);
    var nextBootMac;

    if (!enabled) {
        nextBootMac = "插件已关闭，重启后由固件使用默认地址";
    } else if (!validateMac(savedMac)) {
        nextBootMac = savedMac;
    } else {
        nextBootMac = "已启用，但保存的 MAC 无效";
    }

    $("#lanmac_enable").prop("checked", enabled);
    if (lanmacDbus["lanmac_mac"]) {
        $("#lanmac_mac").val(normalizeMac(lanmacDbus["lanmac_mac"]));
    }
    $("#lanmac_saved").text(savedMac || "未设置");
    $("#lanmac_status").text(status);
    $("#lanmac_version").text(version);
    $("#lanmac_oui").text(ouiAvailable ? oui : "未识别（随机功能不可用）");
    $("#random_btn").prop("disabled", !ouiAvailable);
    $("#lanmac_current_br0").text(!validateMac(currentBr0) ? currentBr0 : "未读取到");
    $("#lanmac_next_boot").text(nextBootMac);
    $("#lanmac_applied_mac").text(!validateMac(appliedMac) ? appliedMac : "尚无成功启动记录");
    renderOtherBridges(lanmacDbus["lanmac_other_bridges"] || "");
}

function renderOtherBridges(rawValue) {
    var container = $("#lanmac_other_bridges");
    var entries = rawValue ? rawValue.split("|") : [];
    var validCount = 0;
    var index;
    var separator;
    var name;
    var mac;

    container.empty();
    for (index = 0; index < entries.length; index++) {
        separator = entries[index].indexOf("=");
        if (separator <= 0) {
            continue;
        }
        name = entries[index].substring(0, separator);
        mac = normalizeMac(entries[index].substring(separator + 1));
        if (!/^[A-Za-z0-9_.:-]{1,15}$/.test(name) || validateMac(mac)) {
            continue;
        }
        $("<div></div>").text(name + "：" + mac).appendTo(container);
        validCount++;
    }
    if (!validCount) {
        container.text("未发现其它 Linux 网桥");
    }
}

function renderLoadFailure() {
    $("#lanmac_current_br0").text("读取失败");
    $("#lanmac_other_bridges").text("读取失败");
    $("#lanmac_oui").text("读取失败（随机功能不可用）");
    $("#lanmac_saved").text("读取失败");
    $("#lanmac_next_boot").text("读取失败");
    $("#lanmac_applied_mac").text("读取失败");
    $("#lanmac_status").text("读取插件配置失败，请稍后重试");
    $("#random_btn").prop("disabled", true);
}

function loadConfig(retryCount) {
    var serial = ++lanmacLoadSerial;
    var retries = typeof retryCount === "number" ? retryCount : 0;

    $.ajax({
        type: "GET",
        url: "/_api/lanmac_?_=" + new Date().getTime(),
        dataType: "json",
        cache: false,
        timeout: 5000,
        success: function(data) {
            if (serial !== lanmacLoadSerial) {
                return;
            }
            if (data && data.result && data.result.length > 0) {
                lanmacDbus = data.result[0] || {};
            } else if (retries < 4) {
                window.setTimeout(function() {
                    loadConfig(retries + 1);
                }, 350);
                return;
            } else {
                renderLoadFailure();
                return;
            }
            renderState();
        },
        error: function() {
            if (serial !== lanmacLoadSerial) {
                return;
            }
            if (retries < 4) {
                window.setTimeout(function() {
                    loadConfig(retries + 1);
                }, 350);
                return;
            }
            renderLoadFailure();
        }
    });
}

function refreshBridgeInfo(silent) {
    var postData = {
        "id": parseInt(Math.random() * 100000000, 10),
        "method": "lanmac_status.sh",
        "params": ["start"],
        "fields": {}
    };

    $("#refresh_bridge_btn").val("读取中...").prop("disabled", true);
    $.ajax({
        type: "POST",
        url: "/_api/",
        data: JSON.stringify(postData),
        dataType: "json",
        timeout: 5000,
        error: function() {
            if (!silent) {
                alert("读取网桥 MAC 失败；这不会影响插件配置或当前网络。");
            }
        },
        complete: function() {
            $("#refresh_bridge_btn").val("刷新网桥信息").prop("disabled", false);
            // 无论只读状态脚本是否正常返回，都继续读取 DBus，避免页面停在“读取中”。
            loadConfig(0);
        }
    });
}

function init() {
    if (lanmacPageInitialized) {
        return;
    }
    show_menu(menu_hook);
    lanmacPageInitialized = true;
    // 此固件首次直接读取 DBus 偶尔会悬住；先执行只读状态脚本，再统一读取配置。
    refreshBridgeInfo(true);
}

if (document.addEventListener) {
    document.addEventListener("DOMContentLoaded", init, false);
}

if (window.addEventListener) {
    window.addEventListener("pageshow", function(event) {
        if (!lanmacPageInitialized) {
            init();
            return;
        }
        if (event && event.persisted) {
            refreshBridgeInfo(true);
        }
    });
}

function save() {
    var enabled = $("#lanmac_enable").prop("checked");
    var mac = normalizeMac($("#lanmac_mac").val());
    var errorText = mac ? validateMac(mac) : "";

    $("#lanmac_mac").val(mac);

    if (enabled && !mac) {
        alert("启用插件前必须填写 MAC 地址。");
        $("#lanmac_mac").focus();
        return;
    }
    if (enabled && errorText) {
        alert(errorText + "。");
        $("#lanmac_mac").focus();
        return;
    }
    // 即使旧版本中保存了损坏的值，也必须允许用户关闭插件。
    if (!enabled && errorText) {
        mac = "";
        $("#lanmac_mac").val("");
    }

    var dbusData = {
        "lanmac_enable": enabled ? "1" : "0",
        "lanmac_mac": mac
    };
    var postData = {
        "id": parseInt(Math.random() * 100000000, 10),
        "method": "lanmac_config.sh",
        "params": ["start"],
        "fields": dbusData
    };

    $("#save_btn").val("保存中...").prop("disabled", true);

    $.ajax({
        type: "POST",
        url: "/_api/",
        data: JSON.stringify(postData),
        dataType: "json",
        timeout: 12000,
        success: function() {
            if (enabled) {
                alert("配置已保存。为了避免中断当前管理连接，插件不会立即修改网络；请在方便时重启路由器使其生效。");
            } else {
                alert("插件已关闭，开机启动项已移除；当前网络不会被立即更改。");
            }
            window.setTimeout(function() {
                refreshBridgeInfo(true);
            }, 250);
        },
        error: function() {
            alert("保存请求未正常返回。页面将重新读取实际配置，请根据“已保存”和“状态”确认结果。");
            window.setTimeout(function() {
                refreshBridgeInfo(true);
            }, 250);
        },
        complete: function() {
            $("#save_btn").val("保存设置").prop("disabled", false);
        }
    });
}
</script>
</head>
<body onload="init();">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
<table class="content" align="center" cellpadding="0" cellspacing="0">
    <tr>
        <td width="17">&nbsp;</td>
        <td valign="top" width="202">
            <div id="mainMenu"></div>
            <div id="subMenu"></div>
        </td>
        <td valign="top">
            <div id="tabMenu" class="submenuBlock"></div>
            <table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
                <tr>
                    <td align="left" valign="top">
                        <table width="760px" border="0" cellpadding="5" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
                            <tr>
                                <td bgcolor="#4D595D" colspan="3" valign="top">
                                    <div class="lanmac-header">
                                        <div class="lanmac-title-wrap">
                                            <img class="lanmac-icon" src="/res/icon-lanmac.png" alt="LAN MAC 伪装" />
                                            <div>
                                                <div class="formfonttitle">LAN MAC 伪装</div>
                                                <div class="lanmac-subtitle">安全地自定义 LAN 网桥 MAC，重启后生效</div>
                                            </div>
                                        </div>
                                        <button type="button" class="lanmac-return" onclick="reloadSoftCenter();" title="返回软件中心">&#8592; 返回软件中心</button>
                                    </div>
                                    <div class="lanmac-divider"></div>
                                    <table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
                                        <tr>
                                            <th>开启插件功能</th>
                                            <td>
                                                <input type="checkbox" id="lanmac_enable" />
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>自定义 LAN 口 MAC</th>
                                            <td>
                                                <input type="text" class="input_ss_table lanmac-input" id="lanmac_mac" maxlength="17" autocomplete="off" spellcheck="false" placeholder="例如: 02:11:22:3F:8D:1E" />
                                                <input type="button" class="button_gen lanmac-random" id="random_btn" onclick="generateRandomMac();" value="随机后三组" disabled="disabled" />
                                                <div class="lanmac-hint" id="lanmac_generate_hint">随机功能固定保留本路由器 OUI（前三组），只随机后三组；也可继续手工填写标准单播 MAC。</div>
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>当前网桥 MAC</th>
                                            <td class="lanmac-status">
                                                <div>br0：<span id="lanmac_current_br0">读取中...</span></div>
                                                <div>其它网桥：</div>
                                                <div class="lanmac-bridge-list" id="lanmac_other_bridges">读取中...</div>
                                                <input type="button" class="button_gen lanmac-refresh" id="refresh_bridge_btn" onclick="refreshBridgeInfo(false);" value="刷新网桥信息" />
                                            </td>
                                        </tr>
                                        <tr>
                                            <th>插件状态</th>
                                            <td class="lanmac-status">
                                                <div>版本：<span id="lanmac_version">1.6</span></div>
                                                <div>路由器 OUI：<span id="lanmac_oui">读取中...</span></div>
                                                <div>已保存：<span id="lanmac_saved">读取中...</span></div>
                                                <div>下次重启目标：<span id="lanmac_next_boot">读取中...</span></div>
                                                <div>上次重启实际应用：<span id="lanmac_applied_mac">读取中...</span></div>
                                                <div>状态：<span id="lanmac_status">读取中...</span></div>
                                            </td>
                                        </tr>
                                    </table>
                                    <div class="apply_gen">
                                        <input class="button_gen" id="save_btn" type="button" onclick="save();" value="保存设置" />
                                    </div>
                                    <div class="lanmac-note">
                                        <h3>使用说明</h3>
                                        <ul>
                                            <li>保存设置不会立即重启或修改网络，不影响当前管理连接。</li>
                                            <li>“随机后三组”只填充输入框，不会自动保存或立即应用；前三组使用安装时识别到的路由器 OUI。</li>
                                            <li>网桥信息来自 Linux 的 /sys/class/net，只读取当前地址；刷新操作不会启停或修改任何网桥。</li>
                                            <li>启用后仅在下次路由器启动时修改 LAN 网桥 br0，不改 WAN、无线接口或其它插件配置。</li>
                                            <li>启动应用时 LAN 会短暂重连；若网桥不存在或 MAC 无效，插件会停止操作并记录状态。</li>
                                            <li>请确保所填地址未被局域网内其它设备使用，以免发生 MAC 冲突。</li>
                                        </ul>
                                    </div>
                                    <div class="lanmac-author">作者声明：<span>莫非工作室&nbsp;&nbsp;无敌权号王</span></div>
                                </td>
                            </tr>
                        </table>
                    </td>
                    <td width="10" align="center" valign="top"></td>
                </tr>
            </table>
        </td>
    </tr>
</table>
<div id="footer"></div>
</body>
</html>
