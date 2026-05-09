#!/usr/bin/env bash

set -e

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_FILE="$CONFIG_DIR/config.json"

clear

echo "========================================="
echo "   Xray VLESS + REALITY Auto Installer"
echo "========================================="
echo

if [[ $EUID -ne 0 ]]; then
    echo "Запусти скрипт от root"
    exit 1
fi

read -p "Продолжить установку? (y/n): " confirm

if [[ "$confirm" != "y" ]]; then
    echo "Отменено"
    exit 0
fi

echo
echo "[1/7] Обновление пакетов..."
apt update -y
apt install -y curl openssl qrencode unzip

echo
echo "[2/7] Установка Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

echo
read -p "Порт VPN (по умолчанию 443): " port
port=${port:-443}

read -p "SNI домен (по умолчанию google.com): " sni
sni=${sni:-google.com}

echo
echo "[3/7] Генерация UUID..."
uuid=$(xray uuid)

echo "[4/7] Генерация ключей REALITY..."
keys=$(xray x25519)

private_key=$(echo "$keys" | awk '/PrivateKey/ {print $2}')
public_key=$(echo "$keys" | awk '/PublicKey/ {print $2}')

short_id=$(openssl rand -hex 8)

echo "[5/7] Получение IP..."
ip=$(curl -s ifconfig.me)

mkdir -p $CONFIG_DIR

echo
echo "[6/7] Создание конфига..."

cat > $CONFIG_FILE <<EOF
{
  "log": {
    "loglevel": "warning"
  },

  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $port,
      "protocol": "vless",

      "settings": {
        "clients": [
          {
            "id": "$uuid",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },

      "streamSettings": {
        "network": "tcp",
        "security": "reality",

        "realitySettings": {
          "show": false,
          "dest": "$sni:443",
          "xver": 0,

          "serverNames": [

            "$sni"
          ],

          "privateKey": "$private_key",

          "shortIds": [
            "$short_id"
          ]
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

echo
echo "[7/7] Настройка firewall..."

if command -v ufw &> /dev/null; then
    ufw allow $port/tcp || true
fi

systemctl enable xray
systemctl restart xray

echo
echo "========================================="
echo "        УСТАНОВКА ЗАВЕРШЕНА"
echo "========================================="
echo

vpn_link="vless://$uuid@$ip:$port?security=reality&encryption=none&pbk=$public_key&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=$sni&sid=$short_id#MyVPN"

echo "Ссылка:"
echo
echo "$vpn_link"
echo

echo "QR Code:"
echo
qrencode -t ANSIUTF8 "$vpn_link"

echo
echo "UUID: $uuid"
echo "PublicKey: $public_key"
echo "ShortID: $short_id"
echo
echo "Готово."
