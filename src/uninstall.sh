#!/usr/bin/env bash

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

legible="\e[0m"
black="\e[30m"
red="\e[31m"
green="\e[32m"
yellow="\e[33m"
blue="\e[34m"
magenta="\e[35m"
cyan="\e[36m"
white="\e[37m"
gray="\e[90m"

version="1.3"

last_commit_id=$(curl -s --max-time 10 https://api.github.com/repos/keift/zapret/commits/main | grep -m 1 '"sha":' | cut -d '"' -f 4 | cut -c 1-7)

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
  elif [ -d /opt/etc/init.d ]; then
    init_system="entware"
  # SysVinit
  elif command -v service &> /dev/null || [ -x /usr/sbin/service ] || [ -x /sbin/service ] || [ -d /etc/init.d ]; then
    init_system="sysvinit"
  # Rc
  elif [ -d /etc/rc.d ]; then
    init_system="rc"
  else
    init_system="unknown"
  fi

  if command -v rpm-ostree &> /dev/null; then
    package_manager="rpm-ostree"
  elif command -v apt &> /dev/null; then
    package_manager="apt"
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
      local s6_services_dirs=(
        "/etc/s6-servicedirs"
        "/etc/s6/sv"
      )

      for dir in "${s6_services_dirs[@]}"; do
        if [ -d "${dir}" ]; then
          local s6_services_dir="${dir}"

          break
        fi
      done

      s6-svc -u "${s6_services_dir}"/"${service_name}" &> "${log_redirects}"
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
    if command -v service &> /dev/null || [ -x /usr/sbin/service ] || [ -x /sbin/service ]; then
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
      local s6_services_dirs=(
        "/etc/s6-servicedirs"
        "/etc/s6/sv"
      )

      for dir in "${s6_services_dirs[@]}"; do
        if [ -d "${dir}" ]; then
          local s6_services_dir="${dir}"

          break
        fi
      done

      s6-svc -r "${s6_services_dir}"/"${service_name}" &> "${log_redirects}"
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
    if command -v service &> /dev/null || [ -x /usr/sbin/service ] || [ -x /sbin/service ]; then
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
    local runit_services_dirs=(
      "/etc/sv"
      "/etc/runit/sv"
    )

    local runit_enables_dirs=(
      "/etc/service"
      "/var/service"
      "/run/runit/service"
      "/service"
    )

    for dir in "${runit_services_dirs[@]}"; do
      if [ -d "${dir}" ]; then
        local runit_services_dir="${dir}"

        break
      fi
    done

    for dir in "${runit_enables_dirs[@]}"; do
      if [ -d "${dir}" ]; then
        local runit_enables_dir="${dir}"

        break
      fi
    done

    [ -d "${runit_services_dir}"/"${service_name}" ] && ln -sf "${runit_services_dir}"/"${service_name}" "${runit_enables_dir}"/"${service_name}" &> "${log_redirects}"
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
    if command -v service &> /dev/null || [ -x /usr/sbin/service ] || [ -x /sbin/service ]; then
      if command -v update-rc.d &> /dev/null || [ -x /usr/sbin/update-rc.d ] || [ -x /sbin/update-rc.d ]; then
        update-rc.d "${service_name}" defaults &> "${log_redirects}"
      elif command -v chkconfig &> /dev/null || [ -x /usr/sbin/chkconfig ] || [ -x /sbin/chkconfig ]; then
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

  if [ "${package_manager}" = "rpm-ostree" ]; then
    rpm-ostree install -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apt" ]; then
    apt install -y "${package_name}" &> "${log_redirects}"
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

uninstall_package() {
  local package_name="${1}"

  if [ "${package_manager}" = "rpm-ostree" ]; then
    rpm-ostree uninstall -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apt" ]; then
    apt remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "dnf" ]; then
    dnf remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "pacman" ]; then
    pacman -R --noconfirm "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "zypper" ]; then
    zypper -n remove "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "xbps" ]; then
    xbps-remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "apk" ]; then
    apk del "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "emerge" ]; then
    emerge --unmerge "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "slackpkg" ]; then
    slackpkg -batch=on -default_answer=y remove "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "eopkg" ]; then
    eopkg remove -y "${package_name}" &> "${log_redirects}"
  elif [ "${package_manager}" = "opkg" ]; then
    opkg remove "${package_name}" &> "${log_redirects}"
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

  if [ -n "${last_commit_id}" ]; then
    local version_text="${gray}v${version} (${last_commit_id})"
  else
    local version_text="${gray}v${version}"
  fi

  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${blue}Keift ${cyan}Удалить Zapret ${version_text}${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${blue}Keift ${cyan}Zapret Kaldırma ${version_text}${reset}"
  else
    echo -e "  ${blue}Keift ${cyan}Uninstall Zapret ${version_text}${reset}"
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

if [ "${EUID}" != "0" ]; then
  print_head

  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${red}Недостаточно прав. Попробуйте запустить с помощью этой команды.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${red}İzinler eksik. Şu komut ile çalıştırmayı deneyin.${reset}"
  else
    echo -e "  ${red}Missing permissions. Try running it with the following command.${reset}"
  fi

  echo ""

  echo -e "  ${green}curl ${legible}-${yellow}fsSL ${cyan}https://raw.github.com/keift/zapret/refs/heads/main/src/uninstall.sh ${legible}| ${green}sudo ${cyan}bash${reset}"

  echo ""

  exit 1
fi

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${legible}Настройки DNS удаляются...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${legible}DNS ayarları kaldırılıyor...${reset}"
else
  echo -e "  ${legible}DNS settings are being removed...${reset}"
fi

if [ "${init_system}" = "systemd" ]; then
  curl -fsSL https://raw.github.com/keift/dnsd/refs/heads/main/uninstall.sh | bash &> /dev/null
else
  uninstall_package dnscrypt-proxy
  uninstall_package dnscrypt-proxy2

  uninstall_package dnscrypt-proxy-"${init_system}"
  uninstall_package dnscrypt-proxy2-"${init_system}"

  [ "${package_manager}" = "rpm-ostree" ] && rpm-ostree apply-live &> "${log_redirects}"

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
    echo -e "  ${legible}Zapret уже не установлен.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${legible}Zapret zaten kurulu değil.${reset}"
  else
    echo -e "  ${legible}Zapret already not installed.${reset}"
  fi

  echo ""

  exit 0
fi

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${legible}Удаление Zapret...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${legible}Zapret kaldırılıyor...${reset}"
else
  echo -e "  ${legible}Uninstalling Zapret...${reset}"
fi

echo -e "Y\n\n" | /opt/zapret/uninstall_easy.sh &> "${log_redirects}"
rm -rf /opt/zapret &> "${log_redirects}"

rm -rf /etc/systemd/system/zapret.service &> "${log_redirects}"

rm -rf /etc/systemd/system/zapret-list-update.service &> "${log_redirects}"
rm -rf /etc/systemd/system/zapret-list-update.timer &> "${log_redirects}"

rm -rf /etc/systemd/system/tpws@.service &> "${log_redirects}"
rm -rf /etc/systemd/system/nfqws@.service &> "${log_redirects}"

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${legible}Zapret успешно удален.${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${legible}Zapret başarıyla kaldırıldı.${reset}"
else
  echo -e "  ${legible}Zapret has been successfully uninstalled.${reset}"
fi

echo ""
