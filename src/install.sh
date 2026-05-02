#!/bin/bash

dev=false
debug=false

for arg in "${@}"; do
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

zapret_version="72.12"

country_code=$(curl -s --max-time 10 https://ipinfo.io/country)

dns_resolver="unknown"
blockcheck_domain="unknown"

send_metrics() {
  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${gray}Вы хотите поделиться результатами с ${blue}Keift${gray}?${reset}"
    echo -ne "  ${gray}Это поможет нам улучшить этот инструмент. [${green}Д${gray}/${red}Н${gray}] ${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${gray}Sonuçları ${blue}Keift ${gray}ile paylaşmak ister misiniz?${reset}"
    echo -ne "  ${gray}Bu, aracı geliştirmemize yardımcı olur. [${green}E${gray}/${red}H${gray}] ${reset}"
  else
    echo -e "  ${gray}Would you like to share the results with ${blue}Keift${gray}?${reset}"
    echo -ne "  ${gray}This helps us improve this tool. [${green}Y${gray}/${red}N${gray}] ${reset}"
  fi

  if test -t 0; then
    read metrics_answer
  else
    read metrics_answer < /dev/tty
  fi

  if [ "${country_code}" = "RU" ]; then
    local acceptance_answer="д"
  elif [ "${country_code}" = "TR" ]; then
    local acceptance_answer="e"
  else
    local acceptance_answer="y"
  fi

  if [ "${metrics_answer,,}" = "${acceptance_answer}" ]; then
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
    local blockcheck_results_filtered=$(echo "${blockcheck_results}" | sed -n "/^\* SUMMARY/,/^\$/ { /^\* SUMMARY/d; /^\$/d; p; }")
    local domain_response=$(curl -sSI --max-time 10 https://"${blockcheck_domain}" 2>&1 | head -n 1)
    local nfqws_options=$(cat /opt/zapret/config 2>&1 | grep "^NFQWS")

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
      -d "${payload}" &> "${log_redirects}"
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

    send_metrics ZAPRET_UNSUPPORTED_INIT_SYSTEM

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

    send_metrics ZAPRET_UNSUPPORTED_INIT_SYSTEM

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

    send_metrics ZAPRET_UNSUPPORTED_INIT_SYSTEM

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

    send_metrics ZAPRET_UNSUPPORTED_PACKAGE_MANAGER

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

    send_metrics ZAPRET_UNSUPPORTED_PACKAGE_MANAGER

    echo ""

    exit 1
  fi
}

init_zapret() {
  # Systemd
  if [ "${init_system}" = "systemd" ]; then
    # Being set up by Zapret.
    :
  # Dinit
  elif [ "${init_system}" = "dinit" ]; then
    tee /etc/dinit.d/zapret &> /dev/null << EOF
type = scripted
command = /opt/zapret/init.d/sysv/zapret start
stop-command = /opt/zapret/init.d/sysv/zapret stop
restart = false
EOF
  # Runit
  elif [ "${init_system}" = "runit" ]; then
    if test -d /etc/sv; then
      local runit_sv_dir="/etc/sv"
    elif test -d /etc/runit/sv; then
      local runit_sv_dir="/etc/runit/sv"
    fi

    test -d /opt/zapret/init.d/runit/zapret && ln -sf /opt/zapret/init.d/runit/zapret "${runit_sv_dir}"/zapret &> "${log_redirects}"
  # S6
  elif [ "${init_system}" = "s6" ]; then
    if test -d /etc/s6-servicedirs; then
      local s6_service_dir="/etc/s6-servicedirs"
    elif test -d /etc/s6/sv; then
      local s6_service_dir="/etc/s6/sv"
    fi

    test -d /opt/zapret/init.d/s6/zapret && ln -sf /opt/zapret/init.d/s6/zapret "${s6_service_dir}"/zapret &> "${log_redirects}"
  # OpenRC
  elif [ "${init_system}" = "openrc" ]; then
    # Being set up by Zapret.
    :
  # Launchd
  elif [ "${init_system}" = "launchd" ]; then
    # Being set up by Zapret.
    :
  # Entware
  elif [ "${init_system}" = "entware" ]; then
    tee /opt/etc/init.d/S90zapret &> /dev/null << 'EOF'
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

    chmod +x /opt/etc/init.d/S90zapret
  # SysVinit
  elif [ "${init_system}" = "sysvinit" ]; then
    test -f /opt/zapret/init.d/sysv/zapret && ln -sf /opt/zapret/init.d/sysv/zapret /etc/init.d/zapret &> "${log_redirects}"
  # Rc
  elif [ "${init_system}" = "rc" ]; then
    test -f /opt/zapret/init.d/sysv/zapret && ln -sf /opt/zapret/init.d/sysv/zapret /etc/rc.d/rc.zapret &> "${log_redirects}"
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

print_update_commands() {
  if [ "${package_manager}" = "apt" ]; then
    echo -e "  ${green}sudo ${cyan}apt ${cyan}update${reset}"
    echo -e "  ${green}sudo ${cyan}apt ${cyan}upgrade ${white}-${yellow}y${reset}"
  elif [ "${package_manager}" = "rpm-ostree" ]; then
    echo -e "  ${green}sudo ${cyan}rpm-ostree ${cyan}upgrade${reset}"
  elif [ "${package_manager}" = "dnf" ]; then
    echo -e "  ${green}sudo ${cyan}dnf ${cyan}upgrade ${white}-${yellow}y${reset}"
  elif [ "${package_manager}" = "pacman" ]; then
    echo -e "  ${green}sudo ${cyan}pacman ${white}-${yellow}Syu ${white}--${yellow}noconfirm${reset}"
  elif [ "${package_manager}" = "zypper" ]; then
    echo -e "  ${green}sudo ${cyan}zypper ${white}-${yellow}n ${cyan}update${reset}"
  elif [ "${package_manager}" = "xbps" ]; then
    echo -e "  ${green}sudo ${cyan}xbps-install ${white}-${yellow}Suy${reset}"
  elif [ "${package_manager}" = "apk" ]; then
    echo -e "  ${green}sudo ${cyan}apk ${cyan}upgrade ${white}-${yellow}U${reset}"
  elif [ "${package_manager}" = "emerge" ]; then
    echo -e "  ${green}sudo ${cyan}emerge ${white}--${yellow}sync${reset}"
    echo -e "  ${green}sudo ${cyan}emerge ${white}-${yellow}uDNq ${cyan}@world${reset}"
  elif [ "${package_manager}" = "slackpkg" ]; then
    echo -e "  ${green}sudo ${cyan}slackpkg ${white}-${yellow}batch=on ${white}-${yellow}default_answer=y ${cyan}update${reset}"
    echo -e "  ${green}sudo ${cyan}slackpkg ${white}-${yellow}batch=on ${white}-${yellow}default_answer=y ${cyan}upgrade-all${reset}"
  elif [ "${package_manager}" = "eopkg" ]; then
    echo -e "  ${green}sudo ${cyan}eopkg ${cyan}upgrade ${white}-${yellow}y${reset}"
  elif [ "${package_manager}" = "opkg" ]; then
    echo -e "  ${green}sudo ${cyan}opkg ${cyan}update${reset}"
    echo -e "  ${green}sudo ${cyan}opkg ${cyan}upgrade${reset}"
  fi
}

throw_system_is_too_old() {
  print_head

  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${red}Ваша система слишком устарела. Пожалуйста, обновите вашу систему.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${red}Sisteminiz çok eski. Lütfen sisteminizi güncelleyin.${reset}"
  else
    echo -e "  ${red}Your system is too old. Please update your system.${reset}"
  fi

  echo ""

  print_update_commands

  echo ""

  send_metrics ZAPRET_SYSTEM_IS_TOO_OLD

  echo ""

  exit 1
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

  echo -e "  ${green}curl ${white}-${yellow}fsSL ${cyan}https://raw.github.com/keift/zapret/refs/heads/main/src/install.sh ${gray}| ${green}sudo ${cyan}bash${reset}"

  echo ""

  exit 1
fi

# 1. Install dependencies

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Установка зависимостей...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Bağımlılıklar yükleniyor...${reset}"
else
  echo -e "  ${gray}Installing dependencies...${reset}"
fi

install_package bind
install_package bind-tools
install_package bind-utils
install_package bind9-dnsutils
install_package bind920
install_package curl
install_package gzip
install_package iptables
install_package jq
install_package nftables
install_package tar
install_package wget
install_package wget-ssl

if ! command -v dig &> /dev/null \
  || ! command -v curl &> /dev/null \
  || ! command -v jq &> /dev/null \
  || ! command -v tar &> /dev/null \
  || ! command -v wget &> /dev/null; then
  throw_system_is_too_old
fi

# 2. Change DNS settings

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Шифрование DNS-запросов...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}DNS sorguları şifreleniyor...${reset}"
else
  echo -e "  ${gray}Encrypting DNS queries...${reset}"
fi

if [ "${init_system}" = "systemd" ]; then
  dns_resolver="dnscrypt-proxy"

  install_package systemd-resolved

  if [ "${package_manager}" = "opkg" ]; then
    install_package dnscrypt-proxy2
  else
    install_package dnscrypt-proxy
  fi

  install_package dnscrypt-proxy-"${init_system}"
  install_package dnscrypt-proxy2-"${init_system}"

  enable_service systemd-resolved
  start_service systemd-resolved

  enable_service dnscrypt-proxy
  enable_service dnscrypt-proxy2
  start_service dnscrypt-proxy
  start_service dnscrypt-proxy2

  dnscrypt_paths=(
    "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    "/etc/dnscrypt-proxy.toml"

    "/usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    "/usr/local/etc/dnscrypt-proxy.toml"

    "/opt/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    "/opt/etc/dnscrypt-proxy.toml"

    "/opt/dnscrypt-proxy/dnscrypt-proxy.toml"
  )

  for path in "${dnscrypt_paths[@]}"; do
    if test -f "${path}"; then
      dnscrypt_path="${path}"

      break
    fi
  done

  if test -z "${dnscrypt_path}"; then
    if test -f "/usr/share/defaults/dnscrypt-proxy/dnscrypt-proxy.toml"; then
      mkdir -p /etc/dnscrypt-proxy &> "${log_redirects}"

      cp /usr/share/defaults/dnscrypt-proxy/dnscrypt-proxy.toml /etc/dnscrypt-proxy &> "${log_redirects}"

      dnscrypt_path="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    else
      throw_system_is_too_old
    fi
  fi

  tee /etc/systemd/resolved.conf &> /dev/null <<< ""

  chattr -i /etc/resolv.conf &> "${log_redirects}"

  test -f /run/systemd/resolve/stub-resolv.conf && ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf &> "${log_redirects}"

  restart_service systemd-resolved

  tee "${dnscrypt_path}" &> /dev/null << EOF
listen_addresses = ["127.0.0.1:5300", "[::1]:5300"]

[sources."public-resolvers"]
urls = ["https://raw.github.com/dnscrypt/dnscrypt-resolvers/refs/heads/master/v3/public-resolvers.md", "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"]
minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
cache_file = "public-resolvers.md"
EOF

  restart_service dnscrypt-proxy
  restart_service dnscrypt-proxy2

  while ! dig -p 5300 +tries=1 +time=10 @127.0.0.1 &> /dev/null && ! dig -p 5300 +tries=1 +time=10 @::1 &> /dev/null; do
    restart_service dnscrypt-proxy
    restart_service dnscrypt-proxy2

    sleep 10
  done

  tee /etc/systemd/resolved.conf &> /dev/null << EOF
[Resolve]
DNS=127.0.0.1:5300
DNS=[::1]:5300

Domains=~.
DNSOverTLS=no
EOF

  chattr -i /etc/resolv.conf &> "${log_redirects}"

  test -f /run/systemd/resolve/stub-resolv.conf && ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf &> "${log_redirects}"

  restart_service systemd-resolved
else
  dns_resolver="dnscrypt-proxy"

  if [ "${package_manager}" = "opkg" ]; then
    install_package dnscrypt-proxy2
  else
    install_package dnscrypt-proxy
  fi

  install_package dnscrypt-proxy-"${init_system}"
  install_package dnscrypt-proxy2-"${init_system}"

  enable_service dnscrypt-proxy
  enable_service dnscrypt-proxy2
  start_service dnscrypt-proxy
  start_service dnscrypt-proxy2

  dnscrypt_paths=(
    "/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    "/etc/dnscrypt-proxy.toml"

    "/usr/local/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    "/usr/local/etc/dnscrypt-proxy.toml"

    "/opt/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    "/opt/etc/dnscrypt-proxy.toml"

    "/opt/dnscrypt-proxy/dnscrypt-proxy.toml"
  )

  for path in "${dnscrypt_paths[@]}"; do
    if test -f "${path}"; then
      dnscrypt_path="${path}"

      break
    fi
  done

  if test -z "${dnscrypt_path}"; then
    if test -f "/usr/share/defaults/dnscrypt-proxy/dnscrypt-proxy.toml"; then
      mkdir -p /etc/dnscrypt-proxy &> "${log_redirects}"

      cp /usr/share/defaults/dnscrypt-proxy/dnscrypt-proxy.toml /etc/dnscrypt-proxy &> "${log_redirects}"

      dnscrypt_path="/etc/dnscrypt-proxy/dnscrypt-proxy.toml"
    else
      throw_system_is_too_old
    fi
  fi

  chattr -i /etc/resolv.conf &> "${log_redirects}"

  tee /etc/resolv.conf &> /dev/null << EOF
nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
nameserver 1.0.0.1
nameserver 2606:4700:4700::1001
EOF

  tee "${dnscrypt_path}" &> /dev/null << EOF
listen_addresses = ["127.0.0.1:53", "[::1]:53"]

[sources."public-resolvers"]
urls = ["https://raw.github.com/dnscrypt/dnscrypt-resolvers/refs/heads/master/v3/public-resolvers.md", "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"]
minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
cache_file = "public-resolvers.md"
EOF

  restart_service dnscrypt-proxy
  restart_service dnscrypt-proxy2

  while ! dig -p 53 +tries=1 +time=10 @127.0.0.1 &> /dev/null && ! dig -p 53 +tries=1 +time=10 @::1 &> /dev/null; do
    restart_service dnscrypt-proxy
    restart_service dnscrypt-proxy2

    sleep 10
  done

  chattr -i /etc/resolv.conf &> "${log_redirects}"

  tee /etc/resolv.conf &> /dev/null << EOF
nameserver 127.0.0.1
nameserver ::1
EOF

  chattr +i /etc/resolv.conf &> "${log_redirects}"
fi

# 3. Download Zapret

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Скачивание Zapret...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Zapret indiriliyor...${reset}"
else
  echo -e "  ${gray}Downloading Zapret...${reset}"
fi

rm -rf /tmp/zapret &> "${log_redirects}"
rm -rf /tmp/zapret.tar.gz &> "${log_redirects}"

wget -O /tmp/zapret.tar.gz https://github.com/bol-van/zapret/releases/download/v"${zapret_version}"/zapret-v"${zapret_version}".tar.gz &> "${log_redirects}"

tar -xz -f /tmp/zapret.tar.gz -C /tmp &> "${log_redirects}"

mv /tmp/zapret-v"${zapret_version}" /tmp/zapret &> "${log_redirects}"

rm -rf /tmp/zapret.tar.gz &> "${log_redirects}"

# 4. Prepare for installation

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Подготовка к установке...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Kuruluma hazırlanıyor...${reset}"
else
  echo -e "  ${gray}Preparing for installation...${reset}"
fi

echo -e "Y\n\n" | /opt/zapret/uninstall_easy.sh &> "${log_redirects}"
rm -rf /opt/zapret &> "${log_redirects}"

echo -e "\n\n" | /tmp/zapret/install_prereq.sh &> "${log_redirects}"
/tmp/zapret/install_bin.sh &> "${log_redirects}"

# 5. Do Blockcheck

if [ "${country_code}" = "RU" ]; then
  echo -e "  ${gray}Поиск способов обхода блокировок...${reset}"
elif [ "${country_code}" = "TR" ]; then
  echo -e "  ${gray}Erişim engelleri aşma yöntemleri aranıyor...${reset}"
else
  echo -e "  ${gray}Searching for methods to bypass access restrictions...${reset}"
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

for domain in "${blockcheck_domains[@]}"; do
  blockcheck_domain="${domain}"

  curl --max-time 10 https://"${domain}" &> /dev/null || break
done

while [ $# -gt 0 ]; do
  if echo "${1}" | grep -iq "^--blockcheck-domain="; then
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
  nfqws_options="--dpi-desync=fakeddisorder --dpi-desync-ttl=1 --dpi-desync-autottl=-5 --dpi-desync-split-pos=1"
else
  blockcheck_results=$(echo -e "${blockcheck_domain}\n\n\n\n\n\n\n\n" | /tmp/zapret/blockcheck.sh 2> "${log_redirects}")

  [ "${debug}" = true ] && echo "${blockcheck_results}"

  nfqws_options=$(echo "${blockcheck_results}" | sed -n "/^\* SUMMARY/,/^\$/ { /^\* SUMMARY/d; /^\$/d; p; }" | grep -E "(curl_test_http|curl_test_https[^ ]*) ipv[0-9] ${blockcheck_domain} : nfqws" | tail -n 1 | sed "s/.*nfqws //" | sed "s|/tmp/zapret|/opt/zapret|g" | sed "s/^[[:space:]]*//; s/[[:space:]]*\$//")
fi

if echo "${blockcheck_results}" | grep -iq "nftables queue support is not available"; then
  echo -e "Y\n\n" | /opt/zapret/uninstall_easy.sh &> "${log_redirects}"
  rm -rf /opt/zapret &> "${log_redirects}"
  rm -rf /tmp/zapret &> "${log_redirects}"

  throw_system_is_too_old
fi

if ! echo "${nfqws_options}" | grep -iq -- "--"; then
  echo -e "Y\n\n" | /opt/zapret/uninstall_easy.sh &> "${log_redirects}"
  rm -rf /opt/zapret &> "${log_redirects}"
  rm -rf /tmp/zapret &> "${log_redirects}"

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

prototype_installation_results=$(echo -e "\n\n" | /tmp/zapret/install_easy.sh 2> "${log_redirects}")

if echo "${prototype_installation_results}" | grep -iq "system is not either systemd"; then
  prototype_installation_results=$(echo -e "Y\n\n\n" | /tmp/zapret/install_easy.sh 2> "${log_redirects}")

  if echo "${prototype_installation_results}" | grep -iq "readonly system detected"; then
    installation_results=$(echo -e "Y\nY\nY\nY\nY\n\n\n\n\n\n\nY\n\n\n\n\n" | /tmp/zapret/install_easy.sh 2> "${log_redirects}")
  else
    installation_results=$(echo -e "Y\nY\nY\n\n\n\n\n\n\nY\n\n\n\n\n" | /tmp/zapret/install_easy.sh 2> "${log_redirects}")
  fi
else
  if echo "${prototype_installation_results}" | grep -iq "readonly system detected"; then
    installation_results=$(echo -e "Y\nY\nY\n\n\n\n\n\n\nY\n\n\n\n\n" | /tmp/zapret/install_easy.sh 2> "${log_redirects}")
  else
    installation_results=$(echo -e "Y\n\n\n\n\n\n\nY\n\n\n\n\n" | /tmp/zapret/install_easy.sh 2> "${log_redirects}")
  fi
fi

[ "${debug}" = true ] && echo "${installation_results}"

if echo "${installation_results}" | grep -iq "readonly system detected"; then
  echo -e "Y\n\n" | /opt/zapret/uninstall_easy.sh &> "${log_redirects}"
  rm -rf /opt/zapret &> "${log_redirects}"
  rm -rf /tmp/zapret &> "${log_redirects}"

  print_head

  if [ "${country_code}" = "RU" ]; then
    echo -e "  ${red}Обнаружена неизменяемая система. Пожалуйста, отключите режим только для чтения.${reset}"
  elif [ "${country_code}" = "TR" ]; then
    echo -e "  ${red}Değiştirilemez sistem tespit edildi. Lütfen salt okunur modunu kapatın.${reset}"
  else
    echo -e "  ${red}Immutable system detected. Please turn off read-only mode.${reset}"
  fi

  echo ""

  send_metrics ZAPRET_IMMUTABLE_SYSTEM_DETECTED

  echo ""

  exit 1
fi

if echo "${installation_results}" | grep -iq "could not start zapret service"; then
  echo -e "Y\n\n" | /opt/zapret/uninstall_easy.sh &> "${log_redirects}"
  rm -rf /opt/zapret &> "${log_redirects}"
  rm -rf /tmp/zapret &> "${log_redirects}"

  print_head

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

echo "${installation_results}" | grep -iq "system is not either systemd" && init_zapret

enable_service zapret
start_service zapret

touch /opt/zapret/ipset/zapret-hosts-user.txt &> "${log_redirects}"
touch /opt/zapret/ipset/zapret-hosts-auto.txt &> "${log_redirects}"

sed -i "/^NFQWS_OPT=\"/,/^\"/c NFQWS_OPT=\"${nfqws_options} --hostlist=/opt/zapret/ipset/zapret-hosts-user.txt --hostlist-auto=/opt/zapret/ipset/zapret-hosts-auto.txt\"" /opt/zapret/config

restart_service zapret

for domain in "${blockcheck_domains[@]}"; do
  for i in {1..3}; do
    curl --max-time 1 https://"${domain}" &> /dev/null
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

rm -rf /tmp/zapret &> "${log_redirects}"

echo ""

send_metrics ZAPRET_INSTALLATION_SUCCESSFUL

echo ""
