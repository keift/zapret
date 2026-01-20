#!/bin/bash

sudo -v

dev=false
debug=false

for arg in "$@"; do
  if [ "$arg" = "--dev" ]; then
    dev=true
  fi
done

for arg in "$@"; do
  if [ "$arg" = "--debug" ]; then
    debug=true
  fi
done

log_redirects="/dev/null"

[ "$debug" = true ] && log_redirects="/dev/stdout"

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

# 1. Install dependencies

echo -e "  ${gray}Installing dependencies...${reset}"

if command -v apt &>/dev/null; then
  export DEBIAN_FRONTEND="noninteractive"

  sudo apt update -y &>"$log_redirects"
  sudo apt install -y bind9-dnsutils &>"$log_redirects"
  sudo apt install -y curl &>"$log_redirects"
  sudo apt install -y dnscrypt-proxy &>"$log_redirects"
  sudo apt install -y nftables &>"$log_redirects"
  sudo apt install -y systemd-resolved &>"$log_redirects"
  sudo apt install -y unzip &>"$log_redirects"
  sudo apt install -y wget &>"$log_redirects"
elif command -v dnf &>/dev/null; then
  sudo dnf check-update -y &>"$log_redirects"
  sudo dnf install -y bind-utils &>"$log_redirects"
  sudo dnf install -y curl &>"$log_redirects"
  sudo dnf install -y dnscrypt-proxy &>"$log_redirects"
  sudo dnf install -y nftables &>"$log_redirects"
  sudo dnf install -y systemd-resolved &>"$log_redirects"
  sudo dnf install -y unzip &>"$log_redirects"
  sudo dnf install -y wget &>"$log_redirects"
elif command -v pacman &>/dev/null; then
  sudo pacman -Sy --noconfirm &>"$log_redirects"
  sudo pacman -S --noconfirm bind &>"$log_redirects"
  sudo pacman -S --noconfirm curl &>"$log_redirects"
  sudo pacman -S --noconfirm dnscrypt-proxy &>"$log_redirects"
  sudo pacman -S --noconfirm nftables &>"$log_redirects"
  sudo pacman -S --noconfirm systemd-resolved &>"$log_redirects"
  sudo pacman -S --noconfirm unzip &>"$log_redirects"
  sudo pacman -S --noconfirm wget &>"$log_redirects"
elif command -v zypper &>/dev/null; then
  sudo zypper -n refresh &>"$log_redirects"
  sudo zypper -n install bind-utils &>"$log_redirects"
  sudo zypper -n install curl &>"$log_redirects"
  sudo zypper -n install dnscrypt-proxy &>"$log_redirects"
  sudo zypper -n install nftables &>"$log_redirects"
  sudo zypper -n install systemd-resolved &>"$log_redirects"
  sudo zypper -n install unzip &>"$log_redirects"
  sudo zypper -n install wget &>"$log_redirects"
else
  echo -e "  ${red}Error: Unsupported package manager.${reset}"
  echo ""

  exit 1
fi

# 2. Change DNS settings

echo -e "  ${gray}DNS settings are being changed...${reset}"

sudo systemctl enable systemd-resolved &>"$log_redirects"
sudo systemctl start systemd-resolved

sudo tee /etc/dnscrypt-proxy/dnscrypt-proxy.toml &>/dev/null << EOF
listen_addresses = ["127.0.0.1:5300", "[::1]:5300"]

server_names = ["cloudflare", "cloudflare-ipv6"]

[sources]
  [sources."public-resolvers"]
  url = "https://raw.github.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
  minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"
  cache_file = "/var/cache/dnscrypt-proxy/public-resolvers-v3.md"
EOF

sudo systemctl restart dnscrypt-proxy

sudo tee /etc/systemd/resolved.conf &>/dev/null << EOF
[Resolve]
DNS=127.0.0.1:5300
DNS=[::1]:5300
DNS=1.1.1.1#one.one.one.one
DNS=2606:4700:4700::1111#one.one.one.one
DNS=1.0.0.1#one.one.one.one
DNS=2606:4700:4700::1001#one.one.one.one
DNSOverTLS=yes
EOF

[ -e /run/systemd/resolve/stub-resolv.conf ] && sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

sudo systemctl restart systemd-resolved

# 3. Download Zapret

echo -e "  ${gray}Downloading Zapret...${reset}"

sudo rm -rf /tmp/zapret-v72.8
sudo rm -rf /tmp/zapret-v72.8.zip

sudo wget -P /tmp https://github.com/bol-van/zapret/releases/download/v72.8/zapret-v72.8.zip &>"$log_redirects"

sudo unzip -d /tmp /tmp/zapret-v72.8.zip &>"$log_redirects"

sudo rm -rf /tmp/zapret-v72.8.zip

# 4. Prepare for installation

echo -e "  ${gray}Preparing for installation...${reset}"

printf "\n" | sudo /opt/zapret/uninstall_easy.sh &>"$log_redirects"
sudo rm -rf /opt/zapret

printf "\n\n" | sudo /tmp/zapret-v72.8/install_prereq.sh &>"$log_redirects"
sudo /tmp/zapret-v72.8/install_bin.sh &>"$log_redirects"

# 5. Do Blockcheck

echo -e "  ${gray}Blockcheck is being performed, this may take a few minutes...${reset}"

blockcheck_domain="discord.com"

if [ "$dev" = true ]; then
  nfqws_options="--dpi-desync=fakeddisorder --dpi-desync-ttl=1 --dpi-desync-autottl=-5 --dpi-desync-split-pos=1"
else
  blockcheck_results=$(printf "$blockcheck_domain\n\n\n\n\n\n\n\n" | sudo /tmp/zapret-v72.8/blockcheck.sh 2>"$log_redirects")

  [ "$debug" = true ] && echo "$blockcheck_results"

  nfqws_options=$(echo "$blockcheck_results" | grep "curl_test_https_tls12 ipv4 $blockcheck_domain : nfqws" | tail -n1 | sed "s/.*nfqws //")
fi

if [[ "$blockcheck_results" == *"curl_test_https_tls12 ipv4 $blockcheck_domain : working without bypass"* ]]; then
  echo -e "  ${gray}No access restrictions were detected.${reset}"
  echo ""

  printf "\n" | sudo /opt/zapret/uninstall_easy.sh &>"$log_redirects"
  sudo rm -rf /opt/zapret
  sudo rm -rf /tmp/zapret-v72.8

  exit 0
fi

# 6. Install Zapret

echo -e "  ${gray}Installing Zapret...${reset}"

printf "Y\n\n\n\n\n\n\nY\n\n\n\n\n" | sudo /tmp/zapret-v72.8/install_easy.sh &>"$log_redirects"

sudo sed -i "/^NFQWS_OPT=\"/,/^\"/c NFQWS_OPT=\"$nfqws_options --hostlist=/opt/zapret/hostlist.txt --hostlist-auto=/opt/zapret/ipset/zapret-hostlist-auto.txt\"" /opt/zapret/config

sudo touch /opt/zapret/hostlist.txt

sudo tee /opt/zapret/ipset/zapret-hostlist-auto.txt &>/dev/null << EOF
discord.com
roblox.com
EOF

sudo systemctl restart zapret

# 7. Finish the installation

echo -e "  ${gray}Zapret was successfully installed.${reset}"

sudo rm -rf /tmp/zapret-v72.8

echo ""