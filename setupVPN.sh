#!/bin/bash

read -p  "Hi, are you sure I'd set up a VPN for you?|Ты уверен в том, что бы я начал настройку впн за тебя?(y/n)" agreesetupvpn

if [ "$agreesetupvpn" = "y" ]; then
    echo "Okay, start core installation|Окей, начинаю установку ядра..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
else
    exit
    fi

read -p "Core installation finished. Choose a port for your VPN (default is 443):" port
port=${port:-443}
echo "Choose your protocol | Выбери протокол:"
echo "1) VLESS (Recommended/Рекомендуется)"
echo "2) Trojan"
echo "3) Shadowsk"

read -p "Enter number (1-3)/Введи число (1-3):" protocol

case $protocol in
    1)
        protocol="vless"
        echo "Selected VLESS | Выбран VLESS"
        link_prefix="vless"
        ;;
    2)
        protocol="trojan"
        echo "Selected Trojan | Выбран Trojan"
        link_prefix="trojan"
        ;;
    3)
        protocol="Shadowsk"
        link_prefix="ss"
        echo "Selected ss(Shadowsk) | Выбран ss(Shadowsk)"
        ;;
    *)
        protocol="vless"
        echo "Invalid choice, using VLESS by default | Неверный выбор, использую VLESS по умолчанию"
        link_prefix="vless"
        ;;
esac

uuid=$(xray uuid)
short_id=$(openssl rand -hex 8)
keys=$(xray x25519 2>&1)
private_key=$(echo "$keys" | grep "PrivateKey" | awk -F': ' '{print $2}')
public_key=$(echo "$keys" | grep "PublicKey" | awk -F': ' '{print $2}')
ip=$(curl -s ifconfig.me)
cat <<EOF > /usr/local/etc/xray/config.json
{
    "inbounds": [
        {
            "port": $vpnport,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "google.com:443",
                    "xver": 0,
                    "serverNames": ["google.com"],
                    "privateKey": "$private_key",
                    "shortIds": ["$short_id"]
                }
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom"
        }
    ]
}
EOF

echo "DEBUG: Keys found:"
echo "PRI: $private_key"
echo "PBK: $public_key"
echo "$link_prefix://$uuid@$ip:$vpnport?security=reality&encryption=none&pbk=$public_key&headerType=none&fp=chrome&type=tcp&sni=google.com&sid=$short_id"
systemctl restart xray
