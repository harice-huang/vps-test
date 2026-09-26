#!/usr/bin/env bash
# by spiritlhl
# from https://github.com/spiritLHLS/ecs
# curl -L https://raw.githubusercontent.com/spiritLHLS/ecs/main/archive/multi_disk_io_test.sh -o mdit.sh && chmod +x mdit.sh && bash mdit.sh
# 2024.07.06

myvar=$(pwd)
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/multi-disk.XXXXXX") || exit 1
YABS_SCRIPT="$TEMP_DIR/yabs.sh"
cleanup_temp_dir() { rm -rf -- "$TEMP_DIR"; }
trap cleanup_temp_dir EXIT
export DEBIAN_FRONTEND=noninteractive
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora" "arch")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora" "Arch")
PACKAGE_UPDATE=("! apt-get update && apt-get --fix-broken install -y && apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update" "pacman -Sy")
PACKAGE_INSTALL=("apt-get -y install" "apt-get -y install" "yum -y install" "yum -y install" "yum -y install" "pacman -Sy --noconfirm --needed")
PACKAGE_REMOVE=("apt-get -y remove" "apt-get -y remove" "yum -y remove" "yum -y remove" "yum -y remove" "pacman -Rsc --noconfirm")
PACKAGE_UNINSTALL=("apt-get -y autoremove" "apt-get -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove" "")
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')" "$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)")
SYS="${CMD[0]}"
[[ -n $SYS ]] || exit 1
for ((int = 0; int < ${#REGEX[@]}; int++)); do
  if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
    SYSTEM="${RELEASE[int]}"
    [[ -n $SYSTEM ]] && break
  fi
done
utf8_locale=$(locale -a 2>/dev/null | grep -i -m 1 -E "UTF-8|utf8")
if [[ -z "$utf8_locale" ]]; then
  echo "No UTF-8 locale found"
else
  export LC_ALL="$utf8_locale"
  export LANG="$utf8_locale"
  export LANGUAGE="$utf8_locale"
  echo "Locale set to $utf8_locale"
fi
apt-get --fix-broken install -y >/dev/null 2>&1

if [ ! -e '/usr/bin/curl' ]; then
  ${PACKAGE_INSTALL[int]} curl
fi
if [ $? -ne 0 ]; then
  apt-get -f install >/dev/null 2>&1
  ${PACKAGE_INSTALL[int]} curl
fi
# [[ $EUID -ne 0 ]] && echo -e "请使用 root 用户运行本脚本！" && exit 1

check_cdn() {
  local o_url=$1
  for cdn_url in "${cdn_urls[@]}"; do
    if curl -sL --proto '=https' --proto-redir '=https' "$cdn_url$o_url" --max-time 6 | grep -q "success" >/dev/null 2>&1; then
      export cdn_success_url="$cdn_url"
      return
    fi
    sleep 0.5
  done
  export cdn_success_url=""
}

check_cdn_file() {
  check_cdn "https://raw.githubusercontent.com/spiritLHLS/ecs/main/back/test"
  if [ -n "$cdn_success_url" ]; then
    echo "CDN available, using CDN"
  else
    echo "No CDN available, no use CDN"
  fi
}

cdn_urls=("https://cdn0.spiritlhl.top/" "https://cdn.spiritlhl.net/")
check_cdn_file

# 下载测试脚本
if ! curl --fail -sL --proto '=https' --proto-redir '=https' "${cdn_success_url}https://raw.githubusercontent.com/masonr/yet-another-bench-script/master/yabs.sh" -o "$YABS_SCRIPT.download"; then
  rm -f "$YABS_SCRIPT.download"
  exit 1
fi
mv "$YABS_SCRIPT.download" "$YABS_SCRIPT"
chmod 700 "$YABS_SCRIPT"
sed -i '/# gather basic system information (inc. CPU, AES-NI\/virt status, RAM + swap + disk size)/,/^echo -e "IPv4\/IPv6  : $ONLINE"/d' "$YABS_SCRIPT"
bash -n "$YABS_SCRIPT" || exit 1
echo -e "---------------------------------"
echo "Current disk: system disk"
echo "Current path: /root"
echo -en "\rRunning fio test..."
output=$("$YABS_SCRIPT" -s -- -i -n -g 2>&1 | tail -n +9)
if [[ $output =~ "Block Size" ]]; then
    output=$(echo "$output" | grep -v 'curl' | sed '$d' | sed '$d' | sed '1,2d')
    echo -en "\r"
    echo "$output"
else
    echo -en "\r"
    echo "Test failed please replace with another"
fi

# 获取非系统盘的顶层块设备名称
root_source=$(findmnt -n -o SOURCE / 2>/dev/null)
root_disk=$(lsblk -s -r -n -o NAME,TYPE "$root_source" 2>/dev/null | awk '$2 == "disk" { print $1; exit }')
disk_names=$(lsblk -e 11 -d -n -o NAME,TYPE | awk -v root_disk="$root_disk" '$2 == "disk" && $1 != root_disk { print $1 }')
if [ -z "$disk_names" ]; then
  echo "No eligible disk names found. Exiting script."
  cleanup_temp_dir
  exit 0
fi

# 存储盘名称和盘路径的数组
declare -a disk_device_names disk_paths

# 遍历每个盘名称并检索对应的盘路径，并将名称和路径存储到数组中
for disk_name in $disk_names; do
  disk_path=$(lsblk -r -n -o MOUNTPOINT "/dev/$disk_name" 2>/dev/null | sed -n '/[^[:space:]]/ { p; q; }')
  if [ -n "$disk_path" ]; then
    disk_device_names+=("$disk_name")
    disk_paths+=("$disk_path")
  fi
done

# 提示用户输入自定义路径
read -r -p "Enter custom path (leave empty to use detected paths): " custom_path

# 遍历数组，打开对应盘路径并检测IO
if [ ${#disk_paths[@]} -gt 0 ]; then
  for ((disk_index = 0; disk_index < ${#disk_paths[@]}; disk_index++)); do
    disk_name="${disk_device_names[disk_index]}"
    path="${disk_paths[disk_index]}"
    
    if [ -n "$custom_path" ]; then
      path="$custom_path"
    fi

    if [ -n "$path" ]; then
      cd -- "$path" >/dev/null 2>&1
      if [ $? -ne 0 ]; then
        continue
      fi
      echo -e "---------------------------------"
      echo "Current disk: ${disk_name}"
      echo "Current path: ${path}"
      echo -en "\rRunning fio test..."
      output=$("$YABS_SCRIPT" -s -- -i -n -g 2>&1 | tail -n +9)
      if [[ $output =~ "Block Size" ]]; then
          output=$(echo "$output" | grep -v 'curl' | sed '$d' | sed '$d' | sed '1,2d')
          echo -en "\r"
          echo "$output"
      else
          echo -en "\r"
          echo "Test failed please replace with another"
      fi
    fi
    cd -- "$myvar" >/dev/null 2>&1
  done
  echo -e "---------------------------------"
else
  echo "No extra disk"
fi
cleanup_temp_dir
