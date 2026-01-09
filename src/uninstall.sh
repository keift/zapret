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

echo ""
echo -e "  ${blue}Keift ${gray}- ${green}Zapret Installer${reset}"
echo ""

echo "  Uninstalling Zapret..."

sudo /opt/zapret/uninstall_easy.sh

sudo rm -rf ~/zapret-v72.2
sudo rm -rf /opt/zapret

echo "  Zapret successfully uninstalled."

echo ""
