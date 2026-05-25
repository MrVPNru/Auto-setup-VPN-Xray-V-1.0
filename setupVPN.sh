#!/usr/bin/env bash

set -e

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_FILE="$CONFIG_DIR/config.json"

clear

echo "========================================="
echo "   Xray VLESS + REALITY Installer"
echo "========================================="
echo

if [[ $EUID -ne 0 ]]; then
    echo "Запусти скрипт от root"
    exit 1
fi

echo "Выбери режим:"
echo
echo "1) Обычное подключение"
echo "2) Двойная маршрутизация"
echo

read -p "Введите номер: " MODE

echo
read -p "Продолжить установку? (y/n): " confirm

if [[ "$confirm" != "y" ]]; then
    echo "Отменено"
    exit 0
fi

echo
echo "[1/8] Обновление пакетов..."
apt update -y
# Заменили awk на gawk, чтобы избежать ошибки виртуального пакета в Debian
apt install -y curl openssl qrencode unzip gawk

echo
echo "[2/8] Установка Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

mkdir -p $CONFIG_DIR

# =========================================================
# ОБЫЧНОЕ ПОДКЛЮЧЕНИЕ
# =========================================================

if [[ "$MODE" == "1" ]]; then

    read -p "Порт VPN (по умолчанию 443): " port
    port=${port:-443}

    read -p "SNI домен (по умолчанию google.com): " sni
    sni=${sni:-google.com}

    echo
    echo "[3/8] Генерация UUID..."
    uuid=$(xray uuid)

    echo
    echo "[4/8] Генерация ключей REALITY..."
    keys=$(xray x25519)
    private_key=$(echo "$keys" | awk '/PrivateKey/ {print $2}')
    public_key=$(echo "$keys" | awk '/PublicKey/ {print $3}')
    short_id=$(openssl rand -hex 8)

    echo
    echo "[5/8] Получение IP..."
    ip=$(curl -s https://api.ipify.org)

    echo
    echo "[6/8] Создание обычного конфига..."

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
        },
        "tcpSettings": {
          "header": {
            "type": "none"
          }
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
    echo "[7/8] Настройка firewall..."
    if command -v ufw &> /dev/null; then
        ufw allow $port/tcp || true
    fi

    systemctl enable xray
    systemctl restart xray

    vpn_link="vless://$uuid@$ip:$port?security=reality&encryption=none&pbk=$public_key&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=$sni&sid=$short_id#MyVPN"

    echo
    echo "========================================="
    echo "        УСТАНОВКА ЗАВЕРШЕНА"
    echo "========================================="
    echo
    echo "Ссылка:"
    echo "$vpn_link"
    echo
    echo "QR Code:"
    qrencode -t ANSIUTF8 "$vpn_link"
    echo
    echo "UUID: $uuid"
    echo "PublicKey: $public_key"
    echo "ShortID: $short_id"
    echo "PrivateKey: $private_key"
fi

# =========================================================
# ДВОЙНАЯ МАРШРУТИЗАЦИЯ
# =========================================================

if [[ "$MODE" == "2" ]]; then

    echo
    echo "========== НАСТРОЙКА ЭТОГО (ВХОДЯЩЕГО) СЕРВЕРА =========="
    read -p "Порт для подключения клиента (например, 443): " inbound_port
    read -p "SNI домен для маскировки (например, google.com): " inbound_sni

    inbound_uuid=$(xray uuid)
    inbound_keys=$(xray x25519)
    inbound_private=$(echo "$inbound_keys" | awk '/PrivateKey/ {print $2}')
    inbound_public=$(echo "$inbound_keys" | awk '/PublicKey/ {print $3}')
    inbound_sid=$(openssl rand -hex 8)

    echo
    echo "========== НАСТРОЙКА ВТОРОГО (ВЫХОДЯЩЕГО) СЕРВЕРА =========="
    read -p "IP второго (финального) сервера: " outbound_ip
    read -p "Порт второго сервера (по умолчанию 443): " outbound_port
    outbound_port=${outbound_port:-443}
    read -p "UUID второго сервера: " outbound_uuid
    read -p "PublicKey второго сервера: " outbound_public
    read -p "SNI второго сервера: " outbound_sni
    read -p "ShortID второго сервера: " outbound_sid

    echo
    echo "[3/8] Получение IP..."
    ip=$(curl -s https://api.ipify.org)

    echo
    echo "[4/8] Создание конфига двойной маршрутизации..."

cat > $CONFIG_FILE <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "inboundTag": ["api"],
        "outboundTag": "api"
      },
      {
        "type": "field",
        "domain": [
          "regexp:\\\\.ru$",
          "regexp:\\\\.рф$",
          "regexp:\\\\.su$",
          "geosite:vk",
          "geosite:yandex",
          "geosite:mailru"
        ],
        "ip": [
          "geoip:ru",
          "geoip:private"
        ],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "proxy-out"
      }
    ]
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": $inbound_port,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$inbound_uuid",
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
          "dest": "$inbound_sni:443",
          "xver": 0,
          "serverNames": [
            "$inbound_sni"
          ],
          "privateKey": "$inbound_private",
          "shortIds": [
            "$inbound_sid"
          ]
        },
        "tcpSettings": {
          "header": {
            "type": "none"
          }
        }
      },
      "tag": "inbound-client",
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy-out",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "$outbound_ip",
            "port": $outbound_port,
            "users": [
              {
                "id": "$outbound_uuid",
                "flow": "xtls-rprx-vision",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "publicKey": "$outbound_public",
          "fingerprint": "chrome",
          "serverName": "$outbound_sni",
          "shortId": "$outbound_sid",
          "spiderX": "/"
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "blocked",
      "protocol": "blackhole"
    }
  ]
}
EOF

    echo
    echo "[5/8] Настройка firewall..."
    if command -v ufw &> /dev/null; then
        ufw allow $inbound_port/tcp || true
    fi

    systemctl enable xray
    systemctl restart xray

    vpn_link="vless://$inbound_uuid@$ip:$inbound_port?security=reality&encryption=none&pbk=$inbound_public&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=$inbound_sni&sid=$inbound_sid#DoubleVPN"

    echo
    echo "========================================="
    echo "    ДВОЙНАЯ МАРШРУТИЗАЦИЯ НАСТРОЕНА"
    echo "========================================="
    echo
    echo "Данные для подключения клиента к ЭТОМУ серверу:"
    echo
    echo "Ссылка:"
    echo "$vpn_link"
    echo
    echo "QR Code:"
    qrencode -t ANSIUTF8 "$vpn_link"
    echo
    echo "UUID: $inbound_uuid"
    echo "PublicKey: $inbound_public"
    echo "ShortID: $inbound_sid"
fi

echo
echo "Готово."

