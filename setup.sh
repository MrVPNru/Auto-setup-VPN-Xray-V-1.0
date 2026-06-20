#!/usr/bin/env bash
set -e
CONFIG_FILE="/usr/local/etc/xray/config.json"

if [[ "${EUID}" -ne 0 ]]; then
   echo "Error: This script must be run as root."
   exit 1
fi

install_dependencies() {
    echo "--- Инициализация системы ---"
    apt update && apt upgrade -y
    apt install -y curl wget unzip qrencode openssl iptables ufw
    if ! command -v xray &> /dev/null; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    fi
}
install_dependencies
setup_dns() {
    echo "--- Installing AdGuard Home ---"
    curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v
    systemctl stop AdGuardHome
    CONF_FILE_AG="/opt/AdGuardHome/conf/AdGuardHome.yaml"
    cat <<EOF >> "$CONF_FILE_AG"
user_rules:
  - "||doubleclick.net^"
  - "||ads.google.com^"
  - "||yandex.ru/ads^"
EOF
    read -p "Enter game domain for bypass: " GAME_DOMAIN
    read -p "Enter IP for rewrite: " MOCK_IP
    echo "  - \"||$GAME_DOMAIN^\$dnsrewrite=$MOCK_IP\"" >> "$CONF_FILE_AG"
    systemctl start AdGuardHome && systemctl enable AdGuardHome
    ufw allow 3000/tcp && ufw allow 53/udp && ufw allow 53/tcp
}
OpenVPN_vpn() {
    apt install -y openvpn iptables openssl
    wget https://git.io/vpn -O openvpn-install.sh && chmod +x openvpn-install.sh
    ./openvpn-install.sh
}

Hysteria2_vpn() {
    read -p "Port: " port; read -p "SNI: " sni; read -p "Password: " password
    ip=$(curl -s https://api.ipify.org)
    cat > $CONFIG_FILE <<EOF
{"inbounds": [{"listen": "0.0.0.0", "port": $port, "protocol": "hysteria2", "settings": {"auth": "$password"}, "streamSettings": {"network": "udp", "security": "tls", "tlsSettings": {"serverName": "$sni"}}}], "outbounds": [{"protocol": "freedom"}]}
EOF
    ufw allow $port/udp && systemctl restart xray
    link="hysteria2://$password@$ip:$port/?sni=$sni&insecure=1#Hysteria2VPN"
    echo "Link: $link"; qrencode -t ANSIUTF8 "$link"
}

Shadowsocks_vpn() {
    read -p "Port: " port
    password=$(openssl rand -base64 16); ip=$(curl -s https://api.ipify.org)
    cat > $CONFIG_FILE <<EOF
{"inbounds": [{"listen": "0.0.0.0", "port": $port, "protocol": "shadowsocks", "settings": {"method": "2022-blake3-aes-128-gcm", "password": "$password", "network": "tcp,udp"}}], "outbounds": [{"protocol": "freedom"}]}
EOF
    systemctl restart xray
    link="ss://$(echo -n "2022-blake3-aes-128-gcm:$password" | base64)@$ip:$port#MyShadowsocks"
    echo "Link: $link"; qrencode -t ANSIUTF8 "$link"
}

Trojan_vpn() {
    read -p "Port: " port; read -p "SNI: " sni; read -p "Password: " password
    ip=$(curl -s https://api.ipify.org)
    cat > $CONFIG_FILE <<EOF
{"inbounds": [{"listen": "0.0.0.0", "port": $port, "protocol": "trojan", "settings": {"clients": [{"password": "$password"}]}, "streamSettings": {"network": "tcp", "security": "tls", "tlsSettings": {"serverName": "$sni", "certificates": [{"certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key"}]}}}], "outbounds": [{"protocol": "freedom"}]}
EOF
    systemctl restart xray
    link="trojan://$password@$ip:$port?security=tls&sni=$sni#TrojanVPN"
    echo "Link: $link"; qrencode -t ANSIUTF8 "$link"
}

WireGuard_vpn() {
    apt install -y wireguard qrencode
    wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
    read -p "Port: " PORT
    cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.0.0.1/24
ListenPort = $PORT
PrivateKey = $(cat /etc/wireguard/private.key)
EOF
    systemctl enable wg-quick@wg0 && systemctl restart wg-quick@wg0
}

vless_vpn() {
    read -p "Port: " port; read -p "SNI: " sni
    uuid=$(xray uuid); keys=$(xray x25519)
    private_key=$(echo "$keys" | awk '/PrivateKey/ {print $2}')
    public_key=$(echo "$keys" | awk '/PublicKey/ {print $3}')
    short_id=$(openssl rand -hex 8); ip=$(curl -s https://api.ipify.org)
    cat > $CONFIG_FILE <<EOF
{"inbounds": [{"listen": "0.0.0.0", "port": $port, "protocol": "vless", "settings": {"clients": [{"id": "$uuid", "flow": "xtls-rprx-vision"}], "decryption": "none"}, "streamSettings": {"network": "tcp", "security": "reality", "realitySettings": {"show": false, "dest": "$sni:443", "serverNames": ["$sni"], "privateKey": "$private_key", "shortIds": ["$short_id"]}}}], "outbounds": [{"protocol": "freedom"}]}
EOF
    systemctl restart xray
    link="vless://$uuid@$ip:$port?security=reality&encryption=none&pbk=$public_key&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=$sni&sid=$short_id#MyVPN"
    echo "Link: $link"; qrencode -t ANSIUTF8 "$link"
}
setup_vpn() {
    echo "1)VLESS 2)WireGuard 3)Trojan 4)Shadowsocks 5)Hysteria2 6)OpenVPN"
    read -p "Choice: " choice
    case $choice in
        1) vless_vpn ;; 2) WireGuard_vpn ;; 3) Trojan_vpn ;;
        4) Shadowsocks_vpn ;; 5) Hysteria2_vpn ;; 6) OpenVPN_vpn ;;
        *) echo "Invalid" ;;
    esac
}

echo "============================================"
echo "1. Setup DNS (AdGuard Home)"
echo "2. Setup VPN"
echo "============================================"
read -p "Option [1-2]: " MODE
case $MODE in
    1) setup_dns ;; 2) setup_vpn ;;
    *) echo "Invalid choice." ;;
esac

