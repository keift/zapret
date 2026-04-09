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

detect_system() {
  # Systemd
  if command -v systemctl &> /dev/null; then
    init_system="systemd"
  # Runit
  elif command -v sv &> /dev/null; then
    init_system="runit"
  # S6
  elif command -v s6-svscan &> /dev/null || command -v s6-rc &> /dev/null; then
    init_system="s6"
  # OpenRC
  elif command -v rc-service &> /dev/null; then
    init_system="openrc"
  # OpenBSD
  elif command -v rcctl &> /dev/null; then
    init_system="openbsd"
  # FreeBSD
  elif command -v sysrc &> /dev/null; then
    init_system="freebsd"
  # pfSense
  elif sudo test -f /etc/pfsense-release || grep -qi "pfsense" /etc/platform 2> /dev/null; then
    init_system="pfsense"
  # SysvInit
  elif command -v service &> /dev/null || sudo test -x /usr/sbin/service || sudo test -x /sbin/service; then
    init_system="sysvinit"
  # SysvInit (Old)
  elif sudo test -d /etc/init.d; then
    init_system="sysvinit-old"
  # Entware
  elif sudo test -d /opt/etc/init.d; then
    init_system="entware"
  # Rc
  elif sudo test -d /etc/rc.d; then
    init_system="rc"
  # Launchd
  elif command -v launchctl &> /dev/null; then
    init_system="launchd"
  else
    init_system="unknown"
  fi

  if command -v apt &> /dev/null; then
    package_manager="apt"
  elif command -v rpm-ostree &> /dev/null; then
    package_manager="rpm-ostree"
  elif command -v dnf &> /dev/null; then
    package_manager="dnf"
  elif command -v pacman &> /dev/null; then
    package_manager="pacman"
  elif command -v zypper &> /dev/null; then
    package_manager="zypper"
  elif command -v xbps-install &> /dev/null; then
    package_manager="xbps"
  elif command -v apk &> /dev/null; then
    package_manager="apk"
  elif command -v emerge &> /dev/null; then
    package_manager="emerge"
  elif command -v slackpkg &> /dev/null; then
    package_manager="slackpkg"
  elif command -v eopkg &> /dev/null; then
    package_manager="eopkg"
  elif command -v pkg &> /dev/null; then
    package_manager="pkg"
  elif command -v pkg_add &> /dev/null; then
    package_manager="pkg_add"
  elif command -v opkg &> /dev/null; then
    package_manager="opkg"
  else
    package_manager="unknown"
  fi
}

detect_system

start_service() {
  local service_name="${1}"

  # Systemd
  if [ "${init_system}" = "systemd" ]; then
    sudo systemctl start "${service_name}" &> "${log_redirects}"
  # Runit
  elif [ "${init_system}" = "runit" ]; then
    sudo sv start "${service_name}" &> "${log_redirects}"
  # S6
  elif [ "${init_system}" = "s6" ]; then
    if command -v s6-rc &> /dev/null; then
      sudo s6-rc -u change "${service_name}" &> "${log_redirects}"
    else
      if sudo test -d /etc/s6/sv; then
        local s6_service_dir="/etc/s6/sv"
      elif sudo test -d /etc/s6-servicedirs; then
        local s6_service_dir="/etc/s6-servicedirs"
      fi

      sudo s6-svc -u "${s6_service_dir}"/"${service_name}" &> "${log_redirects}"
    fi
  # OpenRC
  elif [ "${init_system}" = "openrc" ]; then
    sudo rc-service "${service_name}" start &> "${log_redirects}"
  # OpenBSD
  elif [ "${init_system}" = "openbsd" ]; then
    sudo rcctl start "${service_name}" &> "${log_redirects}"
  # FreeBSD
  elif [ "${init_system}" = "freebsd" ]; then
    sudo service "${service_name}" start &> "${log_redirects}"
  # pfSense
  elif [ "${init_system}" = "pfsense" ]; then
    sudo /usr/local/etc/rc.d/"${service_name}".sh start &> "${log_redirects}"
  # SysvInit
  elif [ "${init_system}" = "sysvinit" ]; then
    sudo service "${service_name}" start &> "${log_redirects}"
  # SysvInit (Old)
  elif [ "${init_system}" = "sysvinit-old" ]; then
    sudo /etc/init.d/"${service_name}" start &> "${log_redirects}"
  # Entware
  elif [ "${init_system}" = "entware" ]; then
    local entware_script=$(ls /opt/etc/init.d/*"${service_name}" 2> /dev/null | head -n 1)

    sudo "${entware_script}" start &> "${log_redirects}"
  # Rc
  elif [ "${init_system}" = "rc" ]; then
    sudo /etc/rc.d/rc."${service_name}" start &> "${log_redirects}"
  # Launchd
  elif [ "${init_system}" = "launchd" ]; then
    sudo launchctl start "${service_name}" &> "${log_redirects}"
  else
    if [ "${country_code}" = "RU" ]; then
      echo -e "  ${red}Неподдерживаемая система инициализации.${reset}"
    elif [ "${country_code}" = "TR" ]; then
      echo -e "  ${red}Desteklenmeyen başlatma sistemi.${reset}"
    else
      echo -e "  ${red}Unsupported init system.${reset}"
    fi
    echo ""

    exit 1
  fi
}

restart_service() {
  local service_name="${1}"

  # Systemd
  if [ "${init_system}" = "systemd" ]; then
    sudo systemctl restart "${service_name}" &> "${log_redirects}"
  # Runit
  elif [ "${init_system}" = "runit" ]; then
    sudo sv restart "${service_name}" &> "${log_redirects}"
  # S6
  elif [ "${init_system}" = "s6" ]; then
    if command -v s6-rc &> /dev/null; then
      sudo s6-rc -d change "${service_name}" &> "${log_redirects}"
      sudo s6-rc -u change "${service_name}" &> "${log_redirects}"
    else
      if sudo test -d /etc/s6/sv; then
        local s6_service_dir="/etc/s6/sv"
      elif sudo test -d /etc/s6-servicedirs; then
        local s6_service_dir="/etc/s6-servicedirs"
      fi

      sudo s6-svc -r "${s6_service_dir}"/"${service_name}" &> "${log_redirects}"
    fi
  # OpenRC
  elif [ "${init_system}" = "openrc" ]; then
    sudo rc-service "${service_name}" restart &> "${log_redirects}"
  # OpenBSD
  elif [ "${init_system}" = "openbsd" ]; then
    sudo rcctl restart "${service_name}" &> "${log_redirects}"
  # FreeBSD
  elif [ "${init_system}" = "freebsd" ]; then
    sudo service "${service_name}" restart &> "${log_redirects}"
  # pfSense
  elif [ "${init_system}" = "pfsense" ]; then
    sudo /usr/local/etc/rc.d/"${service_name}".sh restart &> "${log_redirects}"
  # SysvInit
  elif [ "${init_system}" = "sysvinit" ]; then
    sudo service "${service_name}" restart &> "${log_redirects}"
  # SysvInit (Old)
  elif [ "${init_system}" = "sysvinit-old" ]; then
    sudo /etc/init.d/"${service_name}" restart &> "${log_redirects}"
  # Entware
  elif [ "${init_system}" = "entware" ]; then
    local entware_script=$(ls /opt/etc/init.d/*"${service_name}" 2> /dev/null | head -n 1)

    sudo "${entware_script}" restart &> "${log_redirects}"
  # Rc
  elif [ "${init_system}" = "rc" ]; then
    sudo /etc/rc.d/rc."${service_name}" restart &> "${log_redirects}"
  # Launchd
  elif [ "${init_system}" = "launchd" ]; then
    sudo launchctl stop "${service_name}" &> "${log_redirects}"
    sudo launchctl start "${service_name}" &> "${log_redirects}"
  else
    if [ "${country_code}" = "RU" ]; then
      echo -e "  ${red}Неподдерживаемая система инициализации.${reset}"
    elif [ "${country_code}" = "TR" ]; then
      echo -e "  ${red}Desteklenmeyen başlatma sistemi.${reset}"
    else
      echo -e "  ${red}Unsupported init system.${reset}"
    fi
    echo ""

    exit 1
  fi
}

enable_service() {
  local service_name="${1}"

  # Systemd
  if [ "${init_system}" = "systemd" ]; then
    sudo systemctl enable "${service_name}" &> "${log_redirects}"
  # Runit
  elif [ "${init_system}" = "runit" ]; then
    if sudo test -d /etc/sv; then
      local runit_sv_dir="/etc/sv"
    elif sudo test -d /etc/runit/sv; then
      local runit_sv_dir="/etc/runit/sv"
    fi

    if sudo test -d /var/service; then
      local runit_service_dir="/var/service"
    elif sudo test -d /run/runit/service; then
      local runit_service_dir="/run/runit/service"
    elif sudo test -d /service; then
      local runit_service_dir="/service"
    fi

    sudo ln -sf "${runit_sv_dir}"/"${service_name}" "${runit_service_dir}" &> "${log_redirects}"
  # S6
  elif [ "${init_system}" = "s6" ]; then
    :
  # OpenRC
  elif [ "${init_system}" = "openrc" ]; then
    sudo rc-update add "${service_name}" default &> "${log_redirects}"
  # OpenBSD
  elif [ "${init_system}" = "openbsd" ]; then
    sudo rcctl enable "${service_name}" &> "${log_redirects}"
  # FreeBSD
  elif [ "${init_system}" = "freebsd" ]; then
    sudo sysrc "${service_name}_enable=YES" &> "${log_redirects}"
  # pfSense
  elif [ "${init_system}" = "pfsense" ]; then
    :
  # SysvInit
  elif [ "${init_system}" = "sysvinit" ]; then
    if command -v update-rc.d &> /dev/null || sudo test -x /usr/sbin/update-rc.d || sudo test -x /sbin/update-rc.d; then
      sudo update-rc.d "${service_name}" defaults &> "${log_redirects}"
    elif command -v chkconfig &> /dev/null || sudo test -x /usr/sbin/chkconfig || sudo test -x /sbin/chkconfig; then
      sudo chkconfig "${service_name}" on &> "${log_redirects}"
    fi
  # SysvInit (Old)
  elif [ "${init_system}" = "sysvinit-old" ]; then
    :
  # Entware
  elif [ "${init_system}" = "entware" ]; then
    :
  # Rc
  elif [ "${init_system}" = "rc" ]; then
    :
  # Launchd
  elif [ "${init_system}" = "launchd" ]; then
    sudo launchctl load -w /Library/LaunchDaemons/"${service_name}".plist &> "${log_redirects}"
  else
    if [ "${country_code}" = "RU" ]; then
      echo -e "  ${red}Неподдерживаемая система инициализации.${reset}"
    elif [ "${country_code}" = "TR" ]; then
      echo -e "  ${red}Desteklenmeyen başlatma sistemi.${reset}"
    else
      echo -e "  ${red}Unsupported init system.${reset}"
    fi
    echo ""

    exit 1
  fi
}

install_package() {
  local package_name="${1}"

  if [ "${package_manager}" = "apt" ]; then
    sudo apt install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "rpm-ostree" ]; then
    sudo rpm-ostree install --idempotent --apply-live "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "dnf" ]; then
    sudo dnf install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pacman" ]; then
    sudo pacman -S --noconfirm "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "zypper" ]; then
    sudo zypper -n install "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "xbps" ]; then
    sudo xbps-install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apk" ]; then
    sudo apk add --quiet "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "emerge" ]; then
    sudo emerge --quiet "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "slackpkg" ]; then
    sudo slackpkg -batch=on -default_answer=y install "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "eopkg" ]; then
    sudo eopkg install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pkg" ]; then
    sudo pkg install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pkg_add" ]; then
    sudo pkg_add -I "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "opkg" ]; then
    sudo opkg install "${package_name}" &> "${log_redirects}"
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

  if [ "${package_manager}" = "apt" ]; then
    sudo apt purge -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "rpm-ostree" ]; then
    sudo rpm-ostree uninstall "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "dnf" ]; then
    sudo dnf remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pacman" ]; then
    sudo pacman -Rns --noconfirm "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "zypper" ]; then
    sudo zypper -n remove "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "xbps" ]; then
    sudo xbps-remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apk" ]; then
    sudo apk del --quiet "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "emerge" ]; then
    sudo emerge --unmerge --quiet "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "slackpkg" ]; then
    sudo slackpkg -batch=on -default_answer=y remove "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "eopkg" ]; then
    sudo eopkg remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pkg" ]; then
    sudo pkg delete -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pkg_add" ]; then
    sudo pkg_delete "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "opkg" ]; then
    sudo opkg remove "${package_name}" &> "${log_redirects}"
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

if [ "${init_system}" = "systemd" ] && ! command -v pihole &> /dev/null && ! command -v pihole-FTL &> /dev/null; then
  install_package systemd-resolved

  remove_package dnscrypt-proxy
  remove_package dnscrypt-proxy2

  enable_service systemd-resolved
  start_service systemd-resolved

  sudo tee /etc/systemd/resolved.conf &> /dev/null <<< ""

  sudo chattr -i /etc/resolv.conf &> "${log_redirects}"

  sudo test -f /run/systemd/resolve/stub-resolv.conf && sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf &> "${log_redirects}"

  restart_service systemd-resolved
else
  remove_package dnscrypt-proxy
  remove_package dnscrypt-proxy2

  sudo chattr -i /etc/resolv.conf &> "${log_redirects}"

  sudo tee /etc/resolv.conf &> /dev/null << EOF
nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
nameserver 1.0.0.1
nameserver 2606:4700:4700::1001
EOF
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

printf "Y\n\n" | sudo /opt/zapret/uninstall_easy.sh &> "${log_redirects}"

sudo rm -rf /opt/zapret

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Zapret успешно удален.${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Zapret başarıyla kaldırıldı.${reset}"
else
  echo -e "  ${gray}Zapret has been successfully uninstalled.${reset}"
fi

echo ""
