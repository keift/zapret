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

clear

echo ""
echo -e "  ${blue}Keift ${cyan}Uninstall Zapret${reset}"
echo ""

if [ ! -d "/opt/zapret" ]; then
  echo -e "  ${gray}Zapret already not installed.${reset}"
  echo ""

  exit 0
fi

echo -e "  ${gray}Uninstalling Zapret...${reset}"

printf "Y\n\n" | sudo /opt/zapret/uninstall_easy.sh &>"${log_redirects}"

sudo rm -rf /opt/zapret

echo -e "  ${gray}Zapret has been successfully uninstalled.${reset}"

echo ""