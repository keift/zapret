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
echo -e "  ${blue}Keift ${cyan}Install Zapret${reset}"
echo ""

if ! command -v systemctl &>/dev/null; then
  echo -e "  ${red}Error: It only works on devices where Systemd is installed.${reset}"
  echo ""

  exit 1
fi

# 1. Install required tools

echo -e "  ${gray}Installing required tools...${reset}"

sudo apt install -y curl dnsutils nftables unzip &>/dev/null

sudo dnf install -y bind-utils curl nftables unzip &>/dev/null
sudo yum install -y bind-utils curl nftables unzip &>/dev/null

sudo zypper -n install bind-utils curl nftables unzip &>/dev/null

sudo pacman -S --noconfirm bind-tools curl nftables unzip &>/dev/null

# 2. Change DNS rules

echo -e "  ${gray}DNS rules are being changed...${reset}"

country_code=$(curl -s https://ipinfo.io/country)

sudo systemctl enable systemd-resolved &>/dev/null
sudo systemctl start systemd-resolved

if [ "$country_code" = "RU" ]; then
  echo -e "  ${gray}It appears you are in Russia. Using Yandex DNS...${reset}"

  sudo tee /etc/systemd/resolved.conf &>/dev/null << EOF
[Resolve]
DNS=77.88.8.8#common.dot.dns.yandex.net
DNS=2a02:6b8::feed:0ff#common.dot.dns.yandex.net
DNS=77.88.8.1#common.dot.dns.yandex.net
DNS=2a02:6b8:0:1::feed:0ff#common.dot.dns.yandex.net
DNSOverTLS=yes
EOF
else
  echo -e "  ${gray}It appears you are not in Russia. Using Cloudflare DNS...${reset}"

  sudo tee /etc/systemd/resolved.conf &>/dev/null << EOF
[Resolve]
DNS=1.1.1.1#one.one.one.one
DNS=2606:4700:4700::1111#one.one.one.one
DNS=1.0.0.1#one.one.one.one
DNS=2606:4700:4700::1001#one.one.one.one
DNSOverTLS=yes
EOF
fi

sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

sudo systemctl restart systemd-resolved

# 3. Download Zapret

echo -e "  ${gray}Downloading Zapret...${reset}"

sudo rm -rf /tmp/zapret-v72.7
sudo rm -rf /tmp/zapret-v72.7.zip

sudo wget -P /tmp https://github.com/bol-van/zapret/releases/download/v72.7/zapret-v72.7.zip &>/dev/null

sudo unzip -d /tmp /tmp/zapret-v72.7.zip &>/dev/null

sudo rm -rf /tmp/zapret-v72.7.zip

# 4. Prepare for installation

echo -e "  ${gray}Preparing for installation...${reset}"

printf "\n" | sudo /opt/zapret/uninstall_easy.sh &>/dev/null
sudo rm -rf /opt/zapret

printf "\n\n" | sudo /tmp/zapret-v72.7/install_prereq.sh &>/dev/null
sudo /tmp/zapret-v72.7/install_bin.sh &>/dev/null

# 5. Do Blockcheck

echo -e "  ${gray}Blockcheck is being performed, this may take a few minutes...${reset}"

# blockcheck_results="--dpi-desync=fakeddisorder --dpi-desync-ttl=1 --dpi-desync-autottl=-5 --dpi-desync-split-pos=1"
blockcheck_results=$(printf "discord.com\n\n\n\n\n\n\n\n" | sudo /tmp/zapret-v72.7/blockcheck.sh 2>/dev/null | grep "curl_test_https_tls12" | tail -n1 | sed "s/.*nfqws //")

# echo -e "  ${gray}Blockcheck results: $blockcheck_results${reset}"

if [[ "$blockcheck_results" == *"working without bypass"* ]]; then
  echo -e "  ${gray}No access restrictions were detected.${reset}"
  echo ""

  printf "\n" | sudo /opt/zapret/uninstall_easy.sh &>/dev/null
  sudo rm -rf /opt/zapret
  sudo rm -rf /tmp/zapret-v72.7

  exit 0
fi

# 6. Install Zapret

echo -e "  ${gray}Installing Zapret...${reset}"

printf "Y\n\n\n\n\n\n\nY\n\n\n\n\n" | sudo /tmp/zapret-v72.7/install_easy.sh &>/dev/null

sudo sed -i "/^NFQWS_OPT=\"/,/^\"/c NFQWS_OPT=\"$blockcheck_results\"" /opt/zapret/config

sudo systemctl restart zapret

# 7. Finish the installation

echo -e "  ${gray}Zapret was successfully installed.${reset}"

sudo rm -rf /tmp/zapret-v72.7

echo ""