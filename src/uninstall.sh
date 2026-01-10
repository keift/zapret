#!/bin/bash

sudo -v

reset="\e[0m"
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

# if ! command -v systemd &>/dev/null; then
#   echo -e "  ${red}Error: It only works on devices where Systemd is installed.${reset}"
#   echo ""
#
#   exit 1
# fi

if [ ! -d "/opt/zapret" ]; then
  echo -e "  ${gray}Zapret already not installed.${reset}"
  echo ""

  exit 0
fi

echo -e "  ${gray}Uninstalling Zapret...${reset}"

printf "\n" | sudo /opt/zapret/uninstall_easy.sh &>/dev/null

sudo rm -rf /opt/zapret
sudo rm -rf /tmp/zapret-v72.7

echo -e "  ${gray}Zapret has been successfully uninstalled.${reset}"

echo ""