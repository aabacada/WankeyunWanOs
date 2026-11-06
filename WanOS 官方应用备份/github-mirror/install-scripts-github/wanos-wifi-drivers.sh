#!/bin/sh
set -eu

ROOT="${WANOS_WIFI_DRIVER_ROOT:-/opt/wanos/components/wifi-drivers}"
DB="$ROOT/driver-db.json"
HELPER="/usr/local/bin/wanos-wifi-driver-scan"
APP_ID="wanos-wifi-drivers"
APP_DIR="${WANOS_APP_INSTALL_ROOT:-/opt/wanos/apps/$APP_ID}"
DATA_DIR="${WANOS_APP_DATA_ROOT:-/opt/wanos-data/apps/$APP_ID}"
PANEL_PORT="${WANOS_WIFI_DRIVERS_PANEL_PORT:-18321}"
PANEL_SERVICE="wanos-wifi-drivers-panel"
ICON_URL="${WANOS_WIFI_DRIVERS_ICON_URL:-https://github.com/aabacada/wankeyunwanos/releases/download/wanos-armv7-20261106/wanos-wifi-drivers.png}"
PKG_URL="${WANOS_APP_PACKAGE_URL:-${WANOS_WIFI_DRIVERS_PACKAGE_URL:-}}"
PKG_SHA="${WANOS_APP_PACKAGE_SHA256:-${WANOS_WIFI_DRIVERS_PACKAGE_SHA256:-}}"

mkdir -p "$ROOT" "$APP_DIR" "$DATA_DIR"

download_file() {
  url="$1"
  out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --connect-timeout 20 --max-time 900 --retry 3 -o "$out" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$out" "$url"
  else
    echo "[WanOS WiFi] missing curl/wget"
    return 1
  fi
}

verify_sha256() {
  file="$1"
  want="$2"
  [ -n "$want" ] || return 0
  got="$(sha256sum "$file" | awk '{print $1}')"
  [ "$got" = "$want" ] || {
    echo "[WanOS WiFi] package sha256 mismatch: want $want got $got"
    return 1
  }
}

load_modules() {
  for mod in \
    cfg80211 mac80211 rfkill \
    rt2x00lib rt2x00usb rt2800lib rt2800usb mt7601u mt76 mt76x0u mt76x2u mt7921u \
    rtl8xxxu r8188eu rtl8188eu rtl8188fu 8188eu 8188fu rtl8192eu 8192eu 8192fu 8811cu 8812au 8814au 8814bu 8821au 8821cu 88x2bu 8852bu \
    rtw88_usb rtw88_8821au rtw88_8822bu rtw89_8852bu \
    aic8800_bsp aic_load_fw aic8800_fdrv aic8800_fdrv_usb \
    ath9k_htc ath10k_usb brcmfmac
  do
    modprobe "$mod" >/dev/null 2>&1 || true
  done
}

if [ -n "$PKG_URL" ]; then
  WORK_BASE="${WANOS_COMPONENT_WORK_DIR:-}"
  if [ -z "$WORK_BASE" ]; then
    if [ -d /opt/wanos-data ]; then
      WORK_BASE="/opt/wanos-data/tmp"
    elif [ -d /mnt/wanos/mmcblk0p1-tf ]; then
      WORK_BASE="/mnt/wanos/mmcblk0p1-tf/.wanos/tmp"
    else
      WORK_BASE="/tmp"
    fi
  fi
  mkdir -p "$WORK_BASE"
  WORK="$(mktemp -d "$WORK_BASE/wanos-wifi-drivers.XXXXXX")"
  trap 'rm -rf "$WORK"' EXIT
  PKG="$WORK/package.tar.gz"
  echo "[WanOS WiFi] download driver package: $PKG_URL"
  if download_file "$PKG_URL" "$PKG"; then
    verify_sha256 "$PKG" "$PKG_SHA"
    mkdir -p "$WORK/extract"
    tar -xzf "$PKG" -C "$WORK/extract"
    if [ -x "$WORK/extract/install.sh" ]; then
      WANOS_WIFI_DRIVER_ROOT="$ROOT" sh "$WORK/extract/install.sh"
    elif [ -d "$WORK/extract/rootfs" ]; then
      cp -a "$WORK/extract/rootfs/." /
    else
      cp -a "$WORK/extract/." "$ROOT/"
    fi
  else
    echo "[WanOS WiFi] WARN: driver package unavailable, using kernel built-in modules only"
  fi
fi

cat >"$DB" <<'JSON'
{
  "version": "2026.07.09-6",
  "families": [
    {
      "name": "Ralink/MediaTek RT3070/RT3370/RT5370/RT5372",
      "vendors": ["148f", "0e8d"],
      "modules": ["rt2800usb", "rt2x00usb", "rt2x00lib"],
      "note": "Prefer kernel rt2800usb when available"
    },
    {
      "name": "MediaTek MT7601/MT7610/MT7612/MT7921",
      "vendors": ["148f", "0e8d"],
      "usb_ids": ["148f:6370", "148f:6570", "148f:7601", "148f:7650"],
      "modules": ["mt7601u", "mt76x0u", "mt76x2u", "mt7921u"]
    },
    {
      "name": "Realtek USB WiFi",
      "vendors": ["0bda", "2357", "2c4e"],
      "modules": ["rtl8xxxu", "r8188eu", "rtl8188eu", "rtl8188fu", "rtl8192eu", "8192eu", "8192fu", "8811cu", "8812au", "8814au", "8814bu", "8821au", "8821cu", "88x2bu", "8852bu", "rtw88_usb", "rtw88_8821au", "rtw88_8822bu", "rtw89_8852bu"]
    },
    {
      "name": "Netcore USB WiFi",
      "vendors": ["0e12"],
      "modules": ["rtl8xxxu", "rtl8192eu", "8192eu", "8192fu", "8811cu", "8814au", "8814bu", "8821cu", "aic8800_bsp", "aic_load_fw", "aic8800_fdrv", "aic8800_fdrv_usb"],
      "usb_ids": ["0e12:*", "a69c:8800", "a69c:8801", "368b:8d90", "368b:8d91"]
    },
    {
      "name": "MERCURY/Mercusys UX/UD/MW USB WiFi",
      "vendors": ["2c4e"],
      "modules": ["rtl8xxxu", "rtl8192eu", "8192eu", "8192fu", "8811cu", "8814au", "8814bu", "8821cu", "aic8800_bsp", "aic_load_fw", "aic8800_fdrv", "aic8800_fdrv_usb"],
      "usb_ids": [
        "2c4e:0100", "2c4e:0103", "2c4e:0104", "2c4e:0107", "2c4e:0114", "2c4e:0115"
      ]
    },
    {
      "name": "TP-Link TL-WDN/TL-WN/TL-XDN USB WiFi",
      "vendors": ["2357"],
      "modules": ["rtl8xxxu", "rtl8192eu", "8192eu", "8812au", "8814au", "8821au", "88x2bu", "8852bu", "mt76x0u", "mt76x2u", "rtw88_usb", "rtw89_8852bu"],
      "usb_ids": [
        "2357:0101", "2357:0103", "2357:0105", "2357:0106", "2357:0107", "2357:0109", "2357:010b",
        "2357:011e", "2357:011f", "2357:0120", "2357:0137", "2357:0601", "2357:0604", "2357:0606"
      ]
    },
    {
      "name": "Tenda AX300/AX900 AIC WiFi 6 USB",
      "vendors": ["2604", "a69c", "368b"],
      "modules": ["aic8800_bsp", "aic_load_fw", "aic8800_fdrv", "aic8800_fdrv_usb"],
      "usb_ids": [
        "2604:0013", "2604:0014", "2604:001f", "2604:0020", "2604:0023", "2604:0024",
        "a69c:8800", "a69c:8801", "a69c:88dc", "a69c:88dd", "a69c:8d40", "a69c:8d41", "a69c:8d80", "a69c:8d81",
        "368b:8d90", "368b:8d91", "368b:8d99", "368b:88df", "368b:88e0", "368b:88e1", "368b:88e2", "368b:88e3", "368b:88e5",
        "368b:8d83", "368b:8d85", "368b:8d86", "368b:8d89", "368b:8d8a", "368b:8d8b", "368b:8d8c", "368b:8d8d"
      ]
    },
    {
      "name": "Atheros USB WiFi",
      "vendors": ["0cf3"],
      "modules": ["ath9k_htc", "ath10k_usb"]
    },
    {
      "name": "Broadcom USB WiFi",
      "vendors": ["0a5c", "14e4"],
      "modules": ["brcmfmac"]
    }
  ],
  "vendor_sources": [
    {"vendor":"Tenda","id":"812655522193477","title":"AX900 Linux driver V1.0.1.8","size":5427676,"updated":"2026-06-04","url":"https://static.tenda.com.cn/document/2026/06/04/ba8742f107d64e048aae3e8e21706ac6/ax900-wifi-adapter-linux-driver-V1.0.1.8.zip"},
    {"vendor":"Tenda","id":"812654649405509","title":"AX900 UOS driver V1.0.1.8","size":4248392,"updated":"2026-06-04","url":"https://static.tenda.com.cn/document/2026/06/04/1063b272d6a140df9bc4a99e93e7cd16/ax900-wifi-adapter-linux-driver-V1.0.1.8-UOS.zip"},
    {"vendor":"Tenda","id":"690938082103365","title":"AX300 Kylin Ubuntu driver","size":2343128,"updated":"2026-04-23","url":"https://static.tenda.com.cn/document/2026/04/23/20e9d53d7b0f4e1388da80b52bba3c58/%E9%BA%92%E9%BA%9F%E7%B3%BB%E7%BB%9F(Kylin)Ubuntu%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8.zip"},
    {"vendor":"Tenda","id":"690935753080901","title":"AX900 Kylin Ubuntu driver V1.0.1.4","size":3345218,"updated":"2026-01-26","url":"https://static.tenda.com.cn/document/2026/01/26/914373b8ff0e48a19ee77df001e839aa/ax900-wifi-adapter-linux-driver-V1.0.1.4.zip"},
    {"vendor":"Tenda","id":"690936728768581","title":"AX900 UOS driver V1.0.1.4","size":4510447,"updated":"2026-01-26","url":"https://static.tenda.com.cn/document/2026/01/26/914373b8ff0e48a19ee77df001e839aa/ax900-wifi-adapter-linux-driver-V1.0.1.4-UOS.zip"},
    {"vendor":"Tenda","id":"690938299105349","title":"AX300 UOS driver","size":1341340,"updated":"2025-12-30","url":"https://static.tenda.com.cn/document/2025/12/30/8e6675455b5d45b6b7d484e688658624/690938299105349.zip"},
    {"vendor":"Tenda","id":"690937177473093","title":"AX300 AX900 Linux source","size":3223265,"updated":"2025-06-25","url":"https://static.tenda.com.cn/doc/2025/06/25/bd6a53f212eb4c77b278d792fd22f1ca/%E6%BA%90%E7%A0%81.zip"},
    {"vendor":"Tenda","id":"102656","title":"U6 Linux driver","size":38435609,"updated":"2025-04-07","url":"https://static.tenda.com.cn/doc/2025/04/07/0a90d66f79344138a93c4436d5e46756/Linux_(kernel%202.6.18~5.4).tar.gz.zip"},
    {"vendor":"Tenda","id":"102517","title":"W311MI V2 Linux driver","size":1664576,"updated":"2024-11-28","url":"https://static.tenda.com.cn/tdcweb/download/uploadfile/W311MI/W311MIV2.0_Linux_Driver.zip"},
    {"vendor":"Tenda","id":"102535","title":"U1 Linux driver","size":38486645,"updated":"2020-08-29","url":"https://static.tenda.com.cn/tdcweb/download/uploadfile/U1/Linux_(kernel%202.6.18~5.4).tar.gz"},
    {"vendor":"Tenda","id":"102744","title":"U3 Linux driver","size":38486645,"updated":"2020-08-29","url":"https://static.tenda.com.cn/tdcweb/download/uploadfile/U3/Linux_(kernel%202.6.18~5.4).tar.gz"},
    {"vendor":"Tenda","id":"102614","title":"U12 Linux driver","size":34937272,"updated":"2017-01-16","url":"https://static.tenda.com.cn/tdcweb/download/uploadfile/U12/U12_linux_v5.1.5_19247_Driver.zip"},
    {"vendor":"Tenda","id":"102516","title":"W311M V3 Linux driver","size":1664576,"updated":"2016-06-16","url":"https://static.tenda.com.cn/tdcweb/download/uploadfile/W311M/W311MV3.0_Linux_Driver.zip"},
    {"vendor":"Tenda","id":"102518","title":"W311MA V3 Linux driver","size":1659423,"updated":"2016-06-16","url":"https://static.tenda.com.cn/tdcweb/download/uploadfile/W311MA/W311MAV3.0_Linux_Driver.zip"},
    {"vendor":"Tenda","id":"100619","title":"W311M Linux driver","size":741987,"updated":"2011-08-03","url":"https://static.tenda.com.cn/tdcweb/download/uploadfile/W311M/W311M_Linux_Driver.zip"},
    {"vendor":"Tenda","id":"100617","title":"W311MA Linux driver","size":742027,"updated":"2011-08-03","url":"https://static.tenda.com.cn/tdcweb/download/uploadfile/W311MA/W311MA_Linux_Driver.zip"},
    {"vendor":"TP-Link","id":"1634202030547008","title":"TL-WDN7201H V1.0 Linux driver","size_kb":3519,"updated_ms":1634202030547,"url":"https://service.tp-link.com.cn/download/20218/TL-WDN7201H%20V1.0%20Linux%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F.zip"},
    {"vendor":"TP-Link","id":"1648628248019449","title":"TL-WDN7200H V1.0 Linux driver 20210802","size_kb":3522,"updated_ms":1648628248019,"url":"https://service.tp-link.com.cn/download/20221/TL-WDN7200H%20V1.0%20Linux%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F.zip"},
    {"vendor":"TP-Link","id":"1648628247972281","title":"TL-WDN7201H V1.0 Linux driver 20210802","size_kb":3522,"updated_ms":1648628247972,"url":"https://service.tp-link.com.cn/download/20221/TL-WDN7201H%20V1.0%20Linux%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F.zip"},
    {"vendor":"TP-Link","id":"1634202023205214","title":"TL-WN826N V1.0 Linux driver 20210702","size_kb":5683,"updated_ms":1634202023205,"url":"https://service.tp-link.com.cn/download/20217/TL-WN826N%20V1.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20210702.zip"},
    {"vendor":"TP-Link","id":"1634202030735479","title":"TL-WDN6200 V2.0 Linux driver","size_kb":4186,"updated_ms":1634202030735,"url":"https://service.tp-link.com.cn/download/20218/TL-WDN6200%20V2.0%20Linux%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F.zip"},
    {"vendor":"TP-Link","id":"1648628248061441","title":"TL-WDN6200 V2.0 Linux driver 20220802","size_kb":4188,"updated_ms":1648628248061,"url":"https://service.tp-link.com.cn/download/20221/TL-WDN6200%20V2.0%20Linux%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F.zip"},
    {"vendor":"TP-Link","id":"1634202021498242","title":"TL-WDN5200 V3.0 Linux driver 20210616","size_kb":6627,"updated_ms":1634202021498,"url":"https://service.tp-link.com.cn/download/20216/TL-WDN5200%20V3.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20210616.zip"},
    {"vendor":"TP-Link","id":"1774400100573184","title":"TL-NT524FW V1.0 Linux driver 20250103","size_kb":398,"updated_ms":1774400101020,"url":"https://media.tp-link.com.cn/software/TL-NT524FW%20V1.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20250103.zip"},
    {"vendor":"TP-Link","id":"1634202023143821","title":"TL-WN823N V3.0 Linux driver 20210702","size_kb":5700,"updated_ms":1634202023143,"url":"https://service.tp-link.com.cn/download/20217/TL-WN823N%20V3.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20210702.zip"},
    {"vendor":"TP-Link","id":"1634202023082504","title":"TL-WN821N V5.0 Linux driver 20210702","size_kb":5702,"updated_ms":1634202023082,"url":"https://service.tp-link.com.cn/download/20217/TL-WN821N%20V5.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20210702.zip"},
    {"vendor":"TP-Link","id":"1634202021561204","title":"TL-WDN5200H V2.0 Linux driver 20210616","size_kb":6626,"updated_ms":1634202021561,"url":"https://service.tp-link.com.cn/download/20216/TL-WDN5200H%20V2.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20210616.zip"},
    {"vendor":"TP-Link","id":"1634202030671709","title":"TL-WDN7200H V1.0 Linux driver","size_kb":3519,"updated_ms":1634202030671,"url":"https://service.tp-link.com.cn/download/20218/TL-WDN7200H%20V1.0%20Linux%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F.zip"},
    {"vendor":"TP-Link","id":"1772186109798177","title":"TL-XDN7000 Linux driver 20260224","size_kb":1474,"updated_ms":1772186110257,"url":"https://media.tp-link.com.cn/software/TL-XDN7000%E5%85%8D%E9%A9%B1%E7%89%88%20V1.1%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20260224.zip"},
    {"vendor":"TP-Link","id":"1737698100591193","title":"TL-XDN6000 Linux driver 20250118","size_kb":1823,"updated_ms":1757054235304,"url":"https://media.tp-link.com.cn/software/TL-XDN6000%E5%85%8D%E9%A9%B1%E7%89%88%20V1.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20250118.zip"},
    {"vendor":"TP-Link","id":"1772186110544812","title":"TL-XDN7000H Linux driver 20260224","size_kb":1474,"updated_ms":1772186110939,"url":"https://media.tp-link.com.cn/software/TL-XDN7000H%E5%85%8D%E9%A9%B1%E7%89%88%20V1.1%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20260224.zip"},
    {"vendor":"TP-Link","id":"1737698106348416","title":"TL-XDN6000H Linux driver 20250118","size_kb":1823,"updated_ms":1757054412565,"url":"https://media.tp-link.com.cn/software/TL-XDN6000H%E5%85%8D%E9%A9%B1%E7%89%88%20V1.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20250118.zip"},
    {"vendor":"MERCURY","id":"3284","title":"UX9H V1.1 Linux driver 20260224","size_kb":12011,"updated":"2026-02-27","url":"https://service.mercurycom.com.cn/download/202602/UX9H(%E5%85%8D%E9%A9%B1%E7%89%88)%20V1.1%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20260224.zip"},
    {"vendor":"MERCURY","id":"3283","title":"UX9 V1.1 Linux driver 20260224","size_kb":9336,"updated":"2026-02-27","url":"https://service.mercurycom.com.cn/download/202602/UX9(%E5%85%8D%E9%A9%B1%E7%89%88)%20V1.1%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20260224.zip"},
    {"vendor":"MERCURY","id":"2917","title":"UX3H V1.0 Linux driver 20250118","size_kb":46038,"updated":"2025-01-24","url":"https://service.mercurycom.com.cn/download/202509/UX3H(%E5%85%8D%E9%A9%B1%E7%89%88)%20V1.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20250118.zip"},
    {"vendor":"MERCURY","id":"2916","title":"UX3 V1.0 Linux driver 20250118","size_kb":37284,"updated":"2025-01-24","url":"https://service.mercurycom.com.cn/download/202509/UX3(%E5%85%8D%E9%A9%B1%E7%89%88)%20V1.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20250118.zip"},
    {"vendor":"MERCURY","id":"1958","title":"UD198H V1.0 Linux driver 20210802","size_kb":22392,"updated":"2021-08-03","url":"https://service.mercurycom.com.cn/download/202201/UD198H%20V1.0%20Linux%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20210802.zip"},
    {"vendor":"MERCURY","id":"1957","title":"UD19H V1.0 Linux driver 20210802","size_kb":8673,"updated":"2021-08-03","url":"https://service.mercurycom.com.cn/download/202201/UD19H%20V1.0%20Linux%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F.zip"},
    {"vendor":"MERCURY","id":"1953","title":"MW300TV V2.0 Linux driver 20210702","size_kb":21131,"updated":"2021-07-02","url":"https://service.mercurycom.com.cn/download/202201/MW300TV%20V2.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20210702.zip"},
    {"vendor":"MERCURY","id":"1952","title":"UD6S V1.0 Linux driver 20210616","size_kb":31405,"updated":"2021-06-22","url":"https://service.mercurycom.com.cn/download/202201/UD6S%20V1.0%20Linux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8%E7%A8%8B%E5%BA%8F20210616.zip"},
    {"vendor":"Netcore","id":"2727","title":"AX300 AIC8800FC Linux driver","updated":"2026-02-27","url":"https://www.netcoretec.com/media/upload/aic8800fc_%E9%BA%92%E9%BA%9FLinux%E7%B3%BB%E7%BB%9F%E9%A9%B1%E5%8A%A8.zip","detail":"https://www.netcoretec.com/service-support/download/drive/2727.html"},
    {"vendor":"Netcore","id":"231","title":"NE110 Linux 2.4/2.6 driver bundle","updated":"2020-11-04","url":"https://www.netcoretec.com/upload2022/portal/20201104/202011041734432908.rar","detail":"https://www.netcoretec.com/service-support/download/drive/231.html"}
  ]
}
JSON

cat >"$HELPER" <<'SH'
#!/bin/sh
set +e
echo "[WanOS WiFi] USB adapters:"
for d in /sys/bus/usb/devices/*; do
  [ -r "$d/idVendor" ] && [ -r "$d/idProduct" ] || continue
  v="$(cat "$d/idVendor" 2>/dev/null)"
  p="$(cat "$d/idProduct" 2>/dev/null)"
  name="$(cat "$d/product" 2>/dev/null)"
  case "$v" in
    0bda|2357|2c4e|0e12|148f|0e8d|2604|a69c|368b|0cf3|0a5c|14e4|8087) echo "  $(basename "$d") $v:$p $name" ;;
  esac
done
echo "[WanOS WiFi] network interfaces:"
ip -o link show 2>/dev/null | awk -F': ' '{print "  "$2}' | grep -E '^(wl|wlan)' || true
SH
chmod 0755 "$HELPER"

cat >"$APP_DIR/wifi-drivers-panel.py" <<'PY'
#!/usr/bin/env python3
import html
import json
import os
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

PORT = int(os.environ.get("WANOS_WIFI_DRIVERS_PANEL_PORT", "18321"))
ROOT = os.environ.get("WANOS_WIFI_DRIVER_ROOT", "/opt/wanos/components/wifi-drivers")
DB = os.path.join(ROOT, "driver-db.json")
INSTALLED = os.path.join(ROOT, "installed.env")
WIFI_VENDORS = {"0bda", "2357", "2c4e", "0e12", "148f", "0e8d", "2604", "a69c", "368b", "0cf3", "0a5c", "14e4", "8087"}
MODULES = [
    "cfg80211", "mac80211", "rfkill", "rt2800usb", "mt7601u", "mt76x0u", "mt76x2u", "mt7921u",
    "rtl8xxxu", "r8188eu", "rtl8188eu", "rtl8188fu", "rtl8192eu", "8192eu", "8192fu",
    "8811cu", "8812au", "8814au", "8814bu", "8821au", "8821cu", "88x2bu", "8852bu",
    "rtw88_usb", "rtw89_8852bu", "aic8800_bsp", "aic_load_fw", "aic8800_fdrv", "aic8800_fdrv_usb",
    "ath9k_htc", "ath10k_usb", "brcmfmac",
]

def run(cmd, timeout=12):
    try:
        p = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
        return p.returncode, (p.stdout or "") + (p.stderr or "")
    except Exception as exc:
        return 1, str(exc)

def esc(value):
    return html.escape(str(value or ""), quote=True)

def read_env():
    data = {}
    try:
        with open(INSTALLED, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if "=" in line:
                    k, v = line.rstrip("\n").split("=", 1)
                    data[k] = v
    except Exception:
        pass
    return data

def read_db():
    try:
        with open(DB, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

def usb_devices():
    items = []
    base = "/sys/bus/usb/devices"
    try:
        names = os.listdir(base)
    except Exception:
        return items
    for name in sorted(names):
        path = os.path.join(base, name)
        try:
            with open(os.path.join(path, "idVendor"), "r", encoding="utf-8") as f:
                vendor = f.read().strip().lower()
            with open(os.path.join(path, "idProduct"), "r", encoding="utf-8") as f:
                product = f.read().strip().lower()
        except Exception:
            continue
        if vendor not in WIFI_VENDORS:
            continue
        try:
            label = open(os.path.join(path, "product"), "r", encoding="utf-8", errors="ignore").read().strip()
        except Exception:
            label = ""
        items.append({"bus": name, "id": f"{vendor}:{product}", "label": label or "USB WiFi adapter"})
    return items

def interfaces():
    code, out = run(["ip", "-o", "link", "show"], 6)
    rows = []
    if code == 0:
        for line in out.splitlines():
            parts = line.split(": ", 2)
            if len(parts) >= 2 and (parts[1].startswith("wl") or parts[1].startswith("wlan")):
                rows.append(parts[1].split("@", 1)[0])
    return rows

def loaded_modules():
    code, out = run(["lsmod"], 6)
    loaded = set()
    if code == 0:
        for line in out.splitlines()[1:]:
            name = line.split(None, 1)[0] if line.split() else ""
            if name:
                loaded.add(name)
    rows = []
    for mod in MODULES:
        code, _ = run(["modinfo", mod], 3)
        rows.append({"name": mod, "available": code == 0, "loaded": mod in loaded})
    return rows

def render(message=""):
    db = read_db()
    env = read_env()
    devices = usb_devices()
    ifaces = interfaces()
    modules = loaded_modules()
    sources = db.get("vendor_sources") or []
    families = db.get("families") or []
    device_rows = "".join(f"<tr><td>{esc(x['bus'])}</td><td>{esc(x['id'])}</td><td>{esc(x['label'])}</td></tr>" for x in devices) or "<tr><td colspan='3' class='empty'>未检测到已知 USB 无线网卡</td></tr>"
    module_rows = "".join("<tr><td>{}</td><td><span class='{}'>{}</span></td><td><span class='{}'>{}</span></td></tr>".format(
        esc(x["name"]), "ok" if x["available"] else "bad", "可用" if x["available"] else "缺失",
        "ok" if x["loaded"] else "muted", "已加载" if x["loaded"] else "未加载") for x in modules)
    msg = f"<div class='msg'>{esc(message)}</div>" if message else ""
    return f"""<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>USB WiFi 驱动组件</title><style>
*{{box-sizing:border-box}}body{{margin:0;background:#f5f7fb;color:#172033;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Microsoft YaHei",sans-serif}}.wrap{{max-width:1040px;margin:0 auto;padding:22px}}.head{{display:flex;gap:14px;align-items:center;margin-bottom:18px}}.logo{{width:58px;height:58px;border-radius:14px;background:#fff url('/icon.png') center/42px 42px no-repeat;border:1px solid #e4e7ec;box-shadow:0 12px 30px rgba(16,24,40,.08)}}h1{{font-size:24px;margin:0}}.sub{{color:#667085;margin-top:5px;line-height:1.6}}.grid{{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}}.stat,.card{{background:#fff;border:1px solid #e4e7ec;border-radius:8px;box-shadow:0 1px 2px rgba(16,24,40,.04)}}.stat{{padding:14px}}.stat span{{display:block;color:#667085;font-size:12px}}.stat b{{display:block;margin-top:7px;font-size:18px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}}.card{{padding:16px;margin-top:14px}}.card h2{{font-size:17px;margin:0 0 12px}}table{{width:100%;border-collapse:collapse}}th,td{{text-align:left;border-bottom:1px solid #eef1f5;padding:9px;font-size:13px;vertical-align:top}}th{{color:#667085;font-weight:800}}.ok{{color:#067647;font-weight:800}}.bad{{color:#b42318;font-weight:800}}.muted,.empty{{color:#98a2b3}}.actions{{display:flex;gap:10px;flex-wrap:wrap;margin-top:12px}}button{{height:38px;border:0;border-radius:7px;background:#1f6feb;color:#fff;padding:0 15px;font-weight:850;cursor:pointer}}button.secondary{{background:#667085}}.msg{{background:#ecfdf3;border:1px solid #abefc6;color:#067647;border-radius:7px;padding:10px;margin:0 0 12px}}.hint{{color:#667085;line-height:1.7;font-size:13px}}@media(max-width:760px){{.grid{{grid-template-columns:repeat(2,minmax(0,1fr))}}.wrap{{padding:16px}}}}
</style></head><body><div class="wrap"><div class="head"><div class="logo"></div><div><h1>USB WiFi 驱动组件</h1><div class="sub">识别 USB 无线网卡、查看驱动模块状态，并一键重新扫描加载驱动。</div></div></div>{msg}
<div class="grid"><div class="stat"><span>组件版本</span><b>{esc(db.get('version') or env.get('VERSION') or '-')}</b></div><div class="stat"><span>驱动家族</span><b>{len(families)}</b></div><div class="stat"><span>厂商驱动源</span><b>{len(sources)}</b></div><div class="stat"><span>无线接口</span><b>{esc(', '.join(ifaces) or '未发现')}</b></div></div>
<div class="card"><h2>已识别 USB 无线网卡</h2><table><tr><th>总线</th><th>VID:PID</th><th>设备</th></tr>{device_rows}</table><div class="actions"><form method="post"><button name="action" value="reload">重新扫描并加载驱动</button><button class="secondary" name="action" value="depmod">重建模块索引</button></form></div></div>
<div class="card"><h2>驱动模块状态</h2><table><tr><th>模块</th><th>安装状态</th><th>加载状态</th></tr>{module_rows}</table></div>
<div class="card"><h2>说明</h2><div class="hint">识别列表来自内置 USB VID/PID 和厂商驱动源数据库。是否能即插即用，取决于当前架构驱动包中是否已包含对应内核版本的 .ko 模块和固件；后续补齐驱动包后，更新本组件即可扩展支持范围。</div></div>
</div></body></html>"""

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return
    def send_html(self, body):
        raw = body.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)
    def do_GET(self):
        if self.path == "/icon.png":
            icon = "/opt/wanos/apps/wanos-wifi-drivers/icon.png"
            try:
                raw = open(icon, "rb").read()
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Content-Length", str(len(raw)))
                self.end_headers()
                self.wfile.write(raw)
            except Exception:
                self.send_error(404)
            return
        self.send_html(render())
    def do_POST(self):
        length = int(self.headers.get("Content-Length") or "0")
        data = parse_qs(self.rfile.read(length).decode("utf-8", "ignore"))
        action = (data.get("action") or ["reload"])[0]
        if action == "depmod":
            run(["depmod", "-a"], 30)
            message = "已重建内核模块索引。"
        else:
            for mod in MODULES:
                run(["modprobe", mod], 4)
            message = "已重新扫描并尝试加载常见 USB WiFi 驱动。"
        self.send_html(render(message))

if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
PY
chmod 0755 "$APP_DIR/wifi-drivers-panel.py"
if [ ! -s "$APP_DIR/icon.png" ]; then
  download_file "$ICON_URL" "$APP_DIR/icon.png" >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  cat >"/etc/systemd/system/$PANEL_SERVICE.service" <<EOF
[Unit]
Description=WanOS USB WiFi Drivers Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment=WANOS_WIFI_DRIVERS_PANEL_PORT=$PANEL_PORT
Environment=WANOS_WIFI_DRIVER_ROOT=$ROOT
ExecStart=/usr/bin/python3 $APP_DIR/wifi-drivers-panel.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now "$PANEL_SERVICE" >/dev/null 2>&1 || systemctl restart "$PANEL_SERVICE" >/dev/null 2>&1 || true
else
  echo "[WanOS WiFi] WARN: systemd or python3 missing, web panel skipped"
fi

if command -v depmod >/dev/null 2>&1; then
  depmod -a >/dev/null 2>&1 || true
fi
load_modules

cat >"$ROOT/installed.env" <<EOF
VERSION=2026.07.09-6
INSTALLED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PACKAGE_URL=$PKG_URL
EOF

echo "[WanOS WiFi] driver component installed"
"$HELPER" || true
