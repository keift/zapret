#!/bin/bash

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

country_code=$(curl -s --max-time 10 https://ipinfo.io/country)

detect_system() {
  # Systemd
  if command -v systemctl &> /dev/null; then
    init_system="systemd"
  # Dinit
  elif command -v dinitctl &> /dev/null; then
    init_system="dinit"
  # Runit
  elif command -v sv &> /dev/null; then
    init_system="runit"
  # S6
  elif command -v s6-svscan &> /dev/null || command -v s6-rc &> /dev/null; then
    init_system="s6"
  # OpenRC
  elif command -v rc-service &> /dev/null; then
    init_system="openrc"
  # Launchd
  elif command -v launchctl &> /dev/null; then
    init_system="launchd"
  # Entware
  elif test -d /opt/etc/init.d; then
    init_system="entware"
  # SysVinit
  elif command -v service &> /dev/null || test -x /usr/sbin/service || test -x /sbin/service || test -d /etc/init.d; then
    init_system="sysvinit"
  # Rc
  elif test -d /etc/rc.d; then
    init_system="rc"
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
    systemctl start "${service_name}" &> "${log_redirects}"
  # Dinit
  elif [ "${init_system}" = "dinit" ]; then
    dinitctl start "${service_name}" &> "${log_redirects}"
  # Runit
  elif [ "${init_system}" = "runit" ]; then
    sv start "${service_name}" &> "${log_redirects}"
  # S6
  elif [ "${init_system}" = "s6" ]; then
    if command -v s6-rc &> /dev/null; then
      s6-rc -u change "${service_name}" &> "${log_redirects}"
    else
      if test -d /etc/s6-servicedirs; then
        local s6_service_dir="/etc/s6-servicedirs"
      elif test -d /etc/s6/sv; then
        local s6_service_dir="/etc/s6/sv"
      fi

      s6-svc -u "${s6_service_dir}"/"${service_name}" &> "${log_redirects}"
    fi
  # OpenRC
  elif [ "${init_system}" = "openrc" ]; then
    rc-service "${service_name}" start &> "${log_redirects}"
  # Launchd
  elif [ "${init_system}" = "launchd" ]; then
    launchctl start "${service_name}" &> "${log_redirects}"
  # Entware
  elif [ "${init_system}" = "entware" ]; then
    local entware_script=$(ls /opt/etc/init.d/*"${service_name}" 2> /dev/null | head -n 1)

    "${entware_script}" start &> "${log_redirects}"
  # SysVinit
  elif [ "${init_system}" = "sysvinit" ]; then
    if command -v service &> /dev/null || test -x /usr/sbin/service || test -x /sbin/service; then
      service "${service_name}" start &> "${log_redirects}"
    else
      /etc/init.d/"${service_name}" start &> "${log_redirects}"
    fi
  # Rc
  elif [ "${init_system}" = "rc" ]; then
    /etc/rc.d/rc."${service_name}" start &> "${log_redirects}"
  else
    print_head

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
    systemctl restart "${service_name}" &> "${log_redirects}"
  # Dinit
  elif [ "${init_system}" = "dinit" ]; then
    dinitctl restart "${service_name}" &> "${log_redirects}"
  # Runit
  elif [ "${init_system}" = "runit" ]; then
    sv restart "${service_name}" &> "${log_redirects}"
  # S6
  elif [ "${init_system}" = "s6" ]; then
    if command -v s6-rc &> /dev/null; then
      s6-rc -d change "${service_name}" &> "${log_redirects}"
      s6-rc -u change "${service_name}" &> "${log_redirects}"
    else
      if test -d /etc/s6-servicedirs; then
        local s6_service_dir="/etc/s6-servicedirs"
      elif test -d /etc/s6/sv; then
        local s6_service_dir="/etc/s6/sv"
      fi

      s6-svc -r "${s6_service_dir}"/"${service_name}" &> "${log_redirects}"
    fi
  # OpenRC
  elif [ "${init_system}" = "openrc" ]; then
    rc-service "${service_name}" restart &> "${log_redirects}"
  # Launchd
  elif [ "${init_system}" = "launchd" ]; then
    launchctl stop "${service_name}" &> "${log_redirects}"
    launchctl start "${service_name}" &> "${log_redirects}"
  # Entware
  elif [ "${init_system}" = "entware" ]; then
    local entware_script=$(ls /opt/etc/init.d/*"${service_name}" 2> /dev/null | head -n 1)

    "${entware_script}" restart &> "${log_redirects}"
  # SysVinit
  elif [ "${init_system}" = "sysvinit" ]; then
    if command -v service &> /dev/null || test -x /usr/sbin/service || test -x /sbin/service; then
      service "${service_name}" restart &> "${log_redirects}"
    else
      /etc/init.d/"${service_name}" restart &> "${log_redirects}"
    fi
  # Rc
  elif [ "${init_system}" = "rc" ]; then
    /etc/rc.d/rc."${service_name}" restart &> "${log_redirects}"
  else
    print_head

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
    systemctl enable "${service_name}" &> "${log_redirects}"
  # Dinit
  elif [ "${init_system}" = "dinit" ]; then
    dinitctl enable "${service_name}" &> "${log_redirects}"
  # Runit
  elif [ "${init_system}" = "runit" ]; then
    if test -d /etc/sv; then
      local runit_sv_dir="/etc/sv"
    elif test -d /etc/runit/sv; then
      local runit_sv_dir="/etc/runit/sv"
    fi

    if test -d /var/service; then
      local runit_service_dir="/var/service"
    elif test -d /run/runit/service; then
      local runit_service_dir="/run/runit/service"
    elif test -d /service; then
      local runit_service_dir="/service"
    fi

    test -d "${runit_sv_dir}"/"${service_name}" && ln -sf "${runit_sv_dir}"/"${service_name}" "${runit_service_dir}" &> "${log_redirects}"
  # S6
  elif [ "${init_system}" = "s6" ]; then
    :
  # OpenRC
  elif [ "${init_system}" = "openrc" ]; then
    rc-update add "${service_name}" default &> "${log_redirects}"
  # Launchd
  elif [ "${init_system}" = "launchd" ]; then
    launchctl load -w /Library/LaunchDaemons/"${service_name}".plist &> "${log_redirects}"
  # Entware
  elif [ "${init_system}" = "entware" ]; then
    :
  # SysVinit
  elif [ "${init_system}" = "sysvinit" ]; then
    if command -v service &> /dev/null || test -x /usr/sbin/service || test -x /sbin/service; then
      if command -v update-rc.d &> /dev/null || test -x /usr/sbin/update-rc.d || test -x /sbin/update-rc.d; then
        update-rc.d "${service_name}" defaults &> "${log_redirects}"
      elif command -v chkconfig &> /dev/null || test -x /usr/sbin/chkconfig || test -x /sbin/chkconfig; then
        chkconfig "${service_name}" on &> "${log_redirects}"
      fi
    else
      :
    fi
  # Rc
  elif [ "${init_system}" = "rc" ]; then
    :
  else
    print_head

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
    apt install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "rpm-ostree" ]; then
    rpm-ostree install --apply-live "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "dnf" ]; then
    dnf install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pacman" ]; then
    pacman -S --noconfirm "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "zypper" ]; then
    zypper -n install "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "xbps" ]; then
    xbps-install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apk" ]; then
    apk add "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "emerge" ]; then
    emerge "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "slackpkg" ]; then
    slackpkg -batch=on -default_answer=y install "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "eopkg" ]; then
    eopkg install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "opkg" ]; then
    opkg install "${package_name}" &> "${log_redirects}"
  else
    print_head

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
    apt purge -y --autoremove "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "rpm-ostree" ]; then
    rpm-ostree uninstall --apply-live "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "dnf" ]; then
    dnf remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pacman" ]; then
    pacman -Rns --noconfirm "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "zypper" ]; then
    zypper -n remove -u "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "xbps" ]; then
    xbps-remove -Ry "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apk" ]; then
    apk del "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "emerge" ]; then
    emerge --unmerge "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "slackpkg" ]; then
    slackpkg -batch=on -default_answer=y remove "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "eopkg" ]; then
    eopkg remove -y --purge "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "opkg" ]; then
    opkg remove --autoremove "${package_name}" &> "${log_redirects}"
  else
    print_head

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

if [ "$(uname)" != "Linux" ]; then
  print_head

  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${red}Неподдерживаемая система.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${red}Desteklenmeyen sistem.${reset}"
  else
    echo -e "  ${red}Unsupported system.${reset}"
  fi
  echo ""

  exit 1
fi

if [ "${EUID}" -ne 0 ]; then
  print_head

  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${red}Недостаточно прав. Попробуйте запустить с помощью этой команды.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${red}İzinler eksik. Şu komut ile çalıştırmayı deneyin.${reset}"
  else
    echo -e "  ${red}Missing permissions. Try running it with the following command.${reset}"
  fi

  echo ""

  echo -e "  ${green}curl ${white}-${yellow}fsSL ${cyan}https://raw.github.com/keift/zapret/main/src/uninstall.sh ${gray}| ${green}sudo ${cyan}bash${reset}"

  echo ""

  exit 1
fi

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Настройки DNS удаляются...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}DNS ayarları kaldırılıyor...${reset}"
else
  echo -e "  ${gray}DNS settings are being removed...${reset}"
fi

if [ "${init_system}" = "systemd" ]; then
  install_package systemd-resolved

  remove_package dnscrypt-proxy
  remove_package dnscrypt-proxy2

  remove_package dnscrypt-proxy-"${init_system}"
  remove_package dnscrypt-proxy2-"${init_system}"

  enable_service systemd-resolved
  start_service systemd-resolved

  tee /etc/systemd/resolved.conf &> /dev/null <<< ""

  chattr -i /etc/resolv.conf &> "${log_redirects}"

  test -f /run/systemd/resolve/stub-resolv.conf && ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf &> "${log_redirects}"

  restart_service systemd-resolved
else
  remove_package dnscrypt-proxy
  remove_package dnscrypt-proxy2

  remove_package dnscrypt-proxy-"${init_system}"
  remove_package dnscrypt-proxy2-"${init_system}"

  chattr -i /etc/resolv.conf &> "${log_redirects}"

  tee /etc/resolv.conf &> /dev/null << EOF
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

echo -e "Y\n\n" | /opt/zapret/uninstall_easy.sh &> "${log_redirects}"

rm -rf /opt/zapret &> "${log_redirects}"

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Zapret успешно удален.${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Zapret başarıyla kaldırıldı.${reset}"
else
  echo -e "  ${gray}Zapret has been successfully uninstalled.${reset}"
fi

echo ""
