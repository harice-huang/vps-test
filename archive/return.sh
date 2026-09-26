#!/usr/bin/env bash
_red() { echo -e "\033[31m\033[01m$*\033[0m"; }
_green() { echo -e "\033[32m\033[01m$*\033[0m"; }
_yellow() { echo -e "\033[33m\033[01m$*\033[0m"; }
_blue() { echo -e "\033[36m\033[01m$*\033[0m"; }
reading(){ read -rp "$(_green "$1")" "$2"; }
translate(){ [[ -n "$1" ]] && curl -sm8 --proto '=https' --proto-redir '=https' "https://fanyi.youdao.com/translate?&doctype=json&type=AUTO&i=${1//[[:space:]]/}" | cut -d \" -f18 2>/dev/null; }
is_valid_ipv4(){
  local address="$1" octet
  local parts
  [[ "$address" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
  IFS='.' read -r -a parts <<<"$address"
  for octet in "${parts[@]}"; do ((10#$octet <= 255)) || return 1; done
}
is_valid_ipv6(){ [[ ${#1} -le 45 && "$1" == *:* && "$1" =~ ^[0-9A-Fa-f:.]+$ ]]; }
sanitize_text(){ printf '%s' "$1" | LC_ALL=C tr -d '\000-\037\177'; }
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/return.XXXXXX") || exit 1
TEMP_FILE="$TEMP_DIR/ip.test"
cleanup_temp_dir(){ rm -rf -- "$TEMP_DIR"; }
trap cleanup_temp_dir EXIT
utf8_locale=$(locale -a 2>/dev/null | grep -i -m 1 -E "UTF-8|utf8")
if [[ -z "$utf8_locale" ]]; then
  echo "No UTF-8 locale found"
else
  export LC_ALL="$utf8_locale"
  export LANG="$utf8_locale"
  export LANGUAGE="$utf8_locale"
  echo "Locale set to $utf8_locale"
fi

check_dependencies(){ for c in "$@"; do
type -p "$c" >/dev/null 2>&1 || (_yellow " 安装 $c 中…… " && ${PACKAGE_INSTALL[b]} "$c") || (_yellow " 先升级软件库才能继续安装 \$c，时间较长，请耐心等待…… " && ${PACKAGE_UPDATE[b]} && ${PACKAGE_INSTALL[b]} "$c")
! type -p "$c" >/dev/null 2>&1 && _yellow " 安装 \$c 失败，脚本中止，问题反馈:[https://github.com/fscarmen/tools/issues] " && exit 1; done; }

fscarmen_route_script(){
    rm -f "$TEMP_FILE"
    local ARCHITECTURE="$(uname -m)"
    local OS_NAME="$(uname -s)"
    local FILE
        case $ARCHITECTURE in
        x86_64 )  [[ "$OS_NAME" == "Darwin" ]] && FILE=besttracemac || FILE=besttrace;;
        aarch64 | arm64 ) [[ "$OS_NAME" == "Darwin" ]] && FILE=besttracemacarm || FILE=besttracearm;;
        i386 | i686 ) [[ "$OS_NAME" == "Darwin" ]] && FILE=besttracemac || FILE=besttrace32;;
        * ) _red " 只支持 AMD64、ARM64、Mac 使用，问题反馈:[https://github.com/fscarmen/tools/issues] " && return;;
        esac
    local FILE_PATH="$TEMP_DIR/$FILE"
    local ARCHIVE_PATH="$TEMP_DIR/besttrace4linux.zip"
    if ! curl --fail -s -L --proto '=https' --proto-redir '=https' "https://cdn.ipip.net/17mon/besttrace4linux.zip" -o "$ARCHIVE_PATH" &&
       ! curl --fail -s -L --proto '=https' --proto-redir '=https' "https://soft.xiaoz.org/linux/besttrace4linux.zip" -o "$ARCHIVE_PATH"; then
        rm -f "$ARCHIVE_PATH" "$FILE_PATH"
        return 1
    fi
    if [ "$(unzip -Z1 "$ARCHIVE_PATH" | awk -v file="$FILE" '$0 == file { count++ } END { print count + 0 }')" -ne 1 ] ||
       ! unzip -p "$ARCHIVE_PATH" "$FILE" >"$FILE_PATH" || [ ! -s "$FILE_PATH" ]; then
        rm -f "$ARCHIVE_PATH" "$FILE_PATH"
        return 1
    fi
    rm -f "$ARCHIVE_PATH"
    chmod 700 "$FILE_PATH" &>/dev/null
    _green "依次测试电信，联通，移动经过的地区及线路，核心程序来由: ipip.net ，请知悉!" >>"$TEMP_FILE"
    "$FILE_PATH" "$ip" -g cn 2>/dev/null | sed "s/^[ ]//g" | sed "/^[ ]/d" | sed '/ms/!d' | sed "s#.* \([0-9.]\+ ms.*\)#\1#g" >>"$TEMP_FILE"
    [ "${PIPESTATUS[0]}" -eq 0 ] || return 1
    cat "$TEMP_FILE"
    rm -f "$TEMP_FILE"
}

ARCHITECTURE="$(arch)"
# 多方式判断操作系统，试到有值为止。只支持 Debian 10/11、Ubuntu 18.04/20.04 或 CentOS 7/8 ,如非上述操作系统，退出脚本
if [[ $(uname -s) = Darwin ]]; then
  b=0
  SYSTEM='macOS'
  PACKAGE_INSTALL=("brew install")
else
  CMD=(	"$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)"
      	"$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)"
	"$(lsb_release -sd 2>/dev/null)"
	"$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)"
	"$(grep . /etc/redhat-release 2>/dev/null)"
	"$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')"
	)

  REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|amazon linux|alma|rocky")
  RELEASE=("Debian" "Ubuntu" "CentOS")
  PACKAGE_UPDATE=("apt -y update" "apt -y update" "yum -y update")
  PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install")

  for a in "${CMD[@]}"; do
	  SYS="$a" && [[ -n $SYS ]] && break
  done
  
  for ((b=0; b<${#REGEX[@]}; b++)); do
	[[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[b]} ]] && SYSTEM="${RELEASE[b]}" && break
  done
fi

[[ -z $SYSTEM ]] && _red " 本脚本只支持 Debian、Ubuntu、CentOS、Alpine 或者 macOS 系统,问题反馈:[https://github.com/fscarmen/warp_unlock/issues] " && exit 1

check_dependencies curl sudo unzip

main() {
    [[ -z "$ip" || $ip = '[DESTINATION_IP]' ]] && reading "\n 请输入目的地 IP: " ip
    _yellow "\n 检测中，请稍等片刻。\n"
    # 遍历本机可以使用的 IP API 服务商
    API_URL=("api.ip.sb/geoip" "ifconfig.co/json")
    API_ASN=("isp" "asn_org")
    IP_4=""
    WAN_4=""
    for p in "${!API_URL[@]}"; do
      IP_4=$(curl -s4m5 -A Mozilla "https://${API_URL[p]}") || continue
      WAN_4=$(expr "$IP_4" : '.*ip\":[ ]*\"\([^"]*\).*')
      is_valid_ipv4 "$WAN_4" && break
      WAN_4=""
    done
    if [ -n "$WAN_4" ]; then
      COUNTRY_4E=$(expr "$IP_4" : '.*country\":[ ]*\"\([^"]*\).*')
      COUNTRY_4=$(sanitize_text "$(translate "$COUNTRY_4E")")
      ASNORG_4=$(sanitize_text "$(expr "$IP_4" : '.*'${API_ASN[p]}'\":[ ]*\"\([^"]*\).*')")
      TYPE_4=$(sanitize_text "$(curl -4m5 -sSL "https://www.abuseipdb.com/check/$WAN_4" 2>/dev/null | grep -A2 '<th>Usage Type</th>' | tail -n 1 | sed "s@Data Center/Web Hosting/Transit@数据中心@;s@Fixed Line ISP@家庭宽带@;s@Commercial@商业宽带@;s@Mobile ISP@移动流量@;s@Content Delivery Network@内容分发网络(CDN)@;s@Search Engine Spider@搜索引擎蜘蛛@;s@University/College/School@教育网@;s@Unknown@未知@")")
      _green " IPv4: $WAN_4\t\t 地区: $COUNTRY_4\t 类型: $TYPE_4\t ASN: $ASNORG_4\n"
    fi

    IP_6=""
    WAN_6=""
    for p in "${!API_URL[@]}"; do
      IP_6=$(curl -s6m5 -A Mozilla "https://${API_URL[p]}") || continue
      WAN_6=$(expr "$IP_6" : '.*ip\":[ ]*\"\([^"]*\).*')
      is_valid_ipv6 "$WAN_6" && break
      WAN_6=""
    done
    if [ -n "$WAN_6" ]; then
      COUNTRY_6E=$(expr "$IP_6" : '.*country\":[ ]*\"\([^"]*\).*')
      COUNTRY_6=$(sanitize_text "$(translate "$COUNTRY_6E")")
      ASNORG_6=$(sanitize_text "$(expr "$IP_6" : '.*'${API_ASN[p]}'\":[ ]*\"\([^"]*\).*')")
      TYPE_6=$(sanitize_text "$(curl -6m5 -sSL "https://www.abuseipdb.com/check/$WAN_6" 2>/dev/null | grep -A2 '<th>Usage Type</th>' | tail -n 1 | sed "s@Data Center/Web Hosting/Transit@数据中心@;s@Fixed Line ISP@家庭宽带@;s@Commercial@商业宽带@;s@Mobile ISP@移动流量@;s@Content Delivery Network@内容分发网络(CDN)@;s@Search Engine Spider@搜索引擎蜘蛛@;s@University/College/School@教育网@;s@Unknown@未知@")")
      _green " IPv6: $WAN_6\t 地区: $COUNTRY_6\t 类型: $TYPE_6\t ASN: $ASNORG_6\n"
    fi

    [[ $ip =~ '.' && -z "$WAN_4" ]] && _red " VPS 没有 IPv4 网络，不能查 $ip\n" && exit 1
    [[ $ip =~ ':' && -z "$WAN_6" ]] && _red " VPS 没有 IPv6 网络，不能查 $ip\n" && exit 1
    fscarmen_route_script
}

main
