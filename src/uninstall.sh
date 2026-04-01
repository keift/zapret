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

if [ ! -d "/opt/zapret" ]; then
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