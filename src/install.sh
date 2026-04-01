#!/bin/bash

sudo -v

dnscrypt=false
dev=false
debug=false

for arg in "${@}"; do
  [ "${arg}" = "--dnscrypt" ] && dnscrypt=true
  [ "${arg}" = "--dev" ] && dev=true
  [ "${arg}" = "--debug" ] && debug=true
done

parameters="${*}"
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

zapret_version="72.12"

country_code=$(curl --max-time 10 -s https://ipinfo.io/country)

send_metrics() {
  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${gray}Вы хотите поделиться результатами с ${blue}Keift${gray}?${reset}"
    echo -ne "  ${gray}Это поможет нам улучшить этот инструмент. [${green}Y${gray}/${red}N${gray}] ${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${gray}Sonuçları ${blue}Keift${gray} ile paylaşmak ister misiniz?${reset}"
    echo -ne "  ${gray}Bu, aracı geliştirmemize yardımcı olur. [${green}Y${gray}/${red}N${gray}] ${reset}"
  else
    echo -e "  ${gray}Would you like to share the results with ${blue}Keift${gray}?${reset}"
    echo -ne "  ${gray}This helps us improve this tool. [${green}Y${gray}/${red}N${gray}] ${reset}"
  fi

  if [ -t 0 ]; then
    read metrics_answer
  else
    read metrics_answer < /dev/tty
  fi

  if [ "${metrics_answer,,}" = "y" ]; then
    echo ""
    if [ "${country_code}" = "RU" ]; then
      echo -e "  ${gray}Спасибо за ваш отзыв.${reset}"
    elif [ "${country_code}" = "TR" ]; then
      echo -e "  ${gray}Geri bildiriminiz için teşekkürler.${reset}"
    else
      echo -e "  ${gray}Thank you for your feedback.${reset}"
    fi

    local event="${1}"
    local unix_name=$(uname -a)
    local blockcheck_results_filtered=$(echo "${blockcheck_results}" | sed -n "/^\* SUMMARY/,/^$/p")
    local domain_response=$(curl --max-time 10 -sS -I https://"${blockcheck_domain}" 2>&1 | head -n 1)

    # Systemd
    if command -v systemctl &>/dev/null; then
      local init_system="systemd"
    # Runit
    elif command -v sv &>/dev/null; then
      local init_system="runit"
    # S6
    elif command -v s6-svscan &>/dev/null || command -v s6-rc &>/dev/null; then
      local init_system="s6"
    # OpenRC
    elif command -v rc-service &>/dev/null; then
      local init_system="openrc"
    # OpenBSD
    elif command -v rcctl &>/dev/null; then
      local init_system="openbsd"
    # FreeBSD
    elif command -v sysrc &>/dev/null; then
      local init_system="freebsd"
    # pfSense
    elif [ -f /etc/pfsense-release ] || grep -qi "pfsense" /etc/platform 2>/dev/null; then
      local init_system="pfsense"
    # SysvInit
    elif command -v service &>/dev/null || [ -x /usr/sbin/service ] || [ -x /sbin/service ]; then
      local init_system="sysvinit"
    # SysvInit
    elif [ -d /etc/init.d ]; then
      local init_system="sysvinit"
    # Entware
    elif [ -d /opt/etc/init.d ]; then
      local init_system="entware"
    # Rc
    elif [ -d /etc/rc.d ]; then
      local init_system="rc"
    # Launchd
    elif command -v launchctl &>/dev/null; then
      local init_system="launchd"
    else
      local init_system="unknown"
    fi

    if command -v apt &>/dev/null; then
      local package_manager="apt"
    elif command -v rpm-ostree &>/dev/null; then
      local package_manager="rpm-ostree"
    elif command -v dnf &>/dev/null; then
      local package_manager="dnf"
    elif command -v pacman &>/dev/null; then
      local package_manager="pacman"
    elif command -v zypper &>/dev/null; then
      local package_manager="zypper"
    elif command -v xbps-install &>/dev/null; then
      local package_manager="xbps"
    elif command -v apk &>/dev/null; then
      local package_manager="apk"
    elif command -v emerge &>/dev/null; then
      local package_manager="emerge"
    elif command -v slackpkg &>/dev/null; then
      local package_manager="slackpkg"
    elif command -v eopkg &>/dev/null; then
      local package_manager="eopkg"
    elif command -v pkg &>/dev/null; then
      local package_manager="pkg"
    elif command -v pkg_add &>/dev/null; then
      local package_manager="pkg_add"
    elif command -v opkg &>/dev/null; then
      local package_manager="opkg"
    else
      local package_manager="unknown"
    fi

    local payload=$(
      jq -n \
        --arg event "${event}" \
        --arg unix_name "${unix_name}" \
        --arg init_system "${init_system}" \
        --arg package_manager "${package_manager}" \
        --arg dns_resolver "${dns_resolver}" \
        --arg blockcheck_domain "${blockcheck_domain}" \
        --arg blockcheck_results "${blockcheck_results_filtered}" \
        --arg installation_results "${installation_results}" \
        --arg domain_response "${domain_response}" \
        --arg nfqws_options "${nfqws_options}" \
        --arg parameters "${parameters}" \
        '{
          event: $event,
          data: {
            unix_name: $unix_name,
            init_system: $init_system,
            package_manager: $package_manager,
            dns_resolver: $dns_resolver,
            blockcheck_domain: $blockcheck_domain,
            blockcheck_results: $blockcheck_results,
            installation_results: $installation_results,
            domain_response: $domain_response,
            nfqws_options: $nfqws_options,
            parameters: $parameters
          }
        }'
    )

    curl --max-time 10 -X POST https://metrics--api.keift.co/zapret \
      -H "Content-Type: application/json" \
      -d "${payload}" &>"${log_redirects}"
  else
    echo ""
    if [ "${country_code}" = "RU" ]; then
      echo -e "  ${gray}Всё в порядке, ничего не было отправлено.${reset}"
    elif [ "${country_code}" = "TR" ]; then
      echo -e "  ${gray}Sorun değil, hiçbir şey paylaşılmadı.${reset}"
    else
      echo -e "  ${gray}That's okay, nothing was shared.${reset}"
    fi
  fi

  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${gray}Нужна помощь? Свяжитесь с нами.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${gray}Yardıma mı ihtiyacınız var? Bizimle iletişime geçin.${reset}"
  else
    echo -e "  ${gray}Need help? Contact us.${reset}"
  fi
  echo ""
  echo -e "  ${blue}Discord   ${white}https://discord.gg/keift${reset}"
  echo -e "  ${cyan}Telegram  ${white}https://t.me/keiftco${reset}"
}

start_service() {
  local service_name="${1}"

  # Systemd
  if command -v systemctl &>/dev/null; then
    sudo systemctl start "${service_name}" &>"${log_redirects}"
  # Runit
  elif command -v sv &>/dev/null; then
    sudo sv start "${service_name}" &>"${log_redirects}"
  # S6
  elif command -v s6-svscan &>/dev/null || command -v s6-rc &>/dev/null; then
    if command -v s6-rc &>/dev/null; then
      sudo s6-rc -u change "${service_name}" &>"${log_redirects}"
    else
      if [ -d /etc/s6/sv ]; then
        local s6_service_dir="/etc/s6/sv"
      elif [ -d /etc/s6-servicedirs ]; then
        local s6_service_dir="/etc/s6-servicedirs"
      fi

      sudo s6-svc -u "${s6_service_dir}"/"${service_name}" &>"${log_redirects}"
    fi
  # OpenRC
  elif command -v rc-service &>/dev/null; then
    sudo rc-service "${service_name}" start &>"${log_redirects}"
  # OpenBSD
  elif command -v rcctl &>/dev/null; then
    sudo rcctl start "${service_name}" &>"${log_redirects}"
  # FreeBSD
  elif command -v sysrc &>/dev/null; then
    sudo service "${service_name}" start &>"${log_redirects}"
  # pfSense
  elif [ -f /etc/pfsense-release ] || grep -qi "pfsense" /etc/platform 2>/dev/null; then
    sudo /usr/local/etc/rc.d/"${service_name}".sh start &>"${log_redirects}"
  # SysvInit
  elif command -v service &>/dev/null || [ -x /usr/sbin/service ] || [ -x /sbin/service ]; then
    sudo service "${service_name}" start &>"${log_redirects}"
  # SysvInit
  elif [ -d /etc/init.d ]; then
    sudo /etc/init.d/"${service_name}" start &>"${log_redirects}"
  # Entware
  elif [ -d /opt/etc/init.d ]; then
    local entware_script=$(ls /opt/etc/init.d/*"${service_name}" 2>/dev/null | head -n 1)

    sudo "${entware_script}" start &>"${log_redirects}"
  # Rc
  elif [ -d /etc/rc.d ]; then
    sudo /etc/rc.d/rc."${service_name}" start &>"${log_redirects}"
  # Launchd
  elif command -v launchctl &>/dev/null; then
    sudo launchctl start "${service_name}" &>"${log_redirects}"
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

stop_service() {
  local service_name="${1}"

  # Systemd
  if command -v systemctl &>/dev/null; then
    sudo systemctl stop "${service_name}" &>"${log_redirects}"
  # Runit
  elif command -v sv &>/dev/null; then
    sudo sv stop "${service_name}" &>"${log_redirects}"
  # S6
  elif command -v s6-svscan &>/dev/null || command -v s6-rc &>/dev/null; then
    if command -v s6-rc &>/dev/null; then
      sudo s6-rc -d change "${service_name}" &>"${log_redirects}"
    else
      if [ -d /etc/s6/sv ]; then
        local s6_service_dir="/etc/s6/sv"
      elif [ -d /etc/s6-servicedirs ]; then
        local s6_service_dir="/etc/s6-servicedirs"
      fi

      sudo s6-svc -d "${s6_service_dir}"/"${service_name}" &>"${log_redirects}"
    fi
  # OpenRC
  elif command -v rc-service &>/dev/null; then
    sudo rc-service "${service_name}" stop &>"${log_redirects}"
  # OpenBSD
  elif command -v rcctl &>/dev/null; then
    sudo rcctl stop "${service_name}" &>"${log_redirects}"
  # FreeBSD
  elif command -v sysrc &>/dev/null; then
    sudo service "${service_name}" stop &>"${log_redirects}"
  # pfSense
  elif [ -f /etc/pfsense-release ] || grep -qi "pfsense" /etc/platform 2>/dev/null; then
    sudo /usr/local/etc/rc.d/"${service_name}".sh stop &>"${log_redirects}"
  # SysvInit
  elif command -v service &>/dev/null || [ -x /usr/sbin/service ] || [ -x /sbin/service ]; then
    sudo service "${service_name}" stop &>"${log_redirects}"
  # SysvInit
  elif [ -d /etc/init.d ]; then
    sudo /etc/init.d/"${service_name}" stop &>"${log_redirects}"
  # Entware
  elif [ -d /opt/etc/init.d ]; then
    local entware_script=$(ls /opt/etc/init.d/*"${service_name}" 2>/dev/null | head -n 1)

    sudo "${entware_script}" stop &>"${log_redirects}"
  # Rc
  elif [ -d /etc/rc.d ]; then
    sudo /etc/rc.d/rc."${service_name}" stop &>"${log_redirects}"
  # Launchd
  elif command -v launchctl &>/dev/null; then
    sudo launchctl stop "${service_name}" &>"${log_redirects}"
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
  if command -v systemctl &>/dev/null; then
    sudo systemctl restart "${service_name}" &>"${log_redirects}"
  # Runit
  elif command -v sv &>/dev/null; then
    sudo sv restart "${service_name}" &>"${log_redirects}"
  # S6
  elif command -v s6-svscan &>/dev/null || command -v s6-rc &>/dev/null; then
    if command -v s6-rc &>/dev/null; then
      sudo s6-rc -d change "${service_name}" &>"${log_redirects}"
      sudo s6-rc -u change "${service_name}" &>"${log_redirects}"
    else
      if [ -d /etc/s6/sv ]; then
        local s6_service_dir="/etc/s6/sv"
      elif [ -d /etc/s6-servicedirs ]; then
        local s6_service_dir="/etc/s6-servicedirs"
      fi

      sudo s6-svc -r "${s6_service_dir}"/"${service_name}" &>"${log_redirects}"
    fi
  # OpenRC
  elif command -v rc-service &>/dev/null; then
    sudo rc-service "${service_name}" restart &>"${log_redirects}"
  # OpenBSD
  elif command -v rcctl &>/dev/null; then
    sudo rcctl restart "${service_name}" &>"${log_redirects}"
  # FreeBSD
  elif command -v sysrc &>/dev/null; then
    sudo service "${service_name}" restart &>"${log_redirects}"
  # pfSense
  elif [ -f /etc/pfsense-release ] || grep -qi "pfsense" /etc/platform 2>/dev/null; then
    sudo /usr/local/etc/rc.d/"${service_name}".sh restart &>"${log_redirects}"
  # SysvInit
  elif command -v service &>/dev/null || [ -x /usr/sbin/service ] || [ -x /sbin/service ]; then
    sudo service "${service_name}" restart &>"${log_redirects}"
  # SysvInit
  elif [ -d /etc/init.d ]; then
    sudo /etc/init.d/"${service_name}" restart &>"${log_redirects}"
  # Entware
  elif [ -d /opt/etc/init.d ]; then
    local entware_script=$(ls /opt/etc/init.d/*"${service_name}" 2>/dev/null | head -n 1)

    sudo "${entware_script}" restart &>"${log_redirects}"
  # Rc
  elif [ -d /etc/rc.d ]; then
    sudo /etc/rc.d/rc."${service_name}" restart &>"${log_redirects}"
  # Launchd
  elif command -v launchctl &>/dev/null; then
    sudo launchctl stop "${service_name}" &>"${log_redirects}"
    sudo launchctl start "${service_name}" &>"${log_redirects}"
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
  if command -v systemctl &>/dev/null; then
    sudo systemctl enable "${service_name}" &>"${log_redirects}"
  # Runit
  elif command -v sv &>/dev/null; then
    if [ -d /etc/sv ]; then
      local runit_sv_dir="/etc/sv"
    elif [ -d /etc/runit/sv ]; then
      local runit_sv_dir="/etc/runit/sv"
    fi

    if [ -d /var/service ]; then
      local runit_service_dir="/var/service"
    elif [ -d /run/runit/service ]; then
      local runit_service_dir="/run/runit/service"
    elif [ -d /service ]; then
      local runit_service_dir="/service"
    fi

    sudo ln -sf "${runit_sv_dir}"/"${service_name}" "${runit_service_dir}" &>"${log_redirects}"
  # S6
  elif command -v s6-svscan &>/dev/null || command -v s6-rc &>/dev/null; then
    :
  # OpenRC
  elif command -v rc-service &>/dev/null; then
    sudo rc-update add "${service_name}" default &>"${log_redirects}"
  # OpenBSD
  elif command -v rcctl &>/dev/null; then
    sudo rcctl enable "${service_name}" &>"${log_redirects}"
  # FreeBSD
  elif command -v sysrc &>/dev/null; then
    sudo sysrc "${service_name}_enable=YES" &>"${log_redirects}"
  # pfSense
  elif [ -f /etc/pfsense-release ] || grep -qi "pfsense" /etc/platform 2>/dev/null; then
    :
  # SysvInit
  elif command -v service &>/dev/null || [ -x /usr/sbin/service ] || [ -x /sbin/service ]; then
    if command -v update-rc.d &>/dev/null || [ -x /usr/sbin/update-rc.d ] || [ -x /sbin/update-rc.d ]; then
      sudo update-rc.d "${service_name}" defaults &>"${log_redirects}"
    elif command -v chkconfig &>/dev/null || [ -x /usr/sbin/chkconfig ] || [ -x /sbin/chkconfig ]; then
      sudo chkconfig "${service_name}" on &>"${log_redirects}"
    fi
  # SysvInit
  elif [ -d /etc/init.d ]; then
    :
  # Entware
  elif [ -d /opt/etc/init.d ]; then
    :
  # Rc
  elif [ -d /etc/rc.d ]; then
    :
  # Launchd
  elif command -v launchctl &>/dev/null; then
    sudo launchctl load -w /Library/LaunchDaemons/"${service_name}".plist &>"${log_redirects}"
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

init_zapret() {
  # Systemd
  if command -v systemctl &>/dev/null; then
    # Being set up by Zapret.
    :
  # Runit
  elif command -v sv &>/dev/null; then
    if [ -d /etc/sv ]; then
      local runit_sv_dir="/etc/sv"
    elif [ -d /etc/runit/sv ]; then
      local runit_sv_dir="/etc/runit/sv"
    fi

    sudo ln -sf /opt/zapret/init.d/runit/zapret "${runit_sv_dir}"/zapret &>"${log_redirects}"

    enable_service zapret
  # S6
  elif command -v s6-svscan &>/dev/null || command -v s6-rc &>/dev/null; then
    if [ -d /etc/s6/sv ]; then
      local s6_service_dir="/etc/s6/sv"
    elif [ -d /etc/s6-servicedirs ]; then
      local s6_service_dir="/etc/s6-servicedirs"
    fi

    sudo ln -sf /opt/zapret/init.d/s6/zapret "${s6_service_dir}"/zapret &>"${log_redirects}"

    enable_service zapret
  # OpenRC
  elif command -v rc-service &>/dev/null; then
    # Being set up by Zapret.
    :
  # OpenBSD
  elif command -v rcctl &>/dev/null; then
    sudo tee /etc/rc.d/zapret &>/dev/null << 'EOF'
#!/bin/ksh

daemon="/opt/zapret/init.d/sysv/zapret"

. /etc/rc.d/rc.subr

rc_start() {
  ${daemon} start
}

rc_stop() {
  ${daemon} stop
}

rc_cmd "${1}"
EOF

    sudo chmod +x /etc/rc.d/zapret

    enable_service zapret
  # FreeBSD
  elif command -v sysrc &>/dev/null; then
    sudo ln -sf /opt/zapret/init.d/sysv/zapret /usr/local/etc/rc.d/zapret &>"${log_redirects}"

    enable_service zapret
  # pfSense
  elif [ -f /etc/pfsense-release ] || grep -qi "pfsense" /etc/platform 2>/dev/null; then
    sudo ln -sf /opt/zapret/init.d/pfsense/zapret.sh /usr/local/etc/rc.d/zapret.sh &>"${log_redirects}"

    enable_service zapret
  # SysvInit
  elif command -v service &>/dev/null || [ -x /usr/sbin/service ] || [ -x /sbin/service ]; then
    sudo ln -sf /opt/zapret/init.d/sysv/zapret /etc/init.d/zapret &>"${log_redirects}"

    enable_service zapret
  # SysvInit
  elif [ -d /etc/init.d ]; then
    sudo ln -sf /opt/zapret/init.d/sysv/zapret /etc/init.d/zapret &>"${log_redirects}"

    enable_service zapret
  # Entware
  elif [ -d /opt/etc/init.d ]; then
    sudo tee /opt/etc/init.d/S90zapret &>/dev/null << 'EOF'
#!/bin/sh

if [ "${1}" = "start" ]; then
  /opt/zapret/init.d/sysv/zapret start
elif [ "${1}" = "stop" ]; then
  /opt/zapret/init.d/sysv/zapret stop
elif [ "${1}" = "restart" ]; then
  /opt/zapret/init.d/sysv/zapret stop
  /opt/zapret/init.d/sysv/zapret start
else
  echo "Usage: ${0} {start|stop|restart}"

  exit 1
fi
EOF

    sudo chmod +x /opt/etc/init.d/S90zapret

    enable_service zapret
  # Rc
  elif [ -d /etc/rc.d ]; then
    sudo ln -sf /opt/zapret/init.d/sysv/zapret /etc/rc.d/rc.zapret &>"${log_redirects}"

    enable_service zapret
  # Launchd
  elif command -v launchctl &>/dev/null; then
    # Being set up by Zapret.
    :
  fi
}

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

update_packages() {
  if command -v apt &>/dev/null; then
    export DEBIAN_FRONTEND="noninteractive"

    sudo apt update -y &>"${log_redirects}"
  elif command -v rpm-ostree &>/dev/null; then
    sudo rpm-ostree refresh-md &>"${log_redirects}"
  elif command -v dnf &>/dev/null; then
    sudo dnf makecache -y &>"${log_redirects}"
  elif command -v pacman &>/dev/null; then
    # sudo pacman -Syu --noconfirm &>"${log_redirects}"
    :
  elif command -v zypper &>/dev/null; then
    sudo zypper -n refresh &>"${log_redirects}"
  elif command -v xbps-install &>/dev/null; then
    # sudo xbps-install -Suy &>"${log_redirects}"
    :
  elif command -v apk &>/dev/null; then
    sudo apk update --quiet &>"${log_redirects}"
  elif command -v emerge &>/dev/null; then
    sudo emerge --sync --quiet &>"${log_redirects}"
  elif command -v slackpkg &>/dev/null; then
    sudo slackpkg -batch=on update &>"${log_redirects}"
  elif command -v eopkg &>/dev/null; then
    sudo eopkg update-repo -y &>"${log_redirects}"
  elif command -v pkg &>/dev/null; then
    sudo pkg update &>"${log_redirects}"
  elif command -v pkg_add &>/dev/null; then
    # sudo pkg_add -u &>"${log_redirects}"
    :
  elif command -v opkg &>/dev/null; then
    sudo opkg update &>"${log_redirects}"
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

print_upgrade_commands() {
  if command -v pacman &>/dev/null; then
    echo ""
    echo -e "  ${yellow}sudo ${green}pacman ${white}-${cyan}Syu ${white}--${cyan}noconfirm  ${reset}"
    echo ""
  elif command -v pkg_add &>/dev/null; then
    echo ""
    echo -e "  ${yellow}sudo ${green}pkg_add ${white}-${cyan}u  ${reset}"
    echo ""
  elif command -v xbps-install &>/dev/null; then
    echo ""
    echo -e "  ${yellow}sudo ${green}xbps-install ${white}-${cyan}Suy  ${reset}"
    echo ""
  fi
}

print_head() {
  clear

  echo ""
  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${blue}Keift ${cyan}Установить Zapret${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${blue}Keift ${cyan}Zapret Kurulumu${reset}"
  else
    echo -e "  ${blue}Keift ${cyan}Install Zapret${reset}"
  fi
  echo ""
}

print_head

if [ "$(uname)" != "Linux" ]; then
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

# 1. Install dependencies

if command -v pacman &>/dev/null || \
  command -v pkg_add &>/dev/null || \
  command -v xbps-install &>/dev/null; then
  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${gray}Для стабильности установки важно поддерживать систему в актуальном состоянии.${reset}"
    echo -e "  ${gray}Вы можете обновить систему, выполнив следующие команды.${reset}"

    print_upgrade_commands

    echo -ne "  ${gray}Если вы готовы, нажмите ${blue}[ENTER]${gray}...${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${gray}Kurulumun kararlılığı açısından sisteminizi güncel tutmanız önemlidir.${reset}"
    echo -e "  ${gray}Aşağıdaki komutları yürüterek sisteminizi güncelleyebilirsiniz.${reset}"

    print_upgrade_commands

    echo -ne "  ${gray}Hazırsanız ${blue}[ENTER] ${gray}tuşuna basın...${reset}"
  else
    echo -e "  ${gray}It is important to keep your system up to date for the stability of the installation.${reset}"
    echo -e "  ${gray}You can update your system by running the following commands.${reset}"

    print_upgrade_commands

    echo -ne "  ${gray}If you are ready, press ${blue}[ENTER]${gray}...${reset}"
  fi

  if [ -t 0 ]; then
    read -r
  else
    read -r < /dev/tty
  fi

  print_head
fi

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Установка зависимостей...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Bağımlılıklar yükleniyor...${reset}"
else
  echo -e "  ${gray}Installing dependencies...${reset}"
fi

update_packages

install_package bind
install_package bind-tools
install_package bind-utils
install_package bind9-dnsutils
install_package bind920
install_package curl
install_package iptables
install_package jq
install_package nftables
install_package unzip
install_package wget
install_package wget-ssl

# 2. Change DNS settings

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Настройки DNS изменяются...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}DNS ayarları değiştiriliyor...${reset}"
else
  echo -e "  ${gray}DNS settings are being changed...${reset}"
fi

if command -v systemctl &>/dev/null && ! command -v pihole &>/dev/null && ! command -v pihole-FTL &>/dev/null; then
  if [ "${dnscrypt}" = false ] && \
    ( dig -p 853 +tls +tls-hostname=one.one.one.one +tries=1 +time=10 @1.1.1.1 &>"${log_redirects}" || \
    dig -p 853 +tls +tls-hostname=one.one.one.one +tries=1 +time=10 @2606:4700:4700::1111 &>"${log_redirects}" || \
    dig -p 853 +tls +tls-hostname=one.one.one.one +tries=1 +time=10 @1.0.0.1 &>"${log_redirects}" || \
    dig -p 853 +tls +tls-hostname=one.one.one.one +tries=1 +time=10 @2606:4700:4700::1001 &>"${log_redirects}" ); then
    dns_resolver="systemd-resolved"

    update_packages

    install_package systemd-resolved
    remove_package dnscrypt-proxy
    remove_package dnscrypt-proxy2

    enable_service systemd-resolved
    start_service systemd-resolved

    sudo tee /etc/systemd/resolved.conf &>/dev/null << EOF
[Resolve]
DNS=1.1.1.1#one.one.one.one
DNS=2606:4700:4700::1111#one.one.one.one
DNS=1.0.0.1#one.one.one.one
DNS=2606:4700:4700::1001#one.one.one.one

DNSOverTLS=yes
EOF

    sudo chattr -i /etc/resolv.conf &>"${log_redirects}"

    [ -f /run/systemd/resolve/stub-resolv.conf ] && sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf &>"${log_redirects}"

    restart_service systemd-resolved
  else
    dns_resolver="dnscrypt-proxy"

    update_packages

    if command -v pkg &>/dev/null || command -v opkg &>/dev/null; then
      install_package dnscrypt-proxy2
    else
      install_package dnscrypt-proxy
    fi

    enable_service systemd-resolved
    start_service systemd-resolved

    enable_service dnscrypt-proxy
    enable_service dnscrypt-proxy2
    start_service dnscrypt-proxy
    start_service dnscrypt-proxy2

    if [ -f /etc/dnscrypt-proxy/dnscrypt-proxy.toml ]; then
      dnscrypt_path="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    elif [ -f /etc/dnscrypt-proxy.toml ]; then
      dnscrypt_path="/etc/dnscrypt-proxy.toml"
    elif [ -f /opt/etc/dnscrypt-proxy.toml ]; then
      dnscrypt_path="/opt/etc/dnscrypt-proxy.toml"
    elif [ -f /usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml ]; then
      dnscrypt_path="/usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    elif [ -f /usr/share/defaults/dnscrypt-proxy/dnscrypt-proxy.toml ]; then
      sudo mkdir -p /etc/dnscrypt-proxy &>"${log_redirects}"

      sudo cp /usr/share/defaults/dnscrypt-proxy/dnscrypt-proxy.toml /etc/dnscrypt-proxy &>"${log_redirects}"

      dnscrypt_path="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    else
      if [ "${country_code}" = "RU" ]; then
        echo -e "  ${red}Путь к DNSCrypt Proxy не найден.${reset}"
      elif [ "${country_code}" = "TR" ]; then
        echo -e "  ${red}DNSCrypt Proxy yolu bulunamadı.${reset}"
      else
        echo -e "  ${red}DNSCrypt Proxy path could not be found.${reset}"
      fi

      echo ""

      exit 1
    fi

    sudo tee /etc/systemd/resolved.conf &>/dev/null <<< ""

    sudo chattr -i /etc/resolv.conf &>"${log_redirects}"

    [ -f /run/systemd/resolve/stub-resolv.conf ] && sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf &>"${log_redirects}"

    restart_service systemd-resolved

    sudo tee "${dnscrypt_path}" &>/dev/null << EOF
listen_addresses = ["127.0.0.1:5300", "[::1]:5300"]

[sources]
  [sources."public-resolvers"]
  urls = ["https://raw.github.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md", "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"]
  minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
  cache_file = "/var/cache/dnscrypt-proxy/public-resolvers-v3.md"
EOF

    restart_service dnscrypt-proxy
    restart_service dnscrypt-proxy2

    while ! dig -p 5300 +tries=1 +time=10 @127.0.0.1 &>/dev/null; do
      restart_service dnscrypt-proxy
      restart_service dnscrypt-proxy2

      sleep 10
    done

    sudo tee /etc/systemd/resolved.conf &>/dev/null << EOF
[Resolve]
DNS=127.0.0.1:5300
DNS=[::1]:5300

Domains=~.
DNSOverTLS=no
EOF

    sudo chattr -i /etc/resolv.conf &>"${log_redirects}"

    [ -f /run/systemd/resolve/stub-resolv.conf ] && sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf &>"${log_redirects}"

    restart_service systemd-resolved
  fi
else
  dns_resolver="dnscrypt-proxy"

  update_packages

  if command -v pkg &>/dev/null || command -v opkg &>/dev/null; then
    install_package dnscrypt-proxy2
  else
    install_package dnscrypt-proxy
  fi

  enable_service dnscrypt-proxy
  enable_service dnscrypt-proxy2
  start_service dnscrypt-proxy
  start_service dnscrypt-proxy2

  if [ -f /etc/dnscrypt-proxy/dnscrypt-proxy.toml ]; then
    dnscrypt_path="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
  elif [ -f /etc/dnscrypt-proxy.toml ]; then
    dnscrypt_path="/etc/dnscrypt-proxy.toml"
  elif [ -f /opt/etc/dnscrypt-proxy.toml ]; then
    dnscrypt_path="/opt/etc/dnscrypt-proxy.toml"
  elif [ -f /usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml ]; then
    dnscrypt_path="/usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
  elif [ -f /usr/share/defaults/dnscrypt-proxy/dnscrypt-proxy.toml ]; then
    sudo mkdir -p /etc/dnscrypt-proxy &>"${log_redirects}"

    sudo cp /usr/share/defaults/dnscrypt-proxy/dnscrypt-proxy.toml /etc/dnscrypt-proxy &>"${log_redirects}"

    dnscrypt_path="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
  else
    if [ "${country_code}" = "RU" ]; then
      echo -e "  ${red}Путь к DNSCrypt Proxy не найден.${reset}"
    elif [ "${country_code}" = "TR" ]; then
      echo -e "  ${red}DNSCrypt Proxy yolu bulunamadı.${reset}"
    else
      echo -e "  ${red}DNSCrypt Proxy path could not be found.${reset}"
    fi

    echo ""

    exit 1
  fi

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

  if command -v pihole &>/dev/null || command -v pihole-FTL &>/dev/null; then
    dns_resolver="pihole"

    sudo tee "${dnscrypt_path}" &>/dev/null << EOF
listen_addresses = ["127.0.0.1:5300", "[::1]:5300"]

[sources]
  [sources."public-resolvers"]
  urls = ["https://raw.github.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md", "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"]
  minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
  cache_file = "/var/cache/dnscrypt-proxy/public-resolvers-v3.md"
EOF

    restart_service dnscrypt-proxy
    restart_service dnscrypt-proxy2

    while ! dig -p 5300 +tries=1 +time=10 @127.0.0.1 &>/dev/null; do
      restart_service dnscrypt-proxy
      restart_service dnscrypt-proxy2

      sleep 10
    done

    echo ""
    if [ "${country_code}" = "RU" ]; then
      echo -e "  ${gray}Похоже, вы используете ${red}Pi-hole${gray}.${reset}"
      echo -e "  ${gray}Измените параметр ${green}Custom DNS ${gray}в Pi-hole на: ${white}127.0.0.1#5300${reset}"
      echo -ne "  ${gray}Нажмите ${blue}[ENTER] ${gray}после внесения этого изменения, чтобы продолжить...${reset}"
    elif [ "${country_code}" = "TR" ]; then
      echo -e "  ${gray}Görünüşe göre ${red}Pi-hole${gray} kullanıyorsunuz.${reset}"
      echo -e "  ${gray}Pi-hole'daki ${green}Custom DNS ${gray}seçeneğini şuna değiştirin: ${white}127.0.0.1#5300${reset}"
      echo -ne "  ${gray}Devam etmek için bu değişikliği yaptıktan sonra ${blue}[ENTER] ${gray}tuşuna basın...${reset}"
    else
      echo -e "  ${gray}It appears you are using ${red}Pi-hole${gray}.${reset}"
      echo -e "  ${gray}Change the ${green}Custom DNS ${gray}option in the Pi-hole to: ${white}127.0.0.1#5300${reset}"
      echo -ne "  ${gray}Press ${blue}[ENTER] ${gray}after you have made this change to continue...${reset}"
    fi

    if [ -t 0 ]; then
      read -r
    else
      read -r < /dev/tty
    fi

    echo ""
  else
    sudo tee "${dnscrypt_path}" &>/dev/null << EOF
listen_addresses = ["127.0.0.1:53", "[::1]:53"]

[sources]
  [sources."public-resolvers"]
  urls = ["https://raw.github.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md", "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"]
  minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
  cache_file = "/var/cache/dnscrypt-proxy/public-resolvers-v3.md"
EOF

    restart_service dnscrypt-proxy
    restart_service dnscrypt-proxy2

    while ! dig -p 53 +tries=1 +time=10 @127.0.0.1 &>/dev/null; do
      restart_service dnscrypt-proxy
      restart_service dnscrypt-proxy2

      sleep 10
    done
  fi

  sudo chattr -i /etc/resolv.conf &>"${log_redirects}"

  if dig -p 53 +tries=1 +time=10 @"${local_resolver}" &>/dev/null; then
    sudo tee /etc/resolv.conf &>/dev/null << EOF
nameserver 127.0.0.1
nameserver ::1

nameserver ${local_resolver}

nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
nameserver 1.0.0.1
nameserver 2606:4700:4700::1001
EOF
  else
    sudo tee /etc/resolv.conf &>/dev/null << EOF
nameserver 127.0.0.1
nameserver ::1

nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
nameserver 1.0.0.1
nameserver 2606:4700:4700::1001
EOF
  fi

  sudo chattr +i /etc/resolv.conf &>"${log_redirects}"
fi

# 3. Download Zapret

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Скачивание Zapret...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Zapret indiriliyor...${reset}"
else
  echo -e "  ${gray}Downloading Zapret...${reset}"
fi

sudo rm -rf /tmp/zapret
sudo rm -rf /tmp/zapret.zip

sudo wget -O /tmp/zapret.zip https://github.com/bol-van/zapret/releases/download/v"${zapret_version}"/zapret-v"${zapret_version}".zip &>"${log_redirects}"

sudo unzip -d /tmp /tmp/zapret.zip &>"${log_redirects}"

sudo mv /tmp/zapret-v"${zapret_version}" /tmp/zapret

sudo rm -rf /tmp/zapret.zip

# 4. Prepare for installation

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Подготовка к установке...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Kuruluma hazırlanıyor...${reset}"
else
  echo -e "  ${gray}Preparing for installation...${reset}"
fi

printf "Y\n\n" | sudo /opt/zapret/uninstall_easy.sh &>"${log_redirects}"
sudo rm -rf /opt/zapret

printf "\n\n" | sudo /tmp/zapret/install_prereq.sh &>"${log_redirects}"
sudo /tmp/zapret/install_bin.sh &>"${log_redirects}"

# 5. Do Blockcheck

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Выполняется Blockcheck, это может занять несколько минут...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Blockcheck yapılıyor, bu birkaç dakika sürebilir...${reset}"
else
  echo -e "  ${gray}Blockcheck is being performed, this may take a few minutes...${reset}"
fi

blockcheck_domains=(
  "discord.com"
  "facebook.com"
  "google.com"
  "instagram.com"
  "pornhub.com"
  "roblox.com"
  "steampowered.com"
  "tiktok.com"
  "x.com"
  "yandex.com"
  "youtube.com"
)

blockcheck_domain="google.com"

for domain in "${blockcheck_domains[@]}"; do
  if ! curl --max-time 10 https://"${domain}" &>/dev/null; then
    blockcheck_domain="${domain}"

    break
  fi
done

while [ $# -gt 0 ]; do
  if echo "${1}" | grep -q "^--blockcheck-domain="; then
    blockcheck_domain="${1#*=}"

    shift
  elif [ "${1}" = "--blockcheck-domain" ]; then
    blockcheck_domain="${2}"

    shift 2
  else
    shift
  fi
done

if [ "${dev}" = true ]; then
  nfqws_options="--dpi-desync=fakeddisorder --dpi-desync-ttl=1 --dpi-desync-autottl=-1 --dpi-desync-split-pos=1"
else
  blockcheck_results=$(printf "${blockcheck_domain}\n\n\n\n\n\n\n\n" | sudo /tmp/zapret/blockcheck.sh 2>"${log_redirects}")

  [ "${debug}" = true ] && echo "${blockcheck_results}"

  nfqws_options=$(echo "${blockcheck_results}" | sed -n "/^\* SUMMARY/,/^$/p" | grep -E "curl_test_http|curl_test_https_tls12" | grep "ipv4 ${blockcheck_domain} : nfqws" | tail -n 5 | head -n 1 | sed "s/.*nfqws //" | sed "s|/tmp/zapret|/opt/zapret|g" | sed "s/[[:space:]]*\$//")
fi

if echo "${blockcheck_results}" | grep -q "nftables queue support is not available"; then
  printf "Y\n\n" | sudo /opt/zapret/uninstall_easy.sh &>"${log_redirects}"
  sudo rm -rf /opt/zapret
  sudo rm -rf /tmp/zapret

  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${red}Вам необходимо обновить и перезагрузить систему.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${red}Sisteminizi güncellemeniz ve yeniden başlatmanız gerekiyor.${reset}"
  else
    echo -e "  ${red}You need to update and reboot your system.${reset}"
  fi

  echo ""

  send_metrics ZAPRET_UPDATE_AND_REBOOT_REQUIRED

  echo ""

  exit 1
fi

if echo "${blockcheck_results}" | grep -q "curl_test_http ipv4 ${blockcheck_domain} : working without bypass" && \
  echo "${blockcheck_results}" | grep -q "curl_test_https_tls12 ipv4 ${blockcheck_domain} : working without bypass"; then
  printf "Y\n\n" | sudo /opt/zapret/uninstall_easy.sh &>"${log_redirects}"
  sudo rm -rf /opt/zapret
  sudo rm -rf /tmp/zapret

  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${gray}Ограничений доступа не обнаружено.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${gray}Erişim kısıtlaması tespit edilmedi.${reset}"
  else
    echo -e "  ${gray}No access restrictions were detected.${reset}"
  fi

  echo ""

  send_metrics ZAPRET_NO_ACCESS_RESTRICTIONS_WERE_DETECTED

  echo ""

  exit 0
fi

# 6. Install Zapret

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Установка Zapret...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Zapret kuruluyor...${reset}"
else
  echo -e "  ${gray}Installing Zapret...${reset}"
fi

prototype_installation_results=$(printf "\n\n" | sudo /tmp/zapret/install_easy.sh 2>"${log_redirects}")

if echo "${prototype_installation_results}" | grep -q "system is not either systemd"; then
  if sudo test -w /bin; then
    installation_results=$(printf "Y\nY\nY\n\n\n\n\n\n\nY\n\n\n\n\n" | sudo /tmp/zapret/install_easy.sh 2>"${log_redirects}")
  else
    installation_results=$(printf "Y\nY\nY\nY\nY\n\n\n\n\n\n\nY\n\n\n\n\n" | sudo /tmp/zapret/install_easy.sh 2>"${log_redirects}")
  fi
else
  if sudo test -w /bin; then
    installation_results=$(printf "Y\n\n\n\n\n\n\nY\n\n\n\n\n" | sudo /tmp/zapret/install_easy.sh 2>"${log_redirects}")
  else
    installation_results=$(printf "Y\nY\nY\n\n\n\n\n\n\nY\n\n\n\n\n" | sudo /tmp/zapret/install_easy.sh 2>"${log_redirects}")
  fi
fi

[ "${debug}" = true ] && echo "${installation_results}"

if echo "${installation_results}" | grep -q "could not start zapret service"; then
  printf "Y\n\n" | sudo /opt/zapret/uninstall_easy.sh &>"${log_redirects}"
  sudo rm -rf /opt/zapret
  sudo rm -rf /tmp/zapret

  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${red}Что-то пошло не так.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${red}Bir şeyler ters gitti.${reset}"
  else
    echo -e "  ${red}Something went wrong.${reset}"
  fi

  echo ""

  send_metrics ZAPRET_SOMETHING_WENT_WRONG

  echo ""

  exit 1
fi

echo "${installation_results}" | grep -q "system is not either systemd" && init_zapret

start_service zapret

sudo touch /opt/zapret/hostlist.txt
sudo touch /opt/zapret/ipset/zapret-hostlist-auto.txt

sudo sed -i "/^NFQWS_OPT=\"/,/^\"/c NFQWS_OPT=\"${nfqws_options} --hostlist=/opt/zapret/hostlist.txt --hostlist-auto=/opt/zapret/ipset/zapret-hostlist-auto.txt\"" /opt/zapret/config

restart_service zapret

for domain in "${blockcheck_domains[@]}"; do
  for i in {1..3}; do
    curl --max-time 1 https://"${domain}" &>/dev/null
  done
done

# 7. Finish the installation

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Zapret успешно установлен.${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Zapret başarıyla kuruldu.${reset}"
else
  echo -e "  ${gray}Zapret was successfully installed.${reset}"
fi

sudo rm -rf /tmp/zapret

echo ""

send_metrics ZAPRET_INSTALLATION_SUCCESSFUL

echo ""