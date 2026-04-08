#!/bin/bash

sudo -v

dev=false
debug=false

for arg in "${@}"; do
  [ "${arg}" = "--dev" ] && dev=true
  [ "${arg}" = "--debug" ] && debug=true
done

log_redirects="/dev/null"

[ "${debug}" = true ] && log_redirects="/dev/stdout"

reset="\e[0m"
bold="\x1b[1m"
dim="\x1b[2m"
italic="\x1b[3m"
underline="\x1b[4m"
blink="\x1b[5m"
inverse="\x1b[7m"
hidden="\x1b[8m"
strikethrough="\x1b[9m"

black="\e[30m"
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
magenta="\e[35m"
cyan="\e[36m"
white="\e[37m"
gray="\e[90m"

bg_black="\x1b[40m"
bg_red="\x1b[41m"
bg_green="\x1b[42m"
bg_yellow="\x1b[43m"
bg_blue="\x1b[44m"
bg_magenta="\x1b[45m"
bg_cyan="\x1b[46m"
bg_white="\x1b[47m"
bg_gray="\x1b[100m"

country_code=$(curl --max-time 10 -s https://ipinfo.io/country)

install_package() {
  local package_name="${1}"

  if command -v apt &>/dev/null; then
    sudo apt install -y "${package_name}" &>"${log_redirects}"
  elif command -v rpm-ostree &>/dev/null; then
    sudo rpm-ostree install --idempotent --apply-live "${package_name}" &>"${log_redirects}"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y "${package_name}" &>"${log_redirects}"
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm "${package_name}" &>"${log_redirects}"
  elif command -v zypper &>/dev/null; then
    sudo zypper -n install "${package_name}" &>"${log_redirects}"
  elif command -v xbps-install &>/dev/null; then
    sudo xbps-install -y "${package_name}" &>"${log_redirects}"
  elif command -v apk &>/dev/null; then
    sudo apk add --quiet "${package_name}" &>"${log_redirects}"
  elif command -v emerge &>/dev/null; then
    sudo emerge --quiet "${package_name}" &>"${log_redirects}"
  elif command -v slackpkg &>/dev/null; then
    sudo slackpkg -batch=on -default_answer=y install "${package_name}" &>"${log_redirects}"
  elif command -v eopkg &>/dev/null; then
    sudo eopkg install -y "${package_name}" &>"${log_redirects}"
  elif command -v pkg &>/dev/null; then
    sudo pkg install -y "${package_name}" &>"${log_redirects}"
  elif command -v pkg_add &>/dev/null; then
    sudo pkg_add -I "${package_name}" &>"${log_redirects}"
  elif command -v opkg &>/dev/null; then
    sudo opkg install "${package_name}" &>"${log_redirects}"
  else
    if [ "${country_code}" = "RU" ]; then
      echo -e "  ${red}Неподдерживаемый менеджер пакетов.${reset}"
    elif [ "${country_code}" = "TR" ]; then
      echo -e "  ${red}Desteklenmeyen paket yöneticisi.${reset}"
    else
      echo -e "  ${red}Unsupported package manager.${reset}"
    fi
    echo ""

    exit 1
  fi
}

remove_package() {
  local package_name="${1}"

  if command -v apt &>/dev/null; then
    sudo apt purge -y "${package_name}" &>"${log_redirects}"
  elif command -v rpm-ostree &>/dev/null; then
    sudo rpm-ostree uninstall "${package_name}" &>"${log_redirects}"
  elif command -v dnf &>/dev/null; then
    sudo dnf remove -y "${package_name}" &>"${log_redirects}"
  elif command -v pacman &>/dev/null; then
    sudo pacman -Rns --noconfirm "${package_name}" &>"${log_redirects}"
  elif command -v zypper &>/dev/null; then
    sudo zypper -n remove "${package_name}" &>"${log_redirects}"
  elif command -v xbps-remove &>/dev/null; then
    sudo xbps-remove -y "${package_name}" &>"${log_redirects}"
  elif command -v apk &>/dev/null; then
    sudo apk del --quiet "${package_name}" &>"${log_redirects}"
  elif command -v emerge &>/dev/null; then
    sudo emerge --unmerge --quiet "${package_name}" &>"${log_redirects}"
  elif command -v slackpkg &>/dev/null; then
    sudo slackpkg -batch=on -default_answer=y remove "${package_name}" &>"${log_redirects}"
  elif command -v eopkg &>/dev/null; then
    sudo eopkg remove -y "${package_name}" &>"${log_redirects}"
  elif command -v pkg &>/dev/null; then
    sudo pkg delete -y "${package_name}" &>"${log_redirects}"
  elif command -v pkg_delete &>/dev/null; then
    sudo pkg_delete "${package_name}" &>"${log_redirects}"
  elif command -v opkg &>/dev/null; then
    sudo opkg remove "${package_name}" &>"${log_redirects}"
  else
    if [ "${country_code}" = "RU" ]; then
      echo -e "  ${red}Неподдерживаемый менеджер пакетов.${reset}"
    elif [ "${country_code}" = "TR" ]; then
      echo -e "  ${red}Desteklenmeyen paket yöneticisi.${reset}"
    else
      echo -e "  ${red}Unsupported package manager.${reset}"
    fi
    echo ""

    exit 1
  fi
}

print_head() {
  clear

  echo ""
  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${blue}Keift ${cyan}Удалить Zapret${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${blue}Keift ${cyan}Zapret Kaldırma${reset}"
  else
    echo -e "  ${blue}Keift ${cyan}Uninstall Zapret${reset}"
  fi
  echo ""
}

print_head

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Настройки DNS удаляются...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}DNS ayarları kaldırılıyor...${reset}"
else
  echo -e "  ${gray}DNS settings are being removed...${reset}"
fi

if command -v systemctl &>/dev/null && ! command -v pihole &>/dev/null && ! command -v pihole-FTL &>/dev/null; then
  install_package systemd-resolved
  remove_package dnscrypt-proxy
  remove_package dnscrypt-proxy2

  enable_service systemd-resolved
  start_service systemd-resolved

  sudo tee /etc/systemd/resolved.conf &>/dev/null <<< ""

  sudo chattr -i /etc/resolv.conf &>"${log_redirects}"

  [ -f /run/systemd/resolve/stub-resolv.conf ] && sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf &>"${log_redirects}"

  restart_service systemd-resolved
else
  remove_package dnscrypt-proxy
  remove_package dnscrypt-proxy2

  sudo chattr -i /etc/resolv.conf &>"${log_redirects}"

  local_resolver=$(ip route show default | awk "{print \$3}" | head -n 1)

  if dig -p 53 +tries=1 +time=10 @"${local_resolver}" &>/dev/null; then
    sudo tee /etc/resolv.conf &>/dev/null << EOF
nameserver ${local_resolver}

nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
nameserver 1.0.0.1
nameserver 2606:4700:4700::1001
EOF
  else
    sudo tee /etc/resolv.conf &>/dev/null << EOF
nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
nameserver 1.0.0.1
nameserver 2606:4700:4700::1001
EOF
  fi
fi

if [ ! -d /opt/zapret ]; then
  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${gray}Zapret уже не установлен.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${gray}Zapret zaten kurulu değil.${reset}"
  else
    echo -e "  ${gray}Zapret already not installed.${reset}"
  fi
  echo ""

  exit 0
fi

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Удаление Zapret...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Zapret kaldırılıyor...${reset}"
else
  echo -e "  ${gray}Uninstalling Zapret...${reset}"
fi

printf "Y\n\n" | sudo /opt/zapret/uninstall_easy.sh &>"${log_redirects}"

sudo rm -rf /opt/zapret

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Zapret успешно удален.${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Zapret başarıyla kaldırıldı.${reset}"
else
  echo -e "  ${gray}Zapret has been successfully uninstalled.${reset}"
fi

echo ""