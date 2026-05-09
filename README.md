At the age of 10, in April, I decided to set up my first VPN on a server, and I succeeded. After a month, I got tired of downloading the panel and doing everything myself, so I decided to create a script that writes config itself into a json file. Let me explain how it works: when you run a script, it asks if the person is sure that the script would continue. When you agree, the script begins installing the Xray core - a base for servers and VPNs. After installation, it asks the port, if you just press Enter, the script will select port 443 (which is the default). He will ask for the protocol, the choice will be from 3 protocols: vless, trojan, shadowsk. The default is vless (that is, if you press Enter, the script will select vless). The script begins generating uuid, pbk, pvk, shortId and recognizes the server's IP through ipconfig. It records the configuration in a config.json file. It assembles the configuration already for the APP. I'm going to send the script myself here so that I don't have to go to this site every time. 
#!/bin/bash

read -p  "Hi, are you sure I'd set up a VPN for you?|Ты уверен в том, что бы я начал настройку впн за тебя?(y/n)" agreesetupvpn

if [ "$agreesetupvpn" = "y" ]; then
    echo "Okay, start core installation|Окей, начинаю установку ядра..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
else
    exit
    fi

read -p "Core installation finished. Choose a port for your VPN (default is 443):" port
vpnport=${vpnport:-443}
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
 For those who don't know how to write this script: write nano setupVPN.sh[instead of setupVPN, specify any other name for the script, but leaving sh. I'll use setupVPN everywhere, but you use the other name you want for the script). Now copy my script and get into the editor. When you write, press cntrl+o (save) and cntrl+x (out). Give the launch rights to:chmod +x setupVPN.sh. Now you can run:setupVPN.sh.
 I'm ONLY STUDYING!!! POSSIBLE TO BE FACILITATIONS!! I'll DO WORK!! 
