#!/bin/bash
set -o pipefail

#by JotchuaDevz
clear

# Initializing Server
export DEBIAN_FRONTEND=noninteractive
source /etc/os-release

SUPPORT_LEVEL="unsupported"
case "$ID:$VERSION_ID" in
  ubuntu:20.04) SUPPORT_LEVEL="legacy" ;;
  ubuntu:22.04) SUPPORT_LEVEL="recommended" ;;
  ubuntu:24.04) SUPPORT_LEVEL="supported" ;;
  debian:11) SUPPORT_LEVEL="legacy" ;;
  debian:12) SUPPORT_LEVEL="supported" ;;
  *) SUPPORT_LEVEL="unsupported" ;;
esac

echo "============================================================"
echo "              Instalador de Script SSH Hex Tunnel"
echo "============================================================"
echo ""
echo "Sistemas Operativos Soportados:"
echo ""
echo "  ✔ Debian 12              (Recomendado)"
echo "  ✔ Debian 11              (Soporte Legado)"
echo "  ✔ Ubuntu 24.04           (Soportado)"
echo "  ✔ Ubuntu 22.04           (Recomendado)"
echo "  ✔ Ubuntu 20.04           (Soporte Legado)"
echo ""
echo "============================================================"
sleep 2

if [ "$SUPPORT_LEVEL" = "unsupported" ]; then
  echo "Este instalador solo soporta Ubuntu 20.04/22.04/24.04 y Debian 11/12."
  echo "Detectado: ${ID} ${VERSION_ID}"
  exit 1
fi

#Script Variables
read -p "Ingresa tu Dominio/Subdominio para Xray (o presiona enter para usar la IP): " -e -i "$(curl -4 -s --max-time 2 ipv4.icanhazip.com || hostname -I | awk '{print $1}')" DOMAIN
export DOMAIN

# OpenSSH Ports
SSH_Port1='22'
SSH_Port2='299'

# Stunnel Ports (Internal Fallback)
Stunnel_Port='127.0.0.1:4443'
Stunnel_Port_Num='4443' 

# Squid Ports
Squid_Port1='3128'
Squid_Port2='8000'

# Node.js Socks Proxy (Isolated Ports)
WsPorts=('10080' '25' '2082' '2086')  
WsPort='10080'  

# SSLH Port
MainPort='666' 

# SSH SlowDNS
read -p "Ingresa el Nameserver de SlowDNS (o presiona enter para el predeterminado): " -e -i "ns-miami.hexapps.app" Nameserver
Serverkey='819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae'
Serverpub='7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59'

# UDP HYSTERIA | UDP PORT | OBFS | PASSWORDS
UDP_PORT=":36712"
_default_obfs='HexTunnel'
_default_password='HexTunnel'

if [ -t 0 ]; then
  read -e -p "Ingresa la cadena de ofuscación de Hysteria (obfs) [${_default_obfs}]: " -i "${_default_obfs}" _input_obfs
  OBFS="${_input_obfs:-${_default_obfs}}"
  read -e -p "Ingresa la contraseña de Hysteria [${_default_password}]: " -i "${_default_password}" _input_pass
  PASSWORD="${_input_pass:-${_default_password}}"
else
  OBFS="${OBFS:-${_default_obfs}}"
  PASSWORD="${PASSWORD:-${_default_password}}"
fi

export OBFS PASSWORD

# WebServer Ports
Nginx_Port='85' 

# DNS Resolver cloudflare dns
Dns_1='1.1.1.1' 
Dns_2='1.0.0.1'

# Server local time
MyVPS_Time='Africa/Accra'

# Telegram IDs
My_Chat_ID='344472672'
My_Bot_Key='8715170470:AAE8urT5fSWdZ_xgkwwZivN4kgHW9nBVxgY'

function ip_address(){
  local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com )"
  [ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipinfo.io/ip )"
  [ ! -z "${IP}" ] && echo "${IP}" || echo
} 
IPADDR="$(ip_address)"

red='\e[1;31m'; green='\e[0;32m'; NC='\e[0m'

apt-get update -y && apt-get upgrade -y --with-new-pkgs

systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null

SSH_SERVICE="ssh"; STUNNEL_SERVICE="stunnel4"; SQUID_SERVICE="squid"; SSLH_SERVICE="sslh"; NGINX_SERVICE="nginx"; SFTP_SUBSYSTEM="internal-sftp"

mkdir -p /etc/stunnel /etc/nginx/conf.d /etc/deekayvpn /var/run/sslh /etc/xray
echo "$DOMAIN" > /etc/deekayvpn/domain.txt
ssh-keygen -A >/dev/null 2>&1 || true

command -v ss >/dev/null 2>&1 || apt-get install -y iproute2
command -v netfilter-persistent >/dev/null 2>&1 || apt-get install -y netfilter-persistent iptables-persistent
command -v jq >/dev/null 2>&1 || apt-get install -y jq
command -v curl >/dev/null 2>&1 || apt-get install -y curl

if ! systemctl list-unit-files | grep -q "^${STUNNEL_SERVICE}\.service"; then
  if systemctl list-unit-files | grep -q "^stunnel\.service"; then STUNNEL_SERVICE="stunnel"; fi
fi
if ! systemctl list-unit-files | grep -q "^${SQUID_SERVICE}\.service"; then
  if systemctl list-unit-files | grep -q "^squid3\.service"; then SQUID_SERVICE="squid3"; fi
fi

PACKAGE_LIST=(
  neofetch sslh dnsutils stunnel4 squid nano sudo wget unzip tar zip gzip
  iptables iptables-persistent netfilter-persistent bc cron dos2unix whois screen ruby
  apt-transport-https software-properties-common gnupg2 ca-certificates curl net-tools 
  nginx certbot jq figlet git gcc make build-essential perl expect libdbi-perl vnstat socat
  libnet-ssleay-perl libauthen-pam-perl libio-pty-perl apt-show-versions openssh-server rsyslog lsof procps
)

AVAILABLE_PACKAGES=()
for pkg in "${PACKAGE_LIST[@]}"; do
  if apt-cache show "$pkg" >/dev/null 2>&1; then AVAILABLE_PACKAGES+=("$pkg"); fi
done

echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1
rm -f /etc/resolv.conf
printf 'nameserver %s\nnameserver %s\n' "$Dns_1" "$Dns_2" > /etc/resolv.conf
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime

cat > /root/.profile <<'EOF_PROFILE'
clear
echo "Script Por JotchuaDevz"
echo "Escribe 'menu' Para Ver Los Comandos"
EOF_PROFILE

apt-get install -y "${AVAILABLE_PACKAGES[@]}"

systemctl enable "$SSH_SERVICE" || true
systemctl enable rsyslog || true
systemctl restart rsyslog || true
gem install lolcat
apt -y --purge remove apache2 ufw firewalld
systemctl stop nginx

wget -q https://github.com/webmin/webmin/releases/download/2.111/webmin_2.111_all.deb
dpkg --install webmin_2.111_all.deb || apt-get install -f -y
rm -rf webmin_2.111_all.deb
sed -i 's|ssl=1|ssl=0|g' /etc/webmin/miniserv.conf
systemctl restart webmin || true

# === HARDCODED CERTIFICATE FOR XRAY & STUNNEL ===
echo "Aplicando Certificado SSL predeterminado para Xray y Stunnel..."

cat <<'EOF_KEY' > /etc/xray/xray.key
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQClmgCdm7RB2VWK
wfH8HO/T9bxEddWDsB3fJKpM/tiVMt4s/WMdGJtFdRlxzUb03u+HT6t00sLlZ78g
ngjxLpJGFpHAGdVf9vACBtrxv5qcrG5gd8k7MJ+FtMTcjeQm8kVRyIW7cOWxlpGY
6jringYZ6NcRTrh/OlxIHKdsLI9ddcekbYGyZVTm1wd22HVG+07PH/AeyY78O2+Z
tbjxGTFRSYt3jUaFeUmWNtxqWnR4MPmC+6iKvUKisV27P89g8v8CiZynAAWRJ0+A
qp+PWxwHi/iJ501WdLspeo8VkXIb3PivyIKC356m+yuuibD2uqwLZ2//afup84Qu
pRtgW/PbAgMBAAECggEAVo/efIQUQEtrlIF2jRNPJZuQ0rRJbHGV27tdrauU6MBT
NG8q7N2c5DymlT75NSyHRlKVzBYTPDjzxgf1oqR2X16Sxzh5uZTpthWBQtal6fmU
JKbYsDDlYc2xDZy5wsXnCC3qAaWs2xxadPUS3Lw/cjGsoeZlOFP4QtV/imLseaws
7r4KZE7SVO8dF8Xtcy304Bd7UsKClnbCrGsABUF/rqA8g34o7yrpo9XqcwbF5ihQ
TbnB0Ns8Bz30pjgGjJZTdTL3eskP9qMJWo/JM76kSaJWReoXTws4DlQHxO29z3eK
zKdxieXaBGMwFnv23JvXKJ5eAnxzqsL6a+SuNPPN4QKBgQDQhisSDdjUJWy0DLnJ
/HjtsnQyfl0efOqAlUEir8r5IdzDTtAEcW6GwPj1rIOm79ZeyysT1pGN6eulzS1i
6lz6/c5uHA9Z+7LT48ZaQjmKF06ItdfHI9ytoXaaQPMqW7NnyOFxCcTHBabmwQ+E
QZDFkM6vVXL37Sz4JyxuIwCNMQKBgQDLThgKi+L3ps7y1dWayj+Z0tutK2JGDww7
6Ze6lD5gmRAURd0crIF8IEQMpvKlxQwkhqR4vEsdkiFFJQAaD+qZ9XQOkWSGXvKP
A/yzk0Xu3qL29ZqX+3CYVjkDbtVOLQC9TBG60IFZW79K/Zp6PhHkO8w6l+CBR+yR
X4+8x1ReywKBgQCfSg52wSski94pABugh4OdGBgZRlw94PCF/v390En92/c3Hupa
qofi2mCT0w/Sox2f1hV3Fw6jWNDRHBYSnLMgbGeXx0mW1GX75OBtrG8l5L3yQu6t
SeDWpiPim8DlV52Jp3NHlU3DNrcTSOFgh3Fe6kpot56Wc5BJlCsliwlt0QKBgEol
u0LtbePgpI2QS41ewf96FcB8mCTxDAc11K6prm5QpLqgGFqC197LbcYnhUvMJ/eS
W53lHog0aYnsSrM2pttr194QTNds/Y4HaDyeM91AubLUNIPFonUMzVJhM86FP0XK
3pSBwwsyGPxirdpzlNbmsD+WcLz13GPQtH2nPTAtAoGAVloDEEjfj5gnZzEWTK5k
4oYWGlwySfcfbt8EnkY+B77UVeZxWnxpVC9PhsPNI1MTNET+CRqxNZzxWo3jVuz1
HtKSizJpaYQ6iarP4EvUdFxHBzjHX6WLahTgUq90YNaxQbXz51ARpid8sFbz1f37
jgjgxgxbitApzno0E2Pq/Kg=
-----END PRIVATE KEY-----
EOF_KEY

cat <<'EOF_CRT' > /etc/xray/xray.crt
-----BEGIN CERTIFICATE-----
MIIDRTCCAi2gAwIBAgIUOvs3vdjcBtCLww52CggSlAKafDkwDQYJKoZIhvcNAQEL
BQAwMjEQMA4GA1UEAwwHS29ielZQTjERMA8GA1UECgwIS29iZUtvYnoxCzAJBgNV
BAYTAlBIMB4XDTIxMDcwNzA1MzQwN1oXDTMxMDcwNTA1MzQwN1owMjEQMA4GA1UE
AwwHS29ielZQTjERMA8GA1UECgwIS29iZUtvYnoxCzAJBgNVBAYTAlBIMIIBIjAN
BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApZoAnZu0QdlVisHx/Bzv0/W8RHXV
g7Ad3ySqTP7YlTLeLP1jHRibRXUZcc1G9N7vh0+rdNLC5We/IJ4I8S6SRhaRwBnV
X/bwAgba8b+anKxuYHfJOzCfhbTE3I3kJvJFUciFu3DlsZaRmOo64p4GGejXEU64
fzpcSBynbCyPXXXHpG2BsmVU5tcHdth1RvtOzx/wHsmO/DtvmbW48RkxUUmLd41G
hXlJljbcalp0eDD5gvuoir1CorFduz/PYPL/AomcpwAFkSdPgKqfj1scB4v4iedN
VnS7KXqPFZFyG9z4r8iCgt+epvsrromw9rqsC2dv/2n7qfOELqUbYFvz2wIDAQAB
o1MwUTAdBgNVHQ4EFgQUcKFL6tckon2uS3xGrpe1Zpa68VEwHwYDVR0jBBgwFoAU
cKFL6tckon2uS3xGrpe1Zpa68VEwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0B
AQsFAAOCAQEAYQP0S67eoJWpAMavayS7NjK+6KMJtlmL8eot/3RKPLleOjEuCdLY
QvrP0Tl3M5gGt+I6WO7r+HKT2PuCN8BshIob8OGAEkuQ/YKEg9QyvmSm2XbPVBaG
RRFjvxFyeL4gtDlqb9hea62tep7+gCkeiccyp8+lmnS32rRtFa7PovmK5pUjkDOr
dpvCQlKoCRjZ/+OfUaanzYQSDrxdTSN8RtJhCZtd45QbxEXzHTEaICXLuXL6cmv7
tMuhgUoefS17gv1jqj/C9+6ogMVa+U7QqOvL5A7hbevHdF/k/TMn+qx4UdhrbL5Q
enL3UGT+BhRAPiA1I5CcG29RqjCzQoaCNg==
-----END CERTIFICATE-----
EOF_CRT

chmod 644 /etc/xray/xray.crt; chmod 600 /etc/xray/xray.key

# Copy and secure Stunnel cert
cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem; chown root:root /etc/stunnel/stunnel.pem

cat <<'deekay77' > /etc/zorro-luffy
<br><font color="#C12267">HEX TUNNEL | VPN | SERVICE<br></font><br>
<font color="#b3b300"> x No DDOS<br></font>
<font color="#00cc00"> x No Torrent<br></font>
<font color="#ff1aff"> x No Spamming<br></font>
<font color="blue"> x No Phishing<br></font>
<font color="#A810FF"> x No Hacking<br></font><br>
<font color="red">• BROUGHT TO YOU BY <br></font><font color="#00cccc">https://t.me/RequestLab_X_Canal !<br></font>
deekay77

# OpenSSH
rm -f /etc/ssh/sshd_config
cat <<'MySSHConfig' > /etc/ssh/sshd_config
Port myPORT1
Port myPORT2
AddressFamily inet
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
MaxSessions 1024
MaxStartups 200:30:400
LoginGraceTime 30
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
UsePAM yes
X11Forwarding yes
PrintMotd no
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
Banner /etc/zorro-luffy
AcceptEnv LANG LC_*
Subsystem sftp SFTP_SUBSYSTEM
MySSHConfig

sed -i "s|myPORT1|$SSH_Port1|g" /etc/ssh/sshd_config
sed -i "s|myPORT2|$SSH_Port2|g" /etc/ssh/sshd_config
sed -i "s|SFTP_SUBSYSTEM|$SFTP_SUBSYSTEM|g" /etc/ssh/sshd_config
sed -i '/password\s*requisite\s*pam_cracklib.s.*/d' /etc/pam.d/common-password
sed -i 's/use_authtok //g' /etc/pam.d/common-password
sed -i '/\/bin\/false/d' /etc/shells
sed -i '/\/usr\/sbin\/nologin/d' /etc/shells
echo '/bin/false' >> /etc/shells; echo '/usr/sbin/nologin' >> /etc/shells
systemctl restart "$SSH_SERVICE"

# SSLH
cd /etc/default/
cat << sslh > /etc/default/sslh
RUN=yes
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 127.0.0.1:$MainPort --ssh 127.0.0.1:$SSH_Port1 --http 127.0.0.1:$WsPort --pidfile /var/run/sslh/sslh.pid"
sslh
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid
systemctl daemon-reload; systemctl enable "$SSLH_SERVICE"; systemctl restart "$SSLH_SERVICE"
cd

# Stunnel
StunnelDir=$(ls /etc/default | grep stunnel | head -n1)
cat <<'MyStunnelD' > /etc/default/$StunnelDir
ENABLED=1
FILES="/etc/stunnel/*.conf"
OPTIONS=""
BANNER="/etc/zorro-luffy"
PPP_RESTART=0
RLIMITS=""
MyStunnelD

cat <<'MyStunnelC' > /etc/stunnel/stunnel.conf
pid = /var/run/stunnel.pid
cert = /etc/stunnel/stunnel.pem
client = no
syslog = no
debug = 0
output = /dev/null
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
TIMEOUTclose = 0
[sslh]
accept = Stunnel_Port
connect = 127.0.0.1:MainPort
MyStunnelC

sed -i "s|Stunnel_Port|$Stunnel_Port|g" /etc/stunnel/stunnel.conf
sed -i "s|MainPort|$MainPort|g" /etc/stunnel/stunnel.conf
systemctl enable "$STUNNEL_SERVICE"; systemctl restart "$STUNNEL_SERVICE"

# Node.js Socks Proxy (Isolated Multi-Process)
loc=/etc/socksproxy; mkdir -p $loc; apt-get install -y nodejs

cat <<EOF > $loc/proxy.js
const net = require('net');
process.on('uncaughtException', (err) => { console.error('Unhandled Exception:', err); });
const TARGET_HOST = '127.0.0.1'; const TARGET_PORT = $SSH_Port1;
const LISTEN_PORT = parseInt(process.argv[2]);
if (!LISTEN_PORT) { process.exit(1); }
const handleConnection = (clientSocket) => {
    clientSocket.once('data', (data) => {
        const targetSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
            clientSocket.write('HTTP/1.1 101 <font color="yellow">Hex Tunnel</font>\r\n\r\n');
            clientSocket.pipe(targetSocket); targetSocket.pipe(clientSocket);
        });
        targetSocket.on('error', () => clientSocket.destroy());
        targetSocket.on('close', () => clientSocket.destroy());
    });
    clientSocket.on('error', () => {}); clientSocket.on('close', () => {});
};
const server = net.createServer(handleConnection);
server.listen(LISTEN_PORT, '0.0.0.0', () => { console.log(\`WS Proxy active on isolated port \${LISTEN_PORT}\`); });
EOF

cat <<'service' > /etc/systemd/system/ws-proxy@.service
[Unit]
Description=Node.js WebSocket Proxy on port %i
After=network.target nss-lookup.target
[Service]
Type=simple
User=root
WorkingDirectory=/etc/socksproxy
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
LimitNOFILE=1048576
Restart=always
RestartSec=1
ExecStart=/usr/bin/node /etc/socksproxy/proxy.js %i
SyslogIdentifier=ws-proxy-%i
[Install]
WantedBy=multi-user.target
service

systemctl daemon-reload
for port in "${WsPorts[@]}"; do systemctl enable ws-proxy@$port; systemctl restart ws-proxy@$port; done

# === XRAY CORE ===
echo "Instalando Xray Core Estable v26.5.9..."
XRAY_VER="v26.5.9"
wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-64.zip"
unzip -q -o /tmp/xray.zip -d /tmp/xray/
mv -f /tmp/xray/xray /usr/local/bin/xray
chmod +x /usr/local/bin/xray
rm -rf /tmp/xray*
touch /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt

cat <<EOF > /etc/xray/config.json
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
    {
      "port": 443, "protocol": "vless",
      "settings": { "clients": [], "decryption": "none", "fallbacks": [ { "path": "/vmess", "dest": 10001 }, { "path": "/trojan", "dest": 10002 }, { "path": "/vless", "dest": 10003 }, { "dest": 666 } ] },
      "streamSettings": { "network": "tcp", "security": "tls", "tlsSettings": { "alpn": ["http/1.1"], "certificates": [ { "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" } ] } }
    },
    { "listen": "127.0.0.1", "port": 10001, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } } },
    { "listen": "127.0.0.1", "port": 10002, "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } } },
    { "port": "80,8080,8880", "protocol": "vless", "settings": { "clients": [], "decryption": "none", "fallbacks": [ { "path": "/vless", "dest": 10003 }, { "path": "/vmess", "dest": 10004 }, { "dest": 10080 } ] }, "streamSettings": { "network": "tcp" } },
    { "listen": "127.0.0.1", "port": 10003, "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } } },
    { "listen": "127.0.0.1", "port": 10004, "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } } }
  ],
  "outbounds": [ { "protocol": "freedom", "settings": {} }, { "protocol": "blackhole", "settings": {}, "tag": "blocked" } ]
}
EOF

mkdir -p /var/log/xray
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable xray; systemctl restart xray

# USER EXPIRY CRONJOB FOR XRAY
cat <<'EOF_EXP' > /usr/local/bin/exp-check
#!/bin/bash
now=$(date +%Y-%m-%d)
for proto in vless vmess trojan; do
  if [ -f "/etc/xray/${proto}.txt" ]; then
    data=( $(cat /etc/xray/${proto}.txt | awk '{print $1}') )
    for user in "${data[@]}"; do
      exp=$(grep -w "^$user" "/etc/xray/${proto}.txt" | awk '{print $3}')
      if [[ "$now" > "$exp" ]]; then
        jq "(.inbounds[].settings.clients) |= map(select(.email != \"$user\"))" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
        sed -i "/^$user /d" /etc/xray/${proto}.txt
      fi
    done
  fi
done
systemctl restart xray
EOF_EXP
chmod +x /usr/local/bin/exp-check
echo "0 0 * * * root /usr/local/bin/exp-check >/dev/null 2>&1" > /etc/cron.d/xray-expiry

# USER EXPIRY CRONJOB FOR HYSTERIA
cat <<'EOF_HYST_EXP' > /usr/local/bin/hysteria-exp
#!/bin/bash
now=$(date +%Y-%m-%d)
USER_DB="/etc/hysteria/users.txt"
CONFIG="/etc/hysteria/config.json"
changed=0

if [ -f "$USER_DB" ]; then
  # Read expired users into an array securely to avoid modifying the file while reading it
  mapfile -t expired_users < <(awk -v d="$now" '$2 < d {print $1}' "$USER_DB")
  
  for user in "${expired_users[@]}"; do
    # Remove from JSON config
    jq ".inbounds[0].users |= map(select(.auth_str != \"$user\"))" "$CONFIG" > /tmp/h.json && mv /tmp/h.json "$CONFIG"
    # Remove from TXT DB
    sed -i "/^$user /d" "$USER_DB"
    changed=1
  done
  
  # Only restart the UDP core if an account was actually scrubbed
  if [ "$changed" -eq 1 ]; then
    systemctl restart hysteria-server
  fi
fi
EOF_HYST_EXP

chmod +x /usr/local/bin/hysteria-exp
echo "0 0 * * * root /usr/local/bin/hysteria-exp >/dev/null 2>&1" > /etc/cron.d/hysteria-expiry

# Nginx & Squid
rm -rf /home/vps/public_html /etc/nginx/sites-* /etc/nginx/nginx.conf; mkdir -p /home/vps/public_html
cat <<'myNginxC' > /etc/nginx/nginx.conf
user www-data; worker_processes auto; pid /var/run/nginx.pid;
events { multi_accept on; worker_connections 8192; }
http { gzip on; gzip_vary on; gzip_comp_level 5; gzip_types text/plain application/x-javascript text/xml text/css; autoindex on; sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 65; types_hash_max_size 2048; server_tokens off; include /etc/nginx/mime.types; default_type application/octet-stream; access_log /var/log/nginx/access.log; error_log /var/log/nginx/error.log; client_max_body_size 32M; client_header_buffer_size 8m; large_client_header_buffers 8 8m; fastcgi_buffer_size 8m; fastcgi_buffers 8 8m; fastcgi_read_timeout 600; include /etc/nginx/conf.d/*.conf; }
myNginxC
cat <<'myvpsC' > /etc/nginx/conf.d/vps.conf
server { listen Nginx_Port; server_name 127.0.0.1 localhost; root /home/vps/public_html; location / { try_files $uri $uri/ /index.php?$args; } }
myvpsC
sed -i "s|Nginx_Port|$Nginx_Port|g" /etc/nginx/conf.d/vps.conf
systemctl restart "$NGINX_SERVICE"

rm -rf /etc/squid/squid.con*
cat <<'mySquid' > /etc/squid/squid.conf
acl server dst IP-ADDRESS/32 localhost
acl ports_ port 14 22 53 21 8081 25 8000 3128 443 80 8080 8880 2082 2086 36712
http_port Squid_Port1
http_port Squid_Port2
http_access allow server
http_access deny all
http_access allow all
visible_hostname IP-ADDRESS
mySquid
sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/squid/squid.conf; sed -i "s|Squid_Port1|$Squid_Port1|g" /etc/squid/squid.conf; sed -i "s|Squid_Port2|$Squid_Port2|g" /etc/squid/squid.conf
systemctl restart "$SQUID_SERVICE"

# Health Checks
mkdir -p /etc/deekayvpn/health
cat <<'ServiceChecker' > /etc/deekayvpn/service_checker.sh
#!/bin/bash
MYID="MYCHATID"; KEY="MYBOTID"; URL="https://api.telegram.org/bot${KEY}/sendMessage"
send_telegram_message() { curl -s --max-time 10 --retry 5 --retry-delay 2 --retry-max-time 10 -d "chat_id=${MYID}&text=$1&disable_web_page_preview=true&parse_mode=markdown" "${URL}" >/dev/null 2>&1; }
server_ip="IPADDRESS"; datenow=$(date +"%Y-%m-%d %T"); IPCOUNTRY=$(curl -s "https://freeipapi.com/api/json/${server_ip}" | jq -r '.countryName')
STATE_DIR="/etc/deekayvpn/health"
check_port() { ss -lnt | awk '{print $4}' | grep -q ":$1$"; }
mark_fail() { local f="$STATE_DIR/$1.fail"; local n=0; [ -f "$f" ] && n=$(cat "$f"); n=$((n+1)); echo "$n" > "$f"; echo "$n"; }
clear_fail() { rm -f "$STATE_DIR/$1.fail"; }
restart_after_3_fails() {
    local fails=$(mark_fail "$1")
    if [ "$fails" -ge 3 ]; then
        systemctl restart "$2" >/dev/null 2>&1
        send_telegram_message "Service *$2* was offline or missing port(s) *$3* on server *${IPCOUNTRY}* ($server_ip). It has been auto-restarted at *${datenow}*."
        clear_fail "$1"
    fi
}
if check_port SSHPORT1 && check_port SSHPORT2 && systemctl is-active --quiet ssh; then clear_fail ssh; else restart_after_3_fails ssh ssh "SSHPORT1,SSHPORT2"; fi
if check_port STUNNELPORT && systemctl is-active --quiet stunnel4; then clear_fail stunnel4; else restart_after_3_fails stunnel4 stunnel4 "STUNNELPORT"; fi
if check_port SSLHPORT && systemctl is-active --quiet sslh; then clear_fail sslh; else restart_after_3_fails sslh sslh "SSLHPORT"; fi
if check_port SQUIDPORT1 && check_port SQUIDPORT2 && systemctl is-active --quiet squid; then clear_fail squid; else restart_after_3_fails squid squid "SQUIDPORT1,SQUIDPORT2"; fi
if check_port NGINXPORT && systemctl is-active --quiet nginx; then clear_fail nginx; else restart_after_3_fails nginx nginx "NGINXPORT"; fi
for port in 10080 25 2082 2086; do if check_port $port && systemctl is-active --quiet ws-proxy@$port; then clear_fail ws-proxy-$port; else restart_after_3_fails ws-proxy-$port ws-proxy@$port "$port"; fi; done
if check_port 443 && systemctl is-active --quiet xray; then clear_fail xray; else restart_after_3_fails xray xray "443, 80"; fi
if systemctl is-active --quiet hysteria-server; then clear_fail hysteria-server; else restart_after_3_fails hysteria-server hysteria-server "UDP"; fi
ServiceChecker

chmod 755 /etc/deekayvpn/service_checker.sh
sed -i "s|MYCHATID|$My_Chat_ID|g" /etc/deekayvpn/service_checker.sh
sed -i "s|MYBOTID|$My_Bot_Key|g" /etc/deekayvpn/service_checker.sh
sed -i "s|IPADDRESS|$IPADDR|g" /etc/deekayvpn/service_checker.sh
sed -i "s|STUNNELPORT|$Stunnel_Port_Num|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSLHPORT|$MainPort|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SQUIDPORT1|$Squid_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SQUIDPORT2|$Squid_Port2|g" /etc/deekayvpn/service_checker.sh
sed -i "s|NGINXPORT|$Nginx_Port|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSHPORT1|$SSH_Port1|g" /etc/deekayvpn/service_checker.sh
sed -i "s|SSHPORT2|$SSH_Port2|g" /etc/deekayvpn/service_checker.sh

echo "*/3 * * * * root /bin/bash /etc/deekayvpn/service_checker.sh >/dev/null 2>&1" > /etc/cron.d/service-checker
rm -f /etc/logrotate.d/rsyslog
cat <<'logrotate' > /etc/logrotate.d/rsyslog
/var/log/syslog /var/log/kern.log /var/log/auth.log /var/log/xray/access.log /var/log/xray/error.log { rotate 7; daily; missingok; notifempty; compress; delaycompress; sharedscripts; postrotate; /usr/lib/rsyslog/rsyslog-rotate; endscript; }
logrotate
chown root:root /var/log; chmod 755 /var/log; chown syslog:adm /var/log/syslog; chmod 640 /var/log/syslog
echo "*/5 * * * * root /usr/sbin/logrotate -v -f /etc/logrotate.d/rsyslog >/dev/null 2>&1" > /etc/cron.d/logrotate
echo "0 3 * * * root sync; echo 3 > /proc/sys/vm/drop_caches" > /etc/cron.d/drop-cache

# ==========================================
# AGGRESSIVE SYSTEM & CONNTRACK TUNING
# ==========================================
# Force load nf_conntrack module
modprobe nf_conntrack 2>/dev/null || true; echo "nf_conntrack" > /etc/modules-load.d/freenet.conf
cat <<'SYSCTL' > /etc/sysctl.d/99-freenet-tuning.conf
# File Descriptors
fs.file-max = 1048576

# Network Core
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384

# TCP Settings
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10

# SOCKS / WARP Local Loopback Optimization
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1

# Connection Tracking Limits (Prevents silent drops)
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
net.netfilter.nf_conntrack_udp_timeout = 60
SYSCTL
sysctl --system || true
mkdir -p /etc/security/limits.d
cat <<'LIMITS' > /etc/security/limits.d/99-freenet.conf
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS

# SLOWDNS
rm -rf /etc/slowdns; mkdir -m 777 /etc/slowdns
cat > /etc/slowdns/server.key << END
$Serverkey
END
cat > /etc/slowdns/server.pub << END
$Serverpub
END
wget -q -O /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
chmod +x /etc/slowdns/server.key /etc/slowdns/server.pub /etc/slowdns/sldns-server
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT
cat > /etc/systemd/system/server-sldns.service << END
[Unit]
Description=Server SlowDNS
After=network.target
[Service]
ExecStart=/etc/slowdns/sldns-server -udp :53 -privkey-file /etc/slowdns/server.key $Nameserver 127.0.0.1:$SSH_Port2
Restart=on-failure
[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload; systemctl enable server-sldns; systemctl restart server-sldns

# === HYSTERIA v1 (Sing-box v1.12.22) & CLOUDFLARE WARP ===
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list
apt-get update && apt-get install -y cloudflare-warp

warp-cli --accept-tos disconnect 2>/dev/null || true
warp-cli --accept-tos registration delete 2>/dev/null || true
warp-cli --accept-tos registration new 2>/dev/null || warp-cli --accept-tos register
warp-cli --accept-tos mode proxy
warp-cli --accept-tos proxy port 40000
warp-cli --accept-tos connect
sleep 2

wget -qO /tmp/sing-box.deb "https://github.com/SagerNet/sing-box/releases/download/v1.12.22/sing-box_1.12.22_linux_amd64.deb"
dpkg -i /tmp/sing-box.deb
apt-mark hold sing-box
rm -f /tmp/sing-box.deb

mkdir -p /etc/hysteria
HYST_PORT="${UDP_PORT##*:}"

cat << EOF > /etc/hysteria/hysteria.crt
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: 40:26:da:91:18:2b:77:9c:85:6a:0c:bb:ca:90:53:fe
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=KobZ
        Validity
            Not Before: Jul 22 22:23:55 2020 GMT
            Not After : Jul 20 22:23:55 2030 GMT
        Subject: CN=server
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (1024 bit)
                Modulus:
                    00:ce:35:23:d8:5d:9f:b6:9b:cb:6a:89:e1:90:af:
                    42:df:5f:f8:bd:ad:a7:78:9a:ca:20:f0:3d:5b:d6:
                    c9:ef:4c:4a:99:96:c3:38:fd:59:b4:d7:65:ed:d4:
                    a7:fa:ab:03:e2:be:88:2f:ca:fc:90:dd:b0:b7:bc:
                    23:cb:83:ac:36:e2:01:57:69:64:b8:e1:9e:51:f0:
                    a6:9d:13:d9:92:6b:4d:04:a6:10:64:a3:3f:6b:ff:
                    fe:32:ac:91:63:c2:71:24:be:9e:76:4f:87:cc:3a:
                    03:a1:9e:48:3f:11:92:33:3b:19:16:9c:d0:5d:16:
                    ee:c1:42:67:99:47:66:67:67
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints: CA:FALSE
            X509v3 Subject Key Identifier: 6B:08:C0:64:10:71:A8:32:7F:0B:FE:1E:98:1F:BD:72:74:0F:C8:66
            X509v3 Authority Key Identifier: keyid:64:49:32:6F:FE:66:62:F1:57:4D:BB:91:A8:5D:BD:26:3E:51:A4:D2
                DirName:/CN=KobZ
                serial:01:A4:01:02:93:12:D9:D6:01:A9:83:DC:03:73:DA:ED:C8:E3:C3:B7
            X509v3 Extended Key Usage: TLS Web Server Authentication
            X509v3 Key Usage: Digital Signature, Key Encipherment
            X509v3 Subject Alternative Name: DNS:server
    Signature Algorithm: sha256WithRSAEncryption
         a1:3e:ac:83:0b:e5:5d:ca:36:b7:d0:ab:d0:d9:73:66:d1:62:
         88:ce:3d:47:9e:08:0b:a0:5b:51:13:fc:7e:d7:6e:17:0e:bd:
         f5:d9:a9:d9:06:78:52:88:5a:e5:df:d3:32:22:4a:4b:08:6f:
         b1:22:80:4f:19:d1:5f:9d:b6:5a:17:f7:ad:70:a9:04:00:ff:
         fe:84:aa:e1:cb:0e:74:c0:1a:75:0b:3e:98:90:1d:22:ba:a4:
         7a:26:65:7d:d1:3b:5c:45:a1:77:22:ed:b6:6b:18:a3:c4:ee:
         3e:06:bb:0b:ec:12:ac:16:a5:50:b3:ed:46:43:87:72:fd:75:8c:38
-----BEGIN CERTIFICATE-----
MIICVDCCAb2gAwIBAgIQQCbakRgrd5yFagy7ypBT/jANBgkqhkiG9w0BAQsFADAP
MQ0wCwYDVQQDDARLb2JaMB4XDTIwMDcyMjIyMjM1NVoXDTMwMDcyMDIyMjM1NVow
ETEPMA0GA1UEAwwGc2VydmVyMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDO
NSPYXZ+2m8tqieGQr0LfX/i9rad4msog8D1b1snvTEqZlsM4/Vm012Xt1Kf6qwPi
vogvyvyQ3bC3vCPLg6w24gFXaWS44Z5R8KadE9mSa00EphBkoz9r//4yrJFjwnEk
vp52T4fMOgOhnkg/EZIzOxkWnNBdFu7BQmeZR2ZnZwIDAQABo4GuMIGrMAkGA1Ud
EwQCMAAwHQYDVR0OBBYEFGsIwGQQcagyfwv+HpgfvXJ0D8hmMEoGA1UdIwRDMEGA
FGRJMm/+ZmLxV027kahdvSY+UaTSoROkETAPMQ0wCwYDVQQDDARLb2JaghQBpAEC
kxLZ1gGpg9wDc9rtyOPDtzATBgNVHSUEDDAKBggrBgEFBQcDATALBgNVHQ8EBAMC
BaAwEQYDVR0RBAowCIIGc2VydmVyMA0GCSqGSIb3DQEBCwUAA4GBAKE+rIML5V3K
NrfQq9DZc2bRYojOPUeeCAugW1ET/H7XbhcOvfXZqdkGeFKIWuXf0zIiSksIb7Ei
gE8Z0V+dtloX961wqQQA//6EquHLDnTAGnULPpiQHSK6pHomZX3RO1xFoXci7bZr
GKPE7j4GuwvsEqwWpVCz7UZDh3L9dYw4
-----END CERTIFICATE-----
EOF

cat << EOF > /etc/hysteria/hysteria.key
-----BEGIN PRIVATE KEY-----
MIICdQIBADANBgkqhkiG9w0BAQEFAASCAl8wggJbAgEAAoGBAM41I9hdn7aby2qJ
4ZCvQt9f+L2tp3iayiDwPVvWye9MSpmWwzj9WbTXZe3Up/qrA+K+iC/K/JDdsLe8
I8uDrDbiAVdpZLjhnlHwpp0T2ZJrTQSmEGSjP2v//jKskWPCcSS+nnZPh8w6A6Ge
SD8RkjM7GRac0F0W7sFCZ5lHZmdnAgMBAAECgYAFNrC+UresDUpaWjwaxWOidDG8
0fwu/3Lm3Ewg21BlvX8RXQ94jGdNPDj2h27r1pEVlY2p767tFr3WF2qsRZsACJpI
qO1BaSbmhek6H++Fw3M4Y/YY+JD+t1eEBjJMa+DR5i8Vx3AE8XOdTXmkl/xK4jaB
EmLYA7POyK+xaDCeEQJBAPJadiYd3k9OeOaOMIX+StCs9OIMniRz+090AJZK4CMd
jiOJv0mbRy945D/TkcqoFhhScrke9qhgZbgFj11VbDkCQQDZ0aKBPiZdvDMjx8WE
y7jaltEDINTCxzmjEBZSeqNr14/2PG0X4GkBL6AAOLjEYgXiIvwfpoYE6IIWl3re
ebCfAkAHxPimrixzVGux0HsjwIw7dl//YzIqrwEugeSG7O2Ukpz87KySOoUks3Z1
yV2SJqNWskX1Q1Xa/gQkyyDWeCeZAkAbyDBI+ctc8082hhl8WZunTcs08fARM+X3
FWszc+76J1F2X7iubfIWs6Ndw95VNgd4E2xDATNg1uMYzJNgYvcTAkBoE8o3rKkp
em2n0WtGh6uXI9IC29tTQGr3jtxLckN/l9KsJ4gabbeKNoes74zdena1tRdfGqUG
JQbf7qSE3mg2
-----END PRIVATE KEY-----
EOF

cat > /etc/hysteria/config.json <<EOF
{
  "log": { "level": "fatal" },
  "inbounds": [
    {
      "type": "hysteria",
      "tag": "hy1-inbound",
      "listen": "::",
      "listen_port": $HYST_PORT,
      "up_mbps": 100, "down_mbps": 100,
      "obfs": "$OBFS",
      "users": [ { "auth_str": "$PASSWORD" } ],
      "tls": { "enabled": true, "certificate_path": "/etc/hysteria/hysteria.crt", "key_path": "/etc/hysteria/hysteria.key" }
    }
  ],
  "outbounds": [
    { "type": "socks", "tag": "warp-proxy", "server": "127.0.0.1", "server_port": 40000 },
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "rules": [
      {
        "inbound": "hy1-inbound",
        "network": "udp",
        "domain_suffix": [ "doubleclick.net", "googlesyndication.com", "googleadservices.com", "admob.com", "google-analytics.com", "app-measurement.com", "adservice.google.com", "g.doubleclick.net", "google.com", "pagead2.googlesyndication.com", "tpc.googlesyndication.com", "googlevideo.com", "gvt1.com", "gvt2.com", "gvt3.com", "ytimg.com", "youtube.com", "gstatic.com", "googleusercontent.com", "ggpht.com", "play.google.com", "firebaseio.com", "firebase.googleapis.com", "crashlytics.com", "fundingchoicesmessages.google.com", "imasdk.googleapis.com", "googleanalytics.com", "analytics.google.com", "fcm.googleapis.com", "mtalk.google.com", "firebaseinstallations.googleapis.com", "firebaselogging.googleapis.com", "firebaselogging-pa.googleapis.com", "firebaseremoteconfig.googleapis.com", "googleadapis.com", "accounts.google.com", "play.googleapis.com", "android.apis.google.com", "adsense.com", "1e100.net" ],
        "outbound": "block"
      },
      {
        "inbound": "hy1-inbound",
        "domain_suffix": [ "doubleclick.net", "googlesyndication.com", "googleadservices.com", "admob.com", "google-analytics.com", "app-measurement.com", "adservice.google.com", "g.doubleclick.net", "google.com", "pagead2.googlesyndication.com", "tpc.googlesyndication.com", "googlevideo.com", "gvt1.com", "gvt2.com", "gvt3.com", "ytimg.com", "youtube.com", "gstatic.com", "googleusercontent.com", "ggpht.com", "play.google.com", "firebaseio.com", "firebase.googleapis.com", "crashlytics.com", "fundingchoicesmessages.google.com", "imasdk.googleapis.com", "googleanalytics.com", "analytics.google.com", "fcm.googleapis.com", "mtalk.google.com", "firebaseinstallations.googleapis.com", "firebaselogging.googleapis.com", "firebaselogging-pa.googleapis.com", "firebaseremoteconfig.googleapis.com", "googleadapis.com", "accounts.google.com", "play.googleapis.com", "android.apis.google.com", "adsense.com", "1e100.net" ],
        "outbound": "warp-proxy"
      },
      { "inbound": "hy1-inbound", "outbound": "direct" }
    ],
    "auto_detect_interface": true
  }
}
EOF

chmod 755 /etc/hysteria/config.json /etc/hysteria/hysteria.crt /etc/hysteria/hysteria.key
echo "$PASSWORD $(date -d "+365 days" +"%Y-%m-%d")" > /etc/hysteria/users.txt

cat > /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Sing-Box Hysteria v1 Core
After=network.target
[Service]
User=root
ExecStart=/usr/bin/sing-box run -c /etc/hysteria/config.json
Restart=on-failure
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable hysteria-server.service; systemctl start hysteria-server.service

# NAT & Iptables Configuration
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
cat > /etc/systemd/system/hysteria-nat.service <<EOF
[Unit]
Description=Restore Hysteria UDP NAT rules
After=network-online.target
Wants=network-online.target
Before=hysteria-server.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'IFACE=\$(ip -4 route ls|grep default|grep -Po "(?<=dev )(\\\\S+)"|head -1); [ -n "\$IFACE" ] && (iptables -t nat -C PREROUTING -i "\$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT 2>/dev/null || iptables -t nat -A PREROUTING -i "\$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :$HYST_PORT)'
ExecStart=/bin/bash -c 'iptables -C INPUT -p udp --dport $HYST_PORT -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport $HYST_PORT -j ACCEPT'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload; systemctl enable hysteria-nat.service; systemctl start hysteria-nat.service

# Creating startup script
cat <<'deekayz' > /etc/deekaystartup
#!/bin/sh
ln -fs /usr/share/zoneinfo/MyTimeZone /etc/localtime
export DEBIAN_FRONTEND=noninteractive
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
echo "nameserver DNS1" > /etc/resolv.conf; echo "nameserver DNS2" >> /etc/resolv.conf
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712 2>/dev/null || iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712
deekayz

sed -i "s|MyTimeZone|$MyVPS_Time|g" /etc/deekaystartup
sed -i "s|DNS1|$Dns_1|g" /etc/deekaystartup
sed -i "s|DNS2|$Dns_2|g" /etc/deekaystartup

cat <<'deekayx' > /etc/systemd/system/deekaystartup.service
[Unit]
Description=Custom startup script
ConditionPathExists=/etc/deekaystartup
[Service]
Type=oneshot
ExecStart=/etc/deekaystartup
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
deekayx
chmod +x /etc/deekaystartup; systemctl enable deekaystartup

# BadVPN Binary
if [ "$(getconf LONG_BIT)" == "64" ]; then
 wget -q -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/jo6qznzwbsf1xhi/badvpn-udpgw64"
else
 wget -q -O /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/8gemt9c6k1fph26/badvpn-udpgw"
fi
chmod +x /usr/bin/badvpn-udpgw

cat <<'deekayb' > /etc/systemd/system/badvpn.service
[Unit]
Description=badvpn tun2socks service
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
[Install]
WantedBy=multi-user.target
deekayb
systemctl enable badvpn; systemctl start badvpn

# VNSTAT INITIALIZATION
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
vnstat -u -i "$IFACE" 2>/dev/null || true
systemctl enable vnstat
systemctl restart vnstat

# MENU CREATION - FULL AND UNCOMPRESSED
mkdir -p /usr/local/bin
cat > /usr/local/bin/menu <<'EOF_MENU'
#!/bin/bash

# Modern Color Palette
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

DOMAIN=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || curl -4 -s --max-time 2 ipv4.icanhazip.com)

HYST_CONFIG="/etc/hysteria/config.json"
HYST_USER_DB="/etc/hysteria/users.txt"
touch "$HYST_USER_DB" 2>/dev/null || true

# --- Utility Functions ---
server_ip() { curl -4 -s --max-time 2 ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}'; }
cpu_count() { nproc 2>/dev/null || echo "1"; }
mem_stats() { free -h 2>/dev/null | awk '/Mem:/ {print $2 "|" $7 "|" $3}'; }
ram_percent() { free 2>/dev/null | awk '/Mem:/ { if ($2>0) printf "%.1f%%", ($3/$2)*100; else print "0.0%" }'; }
cpu_percent() { top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)/ { gsub("%us","",$1); gsub(" ","",$1); split($1,a,":"); if (a[2] == "") print "0.0%"; else printf "%.1f%%", a[2]+0 }'; }
buffer_mem() { free -m 2>/dev/null | awk '/Mem:/ {print $6 "M"}'; }

server_status() {
  local ok=0
  for s in ssh stunnel4 squid nginx server-sldns hysteria-server ws-proxy@10080 xray; do
    systemctl is-active --quiet "$s" 2>/dev/null && ok=$((ok+1))
  done
  [ "$ok" -ge 4 ] && echo -e "${GREEN}EN LÍNEA${NC}" || echo -e "${RED}PROBLEMAS DETECTADOS${NC}"
}
pause_return() { echo; read -rp "Presiona ENTER para volver... " _; }

# --- HYSTERIA MANAGEMENT FUNCTIONS ---
add_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}CREAR USUARIO HYSTERIA${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    read -rp " Ingresa Contraseña/Cadena de Auth: " new_pass
    
    if grep -qw "^$new_pass" "$HYST_USER_DB" 2>/dev/null || jq -e ".inbounds[0].users[] | select(.auth_str == \"$new_pass\")" "$HYST_CONFIG" >/dev/null; then
        echo -e "\n${RED}Error: ¡El usuario/contraseña ya existe!${NC}"
        pause_return; return
    fi
    read -rp " Validez (Días): " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Número inválido.${NC}"; pause_return; return; fi
    exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
    
    jq ".inbounds[0].users += [{\"auth_str\": \"$new_pass\"}]" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
    echo "$new_pass $exp_date" >> "$HYST_USER_DB"
    systemctl restart hysteria-server
    
    OBFS_VAL=$(jq -r '.inbounds[0].obfs' "$HYST_CONFIG" 2>/dev/null || echo "HexTunnel")
    
    echo -e "\n${GREEN}✔ ¡Usuario creado exitosamente!${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    echo -e " ${BOLD}IP:${NC}          ${YELLOW}$(server_ip)${NC}"
    echo -e " ${BOLD}Dominio:${NC}      ${YELLOW}${DOMAIN:-$(server_ip)}${NC}"
    echo -e " ${BOLD}Rango de Puertos:${NC}  ${YELLOW}20000-50000 (-> 36712)${NC}"
    echo -e " ${BOLD}Usuario (Contraseña):${NC} ${YELLOW}${new_pass}${NC}"
    echo -e " ${BOLD}Obfs:${NC}        ${YELLOW}${OBFS_VAL}${NC}"
    echo -e " ${BOLD}Fecha de Expiración:${NC} ${YELLOW}${exp_date}${NC}"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    pause_return
}

del_hysteria() {
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}ELIMINAR USUARIO HYSTERIA${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB" ]; then echo -e "No se encontraron usuarios."; pause_return; return; fi
    cat -n "$HYST_USER_DB" | awk '{print " ["$1"] User: "$2" | Exp: "$3}'
    echo ""
    read -rp " Ingresa el número de ID del usuario a eliminar: " del_id
    if ! [[ "$del_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID inválido.${NC}"; pause_return; return; fi

    del_pass=$(sed -n "${del_id}p" "$HYST_USER_DB" | awk '{print $1}')
    if [ -z "$del_pass" ]; then echo -e "${RED}ID no encontrado.${NC}"; pause_return; return; fi

    jq ".inbounds[0].users |= map(select(.auth_str != \"$del_pass\"))" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
    sed -i "${del_id}d" "$HYST_USER_DB"
    systemctl restart hysteria-server
    echo -e "\n${GREEN}✔ ¡Usuario '$del_pass' eliminado exitosamente!${NC}"
    pause_return
}

extend_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}EXTENDER USUARIO HYSTERIA${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB" ]; then echo -e "No se encontraron usuarios."; pause_return; return; fi

    cat -n "$HYST_USER_DB" | awk '{print " ["$1"] User: "$2" | Exp: "$3}'
    echo ""
    read -rp " Ingresa el número de ID del usuario a extender: " ext_id
    if ! [[ "$ext_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID inválido.${NC}"; pause_return; return; fi
    
    ext_pass=$(sed -n "${ext_id}p" "$HYST_USER_DB" | awk '{print $1}')
    current_exp=$(sed -n "${ext_id}p" "$HYST_USER_DB" | awk '{print $2}')
    if [ -z "$ext_pass" ]; then echo -e "${RED}ID no encontrado.${NC}"; pause_return; return; fi
    
    read -rp " Días a Agregar: " days
    if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Número inválido.${NC}"; pause_return; return; fi
    
    new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
    sed -i "${ext_id}s/.*/$ext_pass $new_exp/" "$HYST_USER_DB"
    
    echo -e "\n${GREEN}✔ ¡Usuario '$ext_pass' extendido exitosamente!${NC}\n Nueva Expiración: ${YELLOW}$new_exp${NC}"
    pause_return
}

list_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}LISTA DE USUARIOS HYSTERIA${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    if [ ! -s "$HYST_USER_DB" ]; then echo -e "\n No se encontraron usuarios activos.\n"
    else
        printf " %-5s | %-25s | %-15s\n" "ID" "PASSWORD (AUTH STRING)" "EXPIRY DATE"
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        cat -n "$HYST_USER_DB" | while read -r num user exp; do
            printf " [%-3s] | %-25s | %-15s\n" "$num" "$user" "$exp"
        done
        echo -e "${CYAN}--------------------------------------------------------------${NC}"
        echo -e " Total de Usuarios Activos: ${YELLOW}$(wc -l < "$HYST_USER_DB")${NC}"
    fi
    pause_return
}

speed_hysteria() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}EDITAR VELOCIDADES SUBIDA/BAJADA${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    current_up=$(jq -r '.inbounds[0].up_mbps' "$HYST_CONFIG" 2>/dev/null || echo "100")
    current_down=$(jq -r '.inbounds[0].down_mbps' "$HYST_CONFIG" 2>/dev/null || echo "100")
    echo -e " Subida Actual:    ${YELLOW}${current_up} Mbps${NC}"
    echo -e " Bajada Actual:    ${YELLOW}${current_down} Mbps${NC}\n"
    read -rp " Ingresa Nueva Velocidad de Subida (Mbps): " new_up
    read -rp " Ingresa Nueva Velocidad de Bajada (Mbps): " new_down
    if [[ "$new_up" =~ ^[0-9]+$ ]] && [[ "$new_down" =~ ^[0-9]+$ ]]; then
        jq ".inbounds[0].up_mbps = $new_up | .inbounds[0].down_mbps = $new_down" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
        systemctl restart hysteria-server
        echo -e "\n${GREEN}✔ ¡Velocidades actualizadas exitosamente!${NC}"
    else echo -e "\n${RED}Entrada inválida. Solo números.${NC}"; fi
    pause_return
}

# --- XRAY MANAGEMENT FUNCTIONS ---
add_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}CREAR CUENTA XRAY${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e " [1] VLESS (TLS y NTLS)"
  echo -e " [2] VMESS (TLS y NTLS)"
  echo -e " [3] TROJAN (TLS)"
  echo -e " [4] TODO-EN-UNO (VLESS + VMESS + TROJAN)"
  read -rp " Selecciona Protocolo: " prot
  read -rp " Nombre de usuario: " user
  
  if grep -qw "^$user" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null; then
    echo -e "${RED}¡El nombre de usuario ya existe!${NC}"; pause_return; return
  fi

  read -rp " Validez (Días): " masa
  exp=$(date -d "+${masa} days" +"%Y-%m-%d")

  read -rp " ¿Quieres usar un UUID personalizado? (y/N): " custom_uuid_prompt
  if [[ "$custom_uuid_prompt" =~ ^[Yy]$ ]]; then
    read -rp " Ingresa el UUID personalizado: " uuid
  else
    uuid=$(cat /proc/sys/kernel/random/uuid)
  fi

  pass="HexTunnel${uuid:0:6}"
  
  if [ "$prot" == "1" ]; then
    jq ".inbounds[0].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    jq ".inbounds[3].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    jq ".inbounds[4].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $uuid $exp" >> /etc/xray/vless.txt
    
    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}CUENTA VLESS CREADA${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "Usuario  : $user\nExpira   : $exp"
    echo -e "\n${YELLOW}TLS (443):${NC}\nvless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}"
    echo -e "\n${YELLOW}NTLS (80/8080/8880):${NC}\nvless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  
  elif [ "$prot" == "2" ]; then
    jq ".inbounds[1].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    jq ".inbounds[5].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $uuid $exp" >> /etc/xray/vmess.txt
    
    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}CUENTA VMESS CREADA${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "Usuario: $user\nExpira: $exp"
    VMESS_TLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    echo -e "\n${YELLOW}TLS (443):${NC}\nvmess://$(echo -n "$VMESS_TLS_JSON" | base64 -w 0)"
    VMESS_NTLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
    echo -e "\n${YELLOW}NTLS (80/8080/8880):${NC}\nvmess://$(echo -n "$VMESS_NTLS_JSON" | base64 -w 0)"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  
  elif [ "$prot" == "3" ]; then
    jq ".inbounds[2].settings.clients += [{\"password\": \"$pass\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    echo "$user $pass $exp" >> /etc/xray/trojan.txt
    
    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}CUENTA TROJAN CREADA${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "Usuario: $user\nContraseña: $pass\nExpira: $exp"
    echo -e "\n${YELLOW}TLS (443):${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"

  elif [ "$prot" == "4" ]; then
    jq ".inbounds[0].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}] | .inbounds[3].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}] | .inbounds[4].settings.clients += [{\"id\": \"$uuid\", \"email\": \"$user\"}] | .inbounds[1].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}] | .inbounds[5].settings.clients += [{\"id\": \"$uuid\", \"alterId\": 0, \"email\": \"$user\"}] | .inbounds[2].settings.clients += [{\"password\": \"$pass\", \"email\": \"$user\"}]" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
    
    echo "$user $uuid $exp" >> /etc/xray/vless.txt
    echo "$user $uuid $exp" >> /etc/xray/vmess.txt
    echo "$user $pass $exp" >> /etc/xray/trojan.txt

    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "               ${BOLD}CUENTA TODO-EN-UNO CREADA${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "Usuario: $user\nExpira:   $exp"
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
    
    echo -e "\n${YELLOW}[ VLESS TLS (443) ]${NC}\nvless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}"
    echo -e "\n${YELLOW}[ VLESS NTLS (80) ]${NC}\nvless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}"
    
    VMESS_TLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    echo -e "\n${YELLOW}[ VMESS TLS (443) ]${NC}\nvmess://$(echo -n "$VMESS_TLS_JSON" | base64 -w 0)"
    
    VMESS_NTLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
    echo -e "\n${YELLOW}[ VMESS NTLS (80) ]${NC}\nvmess://$(echo -n "$VMESS_NTLS_JSON" | base64 -w 0)"

    echo -e "\n${YELLOW}[ TROJAN TLS (443) ]${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  fi
  systemctl restart xray
  pause_return
}

del_xray() {
  clear
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}ELIMINAR CUENTA XRAY${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  
  mapfile -t users < <(cat /etc/xray/*.txt 2>/dev/null | awk '{print $1}' | sort -u)
  
  if [ ${#users[@]} -eq 0 ]; then 
      echo -e "${YELLOW}No se encontraron usuarios de Xray.${NC}"; pause_return; return
  fi
  for i in "${!users[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "${users[$i]}"; done
  echo -e "\n  [${YELLOW}00${NC}] Cancelar\n"

  read -rp "  Selecciona usuario a eliminar: " idx
  if [[ "$idx" == "00" || "$idx" == "0" ]]; then return; fi
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -le 0 ] || [ "$idx" -gt "${#users[@]}" ]; then 
      echo -e "${RED}Selección inválida.${NC}"; pause_return; return 
  fi

  user="${users[$((idx-1))]}"
  jq "(.inbounds[].settings.clients) |= map(select(.email != \"$user\"))" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
  sed -i "/^$user /d" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null
  systemctl restart xray
  echo -e "\n${GREEN}✔ Usuario $user eliminado exitosamente.${NC}"
  pause_return
}

renew_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}RENOVAR CUENTA XRAY${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp " Usuario a renovar: " user
  
  if ! grep -qw "^$user" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null; then 
    echo -e "${RED}Usuario no encontrado.${NC}"; pause_return; return
  fi
  read -rp " Días a Agregar: " days
  for proto in vless vmess trojan; do 
    if grep -qw "^$user" "/etc/xray/${proto}.txt"; then
      current_exp=$(grep -w "^$user" "/etc/xray/${proto}.txt" | awk '{print $3}')
      new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
      sed -i "s/^$user .* $current_exp/$(grep -w "^$user" "/etc/xray/${proto}.txt" | awk '{print $1 " " $2}') $new_exp/" "/etc/xray/${proto}.txt"
    fi
  done
  echo -e "\n${GREEN}✔ Usuario '$user' renovado exitosamente.${NC}\nNueva Expiración: $new_exp"
  pause_return
}

show_xray() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}MOSTRAR ENLACES DE CONFIG XRAY${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp " Usuario a ver: " user
  local found=0
  if grep -qw "^$user" /etc/xray/vless.txt; then
    uuid=$(grep -w "^$user" /etc/xray/vless.txt | awk '{print $2}')
    echo -e "${YELLOW}VLESS TLS (443):${NC}\nvless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}"
    echo -e "\n${YELLOW}VLESS NTLS (80):${NC}\nvless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}\n"
    found=1
  fi
  if grep -qw "^$user" /etc/xray/vmess.txt; then
    uuid=$(grep -w "^$user" /etc/xray/vmess.txt | awk '{print $2}')
    VMESS_TLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    echo -e "${YELLOW}VMESS TLS (443):${NC}\nvmess://$(echo -n "$VMESS_TLS_JSON" | base64 -w 0)"
    VMESS_NTLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
    echo -e "\n${YELLOW}VMESS NTLS (80):${NC}\nvmess://$(echo -n "$VMESS_NTLS_JSON" | base64 -w 0)\n"
    found=1
  fi
  if grep -qw "^$user" /etc/xray/trojan.txt; then
    pass=$(grep -w "^$user" /etc/xray/trojan.txt | awk '{print $2}')
    echo -e "${YELLOW}TROJAN TLS (443):${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}&allowInsecure=1#${user}\n"
    found=1
  fi
  if [ "$found" -eq 0 ]; then echo -e "${RED}Usuario no encontrado en ningún protocolo.${NC}"; fi
  pause_return
}

# --- SSH USER FUNCTIONS ---
list_real_users() { awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "systemd-network" && $1 != "messagebus" {print $1}' /etc/passwd 2>/dev/null; }

select_user() {
  local purpose="$1"
  mapfile -t USERS < <(list_real_users)
  if [ "${#USERS[@]}" -eq 0 ]; then echo -e "${RED}No se encontraron cuentas de usuario activas.${NC}"; return 1; fi
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  printf " %-56s \n" "${BOLD}$purpose${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  for i in "${!USERS[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "${USERS[$i]}"; done
  echo -e "\n  [${YELLOW}00${NC}] Atrás\n"
  read -rp "  Selecciona un número de cuenta: " idx
  [[ "$idx" == "00" || "$idx" == "0" ]] && return 1
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#USERS[@]}" ]; then echo -e "${RED}  Selección inválida.${NC}"; return 1; fi
  SELECTED_USER="${USERS[$((idx-1))]}"
  return 0
}

create_user() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}CREAR NUEVO USUARIO SSH${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  read -rp "  Nombre de usuario: " user
  read -rp "  Contraseña: " pass
  read -rp "  Válido por (días): " days

  if [ -z "$user" ] || [ -z "$pass" ] || [ -z "$days" ]; then echo -e "\n${RED}  Error: Todos los campos son obligatorios.${NC}"; pause_return; return; fi
  if id "$user" >/dev/null 2>&1; then echo -e "\n${RED}  Error: El usuario '$user' ya existe.${NC}"; pause_return; return; fi

  useradd -e "$(date -d "+$days days" +%Y-%m-%d)" -s /bin/false -M "$user" && echo "$user:$pass" | chpasswd

  IP=$(curl -s ipv4.icanhazip.com)
  CURRENT_NS=$(grep 'ExecStart=' /etc/systemd/system/server-sldns.service 2>/dev/null | sed 's/.*server\.key \([^ ]*\) .*/\1/')

  clear
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}CUENTA CREADA EXITOSAMENTE${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${BOLD}Dominio/Host${NC}: ${YELLOW}$DOMAIN${NC}"
  echo -e "  ${BOLD}Dirección IP${NC} : ${YELLOW}$IP${NC}"
  echo -e "  ${BOLD}Usuario${NC}   : ${YELLOW}$user${NC}"
  echo -e "  ${BOLD}Contraseña${NC}   : ${YELLOW}$pass${NC}"
  echo -e "  ${BOLD}Expiración${NC}     : ${YELLOW}$(date -d "+$days days" +%Y-%m-%d)${NC}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  SSH Port   : 22, 299"
  echo -e "  SSL/TLS    : 443"
  echo -e "  SSL/WS     : 443"
  echo -e "  WebSocket  : 80, 8080, 8880, 2082, 2086, 25"
  echo -e "  SlowDNS    : 53"
  echo -e "  BadVPN     : 7300"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  ${BOLD}Payload HTTP     :${NC}"
  echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo -e ""
  echo -e "  ${BOLD}Payload Mejorado :${NC}"
  echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: bug.com[crlf][crlf]PATCH / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
  echo -e "${CYAN}--------------------------------------------------------------${NC}"
  echo -e "  ${BOLD}SlowDNS NS ${NC}: ${YELLOW}${CURRENT_NS:-No configurado}${NC}"
  echo -e "  ${BOLD}DNS PUB KEY${NC}: 7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  pause_return
}

delete_user() {
  if ! select_user "DELETE SSH USER"; then pause_return; return; fi
  clear; echo -e "${RED}Advertencia: Estás a punto de eliminar al usuario: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "¿Estás seguro? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    # Force kill all processes owned by the user to free up the account
    pkill -u "$SELECTED_USER" 2>/dev/null
    
    # Execute forced deletion
    if userdel -r -f "$SELECTED_USER" 2>/dev/null || userdel -f "$SELECTED_USER" 2>/dev/null; then
        echo -e "${GREEN}El usuario $SELECTED_USER ha sido eliminado.${NC}"
    else
        echo -e "${RED}Fallo al eliminar $SELECTED_USER. Revisa archivos bloqueados.${NC}"
    fi
  fi
  pause_return
}

extend_user() {
  if ! select_user "EXTEND USER EXPIRY"; then pause_return; return; fi
  clear; echo -e "Extendiendo cuenta de: ${YELLOW}$SELECTED_USER${NC}"
  read -rp "Ingresa número de días a agregar: " days
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Formato de número inválido.${NC}"; pause_return; return; fi
  current=$(chage -l "$SELECTED_USER" 2>/dev/null | awk -F": " '/Account expires/ {print $2}')
  if [ "$current" = "never" ] || [ -z "$current" ]; then new_exp=$(date -d "+$days days" +%Y-%m-%d)
  else new_exp=$(date -d "$current +$days days" +%Y-%m-%d); fi
  chage -E "$new_exp" "$SELECTED_USER"
  echo -e "${GREEN}¡Éxito!${NC} Cuenta extendida.\nNueva Fecha de Expiración: ${YELLOW}$new_exp${NC}"
  pause_return
}

# --- Monitor ---
online_users() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "               ${BOLD}MONITOR DE SESIONES ACTIVAS${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"

  echo -e "${YELLOW}--- SSH LEGADO ---${NC}"
  declare -A active_ssh
  mapfile -t USERS < <(awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "systemd-network" && $1 != "messagebus" {print $1}' /etc/passwd 2>/dev/null)
  
  for user in "${USERS[@]}"; do
      ssh_count=$(ps -u "$user" 2>/dev/null | grep -c "sshd")
      total=$ssh_count
      if [ "$total" -gt 0 ]; then active_ssh["$user"]=$total; fi
  done

  if [ "${#active_ssh[@]}" -eq 0 ]; then 
      echo -e "  No hay usuarios de SSH legado autenticados en línea actualmente.\n"
  else
    printf "  %-25s %-15s\n" "USERNAME" "ACTIVE SESSIONS"
    echo -e "${CYAN}  ----------------------------------------------------------${NC}"
    for user in "${!active_ssh[@]}"; do 
        if [ "${active_ssh[$user]}" -gt 1 ]; then
            printf "  %-25s ${RED}%-15s (Multi-Login)${NC}\n" "$user" "${active_ssh[$user]}"
        else
            printf "  %-25s ${GREEN}%-15s${NC}\n" "$user" "${active_ssh[$user]}"
        fi
    done | sort
    echo
  fi

  echo -e "${YELLOW}--- INICIOS DE SESIÓN ACTIVOS XRAY CORE (IPs Únicas Recientes) ---${NC}"
  if grep -q '"loglevel": "warning"' /etc/xray/config.json 2>/dev/null; then
      sed -i 's/"loglevel": "warning"/"loglevel": "info"/g' /etc/xray/config.json
      systemctl restart xray 2>/dev/null
      echo -e "  [Nota del Sistema] Registro de Xray habilitado. Reconecta a los usuarios para ver los logs.\n"
  elif [ -f /var/log/xray/access.log ]; then
      active_xray=$(tail -n 10000 /var/log/xray/access.log 2>/dev/null | grep "accepted" | awk '{ user=""; for(i=1;i<=NF;i++) if($i=="email:") user=$(i+1); if(user!="") { split($3, a, ":"); print user " " a[1] } }' | sort -u | awk '{print $1}' | uniq -c | sort -nr)
      if [ -z "$active_xray" ]; then 
          echo -e "  No se encontraron usuarios activos de Xray en los logs recientes.\n"
      else
          printf "  %-15s %-25s\n" "UNIQUE IPs" "USERNAME"
          echo -e "${CYAN}  ----------------------------------------------------------${NC}"
          while read -r count username; do 
              if [ -n "$username" ]; then 
                  if [ "$count" -gt 1 ]; then
                      printf "  ${RED}%-15s${NC} %-25s ${RED}(Multi-IP)${NC}\n" "$count" "$username"
                  else
                      printf "  %-15s %-25s\n" "$count" "$username"
                  fi
              fi
          done <<< "$active_xray"
      fi
  else echo -e "  Log de acceso de Xray no encontrado.\n"; fi
  
  pause_return
}

# --- Service Controls ---
restart_service() {
  local service_name="$1"
  local display_name="$2"
  echo -e "Reiniciando ${display_name}..."
  systemctl restart $service_name 2>/dev/null || true
  echo -e "${GREEN}✔ ${display_name} reiniciado.${NC}"
}

service_control_menu() {
  while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}CONTROL DE SERVICIOS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}01${NC}] Reiniciar Todos Los Servicios"
    echo -e "  [${YELLOW}02${NC}] Reiniciar SSH"
    echo -e "  [${YELLOW}03${NC}] Reiniciar Proxies WebSocket de Node"
    echo -e "  [${YELLOW}04${NC}] Reiniciar Stunnel y Xray Core"
    echo -e "  [${YELLOW}05${NC}] Reiniciar Squid Proxy y Nginx"
    echo -e "  [${YELLOW}06${NC}] Reiniciar Núcleo UDP (SlowDNS / Hysteria / BadVPN)"
    echo -e "  [${YELLOW}00${NC}] Atrás\n"
    read -rp "  Selecciona una opción: " opt
    case "$opt" in
      1|01) restart_service "ssh stunnel4 sslh squid nginx server-sldns hysteria-server badvpn ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086 xray" "All Services"; pause_return ;;
      2|02) restart_service "ssh" "SSH"; pause_return ;;
      3|03) restart_service "ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086" "Node WebSocket Proxies"; pause_return ;;
      4|04) restart_service "stunnel4 xray" "Stunnel & Xray Core"; pause_return ;;
      5|05) restart_service "squid nginx" "Squid Proxy & Nginx"; pause_return ;;
      6|06) restart_service "server-sldns hysteria-server badvpn" "UDP Core Services"; pause_return ;;
      0|00) break ;;
      *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
    esac
  done
}

# --- Backup & Restore ---
backup_snapshot() {
  clear; local out="/root/hextunnel_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
  echo -e "Empaquetando configuraciones del servidor..."
  tar -czf "$out" /etc/ssh /etc/stunnel /etc/squid /etc/hysteria /etc/deekayvpn /etc/systemd/system/ws-proxy@.service /etc/xray 2>/dev/null
  echo -e "\n${GREEN}✔ ¡Respaldo creado exitosamente!${NC}\nUbicación: ${YELLOW}$out${NC}"
  pause_return
}

restore_snapshot() {
  clear
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                   ${BOLD}RESTAURAR CONFIGURACIÓN${NC}"
  echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
  shopt -s nullglob
  backups=(/root/hextunnel_backup_*.tar.gz)
  if [ ${#backups[@]} -eq 0 ]; then echo -e "${RED}  No se encontraron archivos de respaldo en /root/.${NC}"; pause_return; return; fi
  echo -e "  Respaldos Disponibles:\n"
  for i in "${!backups[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "$(basename "${backups[$i]}")"; done
  echo -e "\n  [${YELLOW}00${NC}] Cancelar\n"
  read -rp "  Selecciona respaldo a restaurar: " sel
  if [[ "$sel" == "00" || "$sel" == "0" ]]; then return; fi
  idx=$((sel-1))
  if [ -n "${backups[$idx]}" ]; then
    echo -e "\nRestaurando ${YELLOW}$(basename "${backups[$idx]}")${NC}..."
    tar -xzf "${backups[$idx]}" -C /
    systemctl daemon-reload; systemctl restart ssh stunnel4 sslh squid nginx server-sldns hysteria-server badvpn ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086 xray 2>/dev/null || true
    echo -e "${GREEN}✔ ¡Restauración completa!${NC}"
  else echo -e "${RED}Selección inválida.${NC}"; fi
  pause_return
}

# --- System Utilities ---
utilities_menu() {
  while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                   ${BOLD}UTILIDADES DEL SISTEMA${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}1${NC}] Activar BBR Nativo del Kernel (Rápido y Silencioso)"
    echo -e "  [${YELLOW}2${NC}] Verificar Desbloqueos de Netflix y Streaming (Inglés)"
    echo -e "  [${YELLOW}0${NC}] Atrás\n"
    read -rp "  Selecciona una opción: " subopt
    case "$subopt" in 
      1) 
         echo -e "\nActivando BBR Nativo del Kernel..."
         sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
         sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
         echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
         echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
         sysctl -p >/dev/null 2>&1
         if [[ "$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null)" == *"bbr"* ]]; then echo -e "${GREEN}✔ ¡BBR Activado Exitosamente!${NC}"
         else echo -e "${RED}✖ Fallo al activar BBR (puede que el kernel no lo soporte).${NC}"; fi
         pause_return
         ;; 
      2) 
         clear
         echo -e "${YELLOW}Ejecutando Verificación de Restricción Regional (Inglés)...${NC}\n"
         bash <(curl -sL https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) -E en
         echo ""
         pause_return 
         ;;
      0) break ;;
      *) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
    esac
  done
}

# --- Domain & DNS Management ---
change_domain() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                 ${BOLD}CAMBIAR DOMINIO DEL SERVIDOR${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    current_dom=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || echo "No configurado")
    echo -e " Dominio/IP Actual: ${YELLOW}$current_dom${NC}\n"
    read -rp " Ingresa Nuevo Dominio o IP: " new_dom
    if [ -n "$new_dom" ]; then
        echo "$new_dom" > /etc/deekayvpn/domain.txt; DOMAIN="$new_dom"
        echo -e "\n${GREEN}✔ Dominio actualizado exitosamente a: $new_dom${NC}"
    else echo -e "\n${RED}Acción cancelada.${NC}"; fi
    pause_return
}

change_slowdns() {
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "               ${BOLD}CAMBIAR NAMESERVER DE SLOWDNS${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    svc_file="/etc/systemd/system/server-sldns.service"
    if [ ! -f "$svc_file" ]; then echo -e "${RED}Archivo de servicio SlowDNS no encontrado.${NC}"; pause_return; return; fi
    current_ns=$(grep 'ExecStart=' "$svc_file" | sed 's/.*server\.key \([^ ]*\) .*/\1/')
    echo -e " Nameserver Actual: ${YELLOW}$current_ns${NC}\n"
    read -rp " Ingresa Nuevo Nameserver (ej. ns1.dominio.com): " new_ns
    if [ -n "$new_ns" ] && [ "$new_ns" != "$current_ns" ]; then
        sed -i "s/$current_ns/$new_ns/g" "$svc_file"
        systemctl daemon-reload; systemctl restart server-sldns
        echo -e "\n${GREEN}✔ Nameserver de SlowDNS actualizado a: $new_ns${NC}"
    else echo -e "\n${RED}Acción cancelada o se ingresó el mismo NS.${NC}"; fi
    pause_return
}

# --- Advanced / Danger Zone ---
advanced_menu() {
  while true; do
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "                     ${BOLD}CONFIGURACIÓN AVANZADA${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
    echo -e "  [${YELLOW}01${NC}] Ver JSON Crudo de Hysteria"
    echo -e "  [${YELLOW}02${NC}] Ver Logs de Acciones de Servicios (Journalctl)"
    echo -e "  [${YELLOW}03${NC}] Cambiar Dominio/IP del Servidor"
    echo -e "  [${YELLOW}04${NC}] Cambiar Nameserver de SlowDNS (NS)"
    echo -e "  [${RED}05${NC}] Desinstalar Script Completo (Peligro)"
    echo -e "  [${YELLOW}00${NC}] Atrás\n"
    read -rp "  Selecciona una opción: " opt
    case "$opt" in
      1|01) clear; cat /etc/hysteria/config.json 2>/dev/null || echo "No encontrado."; pause_return ;;
    2|02) 
        clear; echo -e "[1] SSH  [2] WS-Proxies  [3] Hysteria  [4] Stunnel  [5] SlowDNS  [6] Xray\n"
        read -rp "Selecciona log: " lopt
        case "$lopt" in
          1) journalctl -u ssh -n 50 --no-pager ;;
          2) journalctl -u ws-proxy@10080 -n 50 --no-pager ;;
          3) journalctl -u hysteria-server -n 50 --no-pager ;;
          4) journalctl -u stunnel4 -n 50 --no-pager ;;
          5) journalctl -u server-sldns -n 50 --no-pager ;;
          6) journalctl -u xray -n 50 --no-pager ;;
        esac; pause_return ;;
      3|03) change_domain ;;
      4|04) change_slowdns ;;
      5|05) remove_script ;;
      0|00) break ;;
    esac
  done
}

remove_script() {
  clear
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  echo -e "                     ${BOLD}DESINSTALACIÓN COMPLETA${NC}"
  echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
  read -rp "  ¿Estás completamente seguro? [y/N]: " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
      echo -e "\nDeteniendo servicios..."
      systemctl stop ws-proxy@* server-sldns badvpn hysteria-server sslh stunnel4 squid nginx xray 2>/dev/null || true
      systemctl disable ws-proxy@* server-sldns badvpn hysteria-server xray 2>/dev/null || true
      echo "Eliminando archivos..."
      rm -f /etc/systemd/system/ws-proxy@.service /etc/systemd/system/server-sldns.service /etc/systemd/system/badvpn.service /etc/systemd/system/xray.service
      rm -f /etc/cron.d/service-checker /etc/cron.d/logrotate /etc/cron.d/xray-expiry /etc/cron.d/hysteria-expiry /etc/sysctl.d/99-freenet-tuning.conf /etc/security/limits.d/99-freenet.conf
      rm -rf /etc/deekayvpn /etc/slowdns /etc/socksproxy /etc/xray /etc/hysteria /usr/local/bin/menu /usr/bin/menu /usr/bin/Menu
      systemctl daemon-reload; sysctl --system >/dev/null 2>&1 || true
      echo -e "${GREEN}✔ Eliminación completa.${NC}"
  else echo "Cancelado."; fi
  pause_return
}

# --- Main Dashboard ---
draw_header() {
  local os_name=$(. /etc/os-release 2>/dev/null; echo "${ID:-UNKNOWN}" | tr '[:lower:]' '[:upper:]')
  local os_ver=$(. /etc/os-release 2>/dev/null; echo "${VERSION_ID:-}")
  local os="${os_name} ${os_ver}"
  local arch=$(uname -m)
  local cores=$(cpu_count)
  local ip=$(server_ip)
  local time=$(date '+%H:%M %Z')
  local status=$(server_status)
  local ram=$(ram_percent)
  local cpu=$(cpu_percent)
  local buf=$(buffer_mem)

  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}       >>>>>  🐉  ${YELLOW}${BOLD}Hex Tunnel${NC}${BLUE}  ✸  ${YELLOW}${BOLD}Por JotchuaDevz${NC}${BLUE}  🐉  <<<<<${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-17s${NC} ${WHITE}%-6s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-7s${NC} ${YELLOW}%s${NC}\n" "OS:" "$os" "Arch:" "$arch" "Cores:" "$cores"
  printf "  ${WHITE}%-5s${NC} ${YELLOW}%-17s${NC} ${WHITE}%-6s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-7s${NC} %s\n" "IP:" "$ip" "Time:" "$time" "Status:" "$status"
  echo -e "${CYAN}------------------------ ${BOLD}Puertos Abiertos${NC} ${CYAN}------------------------${NC}"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SSH:" "22, 299" "System-DNS:" "53"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "WEB-Nginx:" "85" "SSL:" "443"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SSL/PYTHON:" "443"  "Squid:" "3128, 8000"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "WS/PYTHON:" "80, 8080, 8880" "BadVPN:" "7300"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "WS/PYTHON:" "2082, 2086, 25" "XRAY NTLS:" "80, 8080, 8880"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "XRAY TLS:" "443" "HysteriaUDP:" "20000-50000"
  printf "  ${WHITE}• %-12s${NC} ${GREEN}%-22s${NC} ${WHITE}• %-13s${NC} ${GREEN}%s${NC}\n" "SlowDNS:" "53" "" ""
  echo -e "${CYAN}----------------------- ${BOLD}Recursos Del Sistema${NC} ${CYAN}-----------------------${NC}"
  printf "  ${WHITE}%-10s${NC} ${YELLOW}%-14s${NC} ${WHITE}%-10s${NC} ${YELLOW}%-10s${NC} ${WHITE}%-8s${NC} ${YELLOW}%s${NC}\n" "RAM Usada:" "$ram" "CPU Usada:" "$cpu" "Buffer:" "$buf"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
}

while true; do
  clear; draw_header; echo
  echo -e "  [${YELLOW}01${NC}] Gestión de Cuentas SSH (Legado)"
  echo -e "  [${YELLOW}02${NC}] Gestión de Cuentas Xray (V2ray)"
  echo -e "  [${YELLOW}03${NC}] Gestión de Cuentas Hysteria (UDP)"
  echo -e "  [${YELLOW}04${NC}] Monitorear Conexiones Activas"
  echo -e "  [${YELLOW}05${NC}] Control de Servicios (Reiniciar Protocolos)"
  echo -e "  [${YELLOW}06${NC}] Respaldar y Restaurar Datos"
  echo -e "  [${YELLOW}07${NC}] Utilidades del Sistema (BBR y Netflix)"
  echo -e "  [${YELLOW}08${NC}] Configuración Avanzada (Dominio / Nameserver)"
  echo -e "  [${YELLOW}09${NC}] Reiniciar Servidor"
  echo -e "  [${RED}00${NC}] Salir\n"
  read -rp "  ► Selecciona una opción: " opt
  case "$opt" in
    1|01) 
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}GESTIÓN DE CUENTAS SSH${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Crear Usuario SSH\n  [${YELLOW}2${NC}] Extender Expiración\n  [${YELLOW}3${NC}] Eliminar Usuario SSH\n  [${YELLOW}4${NC}] Listar Todas Las Cuentas\n  [${YELLOW}0${NC}] Atrás\n"
        read -rp "  ► Opción: " sub; case "$sub" in 1) create_user;; 2) extend_user;; 3) delete_user;; 4) list_real_users | nl -w2 -s'. '; pause_return;; 0) break;; esac
      done ;;
    2|02) 
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}GESTIÓN DE CUENTAS XRAY${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Agregar Cuenta Xray\n  [${YELLOW}2${NC}] Renovar Cuenta Xray\n  [${YELLOW}3${NC}] Eliminar Cuenta Xray\n  [${YELLOW}4${NC}] Mostrar Enlaces de Config\n  [${YELLOW}5${NC}] Forzar Eliminación de Usuarios Xray Expirados\n  [${YELLOW}6${NC}] Actualizar Versión de Xray Core\n  [${YELLOW}0${NC}] Atrás\n"
        read -rp "  ► Opción: " sub; case "$sub" in 1) add_xray;; 2) renew_xray;; 3) del_xray;; 4) show_xray;; 5) /usr/local/bin/exp-check; echo "Usuarios Xray expirados eliminados."; pause_return;; 6) systemctl stop xray; XRAY_VER="v26.5.9"; echo "Reinstalando Xray Core ${XRAY_VER}..."; wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-64.zip"; unzip -q -o /tmp/xray.zip -d /tmp/xray/ && mv -f /tmp/xray/xray /usr/local/bin/xray; systemctl start xray; echo -e "${GREEN}✔ ¡Xray Restaurado a ${XRAY_VER}!${NC}"; pause_return;; 0) break;; esac
      done ;;
    3|03)
      while true; do
        clear; echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n                   ${BOLD}GESTIÓN DE CUENTAS HYSTERIA${NC}\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
        echo -e "  [${YELLOW}1${NC}] Agregar Cuenta Hysteria\n  [${YELLOW}2${NC}] Renovar Cuenta Hysteria\n  [${YELLOW}3${NC}] Eliminar Cuenta Hysteria\n  [${YELLOW}4${NC}] Listar Todas Las Cuentas\n  [${YELLOW}5${NC}] Editar Velocidades Subida/Bajada\n  [${YELLOW}0${NC}] Atrás\n"
        read -rp "  ► Opción: " sub; case "$sub" in 1) add_hysteria;; 2) extend_hysteria;; 3) del_hysteria;; 4) list_hysteria;; 5) speed_hysteria;; 0) break;; esac
      done ;;
    4|04) online_users ;;
    5|05) service_control_menu ;;
    6|06)
      clear; echo -e "  [1] Respaldar Configuraciones del Sistema\n  [2] Restaurar Desde Respaldo\n  [0] Atrás"
      read -rp " Selecciona: " subopt; case "$subopt" in 1) backup_snapshot;; 2) restore_snapshot;; esac ;;
    7|07) utilities_menu ;;
    8|08) advanced_menu ;;
    9|09) clear; read -rp "¿Reiniciar el servidor ahora? [y/N]: " ans; [[ "$ans" =~ ^[Yy]$ ]] && reboot ;;
    0|00) clear; exit 0 ;;
  esac
done
EOF_MENU

sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /usr/local/bin/menu
chmod +x /usr/local/bin/menu
cp /usr/local/bin/menu /usr/bin/menu
cp /usr/local/bin/menu /usr/bin/Menu

# Finishing
chown -R www-data:www-data /home/vps/public_html
clear
figlet Hex Tunnel Script By JotchuaDevz -c | lolcat
echo "       ¡Instalación Completa! El sistema necesita reiniciarse para aplicar todos los cambios! "
history -c; rm /root/full.sh 2>/dev/null || true
echo "           ¡El servidor se reiniciará en 10 segundos! "
sleep 10
reboot
