#!/bin/bash

set -o pipefail
clear
export DEBIAN_FRONTEND=noninteractive
source /etc/os-release
SUPPORT_LEVEL="unsupported"
case "$ID:$VERSION_ID" in
ubuntu:20.04) SUPPORT_LEVEL="legacy" ;;
ubuntu:22.04) SUPPORT_LEVEL="recommended" ;;
ubuntu:24.04) SUPPORT_LEVEL="supported" ;;
ubuntu:26.04) SUPPORT_LEVEL="supported" ;;
debian:11) SUPPORT_LEVEL="legacy" ;;
debian:12) SUPPORT_LEVEL="supported" ;;
*) SUPPORT_LEVEL="unsupported" ;;
esac
REINICIAR_AL_FINAL="no"
INICIO_INSTALACION=$(date +%s)
LOG_INSTALACION="/var/log/hex-instalacion.log"
CACHE_DESCARGAS="/tmp/hex-cache"
mkdir -p "$CACHE_DESCARGAS" >/dev/null 2>&1
: > "$LOG_INSTALACION" 2>/dev/null || LOG_INSTALACION="/dev/null"
XRAY_VER="v26.3.27"
HYSTERIA2_VER="app/v2.9.3"
SINGBOX_VER="1.12.22"
WEBMIN_VER="2.111"
mkdir -p /etc/dpkg/dpkg.cfg.d >/dev/null 2>&1
cat > /etc/dpkg/dpkg.cfg.d/01-hex-rapido <<'EOF_DPKG'
path-exclude=/usr/share/doc/*
path-include=/usr/share/doc/*/copyright
path-exclude=/usr/share/man/*
path-exclude=/usr/share/groff/*
path-exclude=/usr/share/info/*
EOF_DPKG
APT_OPC=(-y -o Dpkg::Use-Pty=0 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
RED='\033[38;5;203m'
GREEN='\033[38;5;84m'
YELLOW='\033[38;5;221m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
MAGENTA='\033[38;5;177m'
WHITE='\033[38;5;255m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
GRIS='\033[38;5;245m'
GRIS2='\033[38;5;240m'
ACC='\033[38;5;44m'
ACC2='\033[38;5;81m'
ACC3='\033[38;5;117m'
VIOLETA='\033[38;5;141m'
ROSA='\033[38;5;212m'
NARANJA='\033[38;5;215m'
OKC='\033[38;5;84m'
BG_TITULO='\033[48;5;24m\033[97m\033[1m'
BG_FASE='\033[48;5;23m\033[38;5;122m\033[1m'
BG_OK='\033[48;5;22m\033[38;5;120m\033[1m'
BG_ERR='\033[48;5;52m\033[38;5;210m\033[1m'
ANCHO=64
LINEA_D="$(printf '═%.0s' $(seq 1 $ANCHO))"
LINEA_S="$(printf '─%.0s' $(seq 1 $ANCHO))"
LINEA_G="$(printf '━%.0s' $(seq 1 $((ANCHO + 2))))"
LOCALE_UTF8=0
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
*UTF-8*|*utf-8*|*UTF8*|*utf8*) LOCALE_UTF8=1 ;;
esac
if [ "$LOCALE_UTF8" -eq 0 ] && locale -a 2>/dev/null | grep -qi '^C\.utf-\?8$'; then
export LC_ALL=C.UTF-8
LOCALE_UTF8=1
fi
ui_plano() { printf '%b' "$1" | sed -e 's/\x1b\[[0-9;]*m//g'; }
ui_visible() {
local t; t="$(ui_plano "$1")"
if [ "$LOCALE_UTF8" -eq 1 ]; then
printf '%s' "${#t}"
else
printf '%s' "$(printf '%s' "$t" | LC_ALL=C tr -d '\200-\277' | LC_ALL=C wc -c | tr -d ' ')"
fi
}
ui_top() { printf "${ACC}╔%s╗${NC}\n" "$LINEA_D"; }
ui_sep() { printf "${ACC}╠%s╣${NC}\n" "$LINEA_S"; }
ui_bot() { printf "${ACC}╚%s╝${NC}\n" "$LINEA_D"; }
ui_fila() {
local txt="$1" vis relleno
vis=$(ui_visible "$txt")
relleno=$(( ANCHO - 2 - vis )); [ "$relleno" -lt 0 ] && relleno=0
printf "${ACC}║${NC} %b%*s ${ACC}║${NC}\n" "$txt" "$relleno" ""
}
ui_titulo() {
local txt="$1" vis izq der
vis=$(ui_visible "$txt")
izq=$(( (ANCHO - vis) / 2 )); [ "$izq" -lt 0 ] && izq=0
der=$(( ANCHO - vis - izq )); [ "$der" -lt 0 ] && der=0
printf "${ACC}║${NC}%*s%b%*s${ACC}║${NC}\n" "$izq" "" "$txt" "$der" ""
}
ui_ok()    { printf "     ${OKC}✓${NC} ${WHITE}%b${NC}\n" "$1"; }
ui_info()  { printf "     ${ACC3}ℹ${NC} ${GRIS}%b${NC}\n" "$1"; }
ui_aviso() { printf "     ${YELLOW}▲${NC} ${YELLOW}%b${NC}\n" "$1"; }
ui_error() { printf "     ${RED}✗${NC} ${RED}%b${NC}\n" "$1"; }
titulo_ascii() {
if command -v figlet >/dev/null 2>&1; then
if command -v lolcat >/dev/null 2>&1; then
figlet -c "$1" 2>/dev/null | lolcat 2>/dev/null && return 0
fi
figlet -c "$1" 2>/dev/null && return 0
fi
ui_top; ui_titulo "${WHITE}${BOLD}$1${NC}"; ui_bot
}
tiempo_transcurrido() {
local s=$(( $(date +%s) - INICIO_INSTALACION ))
printf '%02d:%02d' $((s / 60)) $((s % 60))
}
FASE_ACTUAL=0
FASE_TOTAL=20
CABECERA_MOSTRADA=0
ui_regla() { printf "${ACC}%s${NC}\n" "$LINEA_G"; }
cabecera_instalacion() {
[ "$CABECERA_MOSTRADA" -eq 1 ] && return 0
CABECERA_MOSTRADA=1
echo ""
ui_regla
printf "  ${BG_TITULO} MENÚ DE INSTALACIÓN ${NC}  ${ACC3}HEX AUTO SCRIPT${NC}  ${GRIS2}·${NC}  ${VIOLETA}%s fases${NC}\n" "$FASE_TOTAL"
ui_regla
echo ""
}
fase() {
cabecera_instalacion
FASE_ACTUAL=$((FASE_ACTUAL + 1))
local nombre="$1" pct llenos i barra="" vis relleno
pct=$(( FASE_ACTUAL * 100 / FASE_TOTAL ))
llenos=$(( pct * 12 / 100 ))
for ((i = 0; i < 12; i++)); do
if [ "$i" -lt "$llenos" ]; then barra="${barra}▰"; else barra="${barra}▱"; fi
done
vis=$(ui_visible "$nombre"); relleno=$(( 38 - vis )); [ "$relleno" -lt 0 ] && relleno=0
printf "  ${ACC}●${NC} ${GRIS2}%02d${GRIS}/%02d${NC}  ${WHITE}${BOLD}%s${NC}%*s ${ACC2}%s${NC} ${ACC3}%3d%%${NC} ${GRIS2}%s${NC}\n" \
"$FASE_ACTUAL" "$FASE_TOTAL" "$nombre" "$relleno" "" "$barra" "$pct" "$(tiempo_transcurrido)"
}
MARCA_APT="$CACHE_DESCARGAS/.apt-actualizado"
actualizar_indices_apt() {
[ -f "$MARCA_APT" ] && return 0
apt-get update -y > /dev/null 2>&1
: > "$MARCA_APT" 2>/dev/null
return 0
}
ARQ_SISTEMA="$(uname -m)"
detectar_oracle_cloud() {
local marca=""
marca="$(cat /sys/class/dmi/id/chassis_asset_tag 2>/dev/null)"
[ "$marca" = "OracleCloud.com" ] && return 0
marca="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
case "$marca" in *Oracle*) return 0 ;; esac
marca="$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
case "$marca" in *Oracle*|*OCI*|*Standard.E*|*Standard.A*|*Standard.VM*) return 0 ;; esac
return 1
}
abrir_firewall_oracle() {
detectar_oracle_cloud || return 0
ui_info "VPS Oracle Cloud detectado: abriendo puertos del firewall interno..."
command -v iptables >/dev/null 2>&1 || return 0
iptables -P INPUT ACCEPT > /dev/null 2>&1
iptables -P FORWARD ACCEPT > /dev/null 2>&1
iptables -P OUTPUT ACCEPT > /dev/null 2>&1
iptables -F > /dev/null 2>&1
iptables -t nat -F > /dev/null 2>&1
if command -v ip6tables >/dev/null 2>&1; then
ip6tables -P INPUT ACCEPT > /dev/null 2>&1
ip6tables -P FORWARD ACCEPT > /dev/null 2>&1
ip6tables -P OUTPUT ACCEPT > /dev/null 2>&1
ip6tables -F > /dev/null 2>&1
fi
if command -v netfilter-persistent >/dev/null 2>&1; then
netfilter-persistent save > /dev/null 2>&1
else
mkdir -p /etc/iptables > /dev/null 2>&1
iptables-save > /etc/iptables/rules.v4 2>/dev/null
command -v ip6tables-save >/dev/null 2>&1 && ip6tables-save > /etc/iptables/rules.v6 2>/dev/null
fi
ui_ok "Firewall interno de la VM abierto (Oracle Cloud)."
ui_aviso "Aún debes abrir los puertos en el Security List / NSG de la consola OCI."
}
abrir_firewall_oracle
PIDS_DESCARGA=()
bajar_archivo() {
local url="$1" destino="$2"
if command -v curl >/dev/null 2>&1; then
curl -fsSL --connect-timeout 10 --max-time 600 --retry 2 --retry-delay 2 -o "$destino" "$url" 2>/dev/null
else
wget -q --timeout=20 --tries=3 -O "$destino" "$url" 2>/dev/null
fi
}
descargar_cache() {
local nombre="$1" url="$2" destino="$CACHE_DESCARGAS/$1"
[ -s "$destino" ] && return 0
if bajar_archivo "$url" "$destino.parcial" && [ -s "$destino.parcial" ]; then
mv -f "$destino.parcial" "$destino" 2>/dev/null
else
rm -f "$destino.parcial" 2>/dev/null
fi
return 0
}
usar_cache() {
local nombre="$1" destino="$2" url="$3" espera=0
while [ -e "$CACHE_DESCARGAS/$nombre.parcial" ] && [ "$espera" -lt 600 ]; do
sleep 1; espera=$((espera + 1))
done
if [ -s "$CACHE_DESCARGAS/$nombre" ]; then
cp -f "$CACHE_DESCARGAS/$nombre" "$destino" 2>/dev/null && return 0
fi
bajar_archivo "$url" "$destino"
}
iniciar_descargas_paralelas() {
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || return 0
local xray_zip hyst2_bin sb_suf udp_url zi_suf bad_bin h2v
h2v="${HYSTERIA2_VER//\//-}"
case "$ARQ_SISTEMA" in
x86_64|amd64)
xray_zip="Xray-linux-64.zip"; hyst2_bin="hysteria-linux-amd64"; sb_suf="amd64"; zi_suf="amd64"
udp_url="https://raw.githubusercontent.com/mahpud896/UDP-Custom/main/bin/udp-custom-linux-amd64" ;;
aarch64|arm64)
xray_zip="Xray-linux-arm64-v8a.zip"; hyst2_bin="hysteria-linux-arm64"; sb_suf="arm64"; zi_suf="arm64"
udp_url="https://raw.githubusercontent.com/powermx/udp-custom-arm64/main/udp-custom-linux-arm64" ;;
armv7l|armv7*|armv6l)
xray_zip="Xray-linux-arm32-v7a.zip"; hyst2_bin="hysteria-linux-arm"; sb_suf="armel"; zi_suf="arm"; udp_url="" ;;
i386|i486|i586|i686)
xray_zip="Xray-linux-32.zip"; hyst2_bin="hysteria-linux-386"; sb_suf=""; zi_suf=""; udp_url="" ;;
*)
xray_zip=""; hyst2_bin=""; sb_suf=""; zi_suf=""; udp_url="" ;;
esac
if [ "$(getconf LONG_BIT)" = "64" ]; then
bad_bin="https://www.dropbox.com/s/jo6qznzwbsf1xhi/badvpn-udpgw64"
else
bad_bin="https://www.dropbox.com/s/8gemt9c6k1fph26/badvpn-udpgw"
fi
if [ -n "$xray_zip" ]; then
descargar_cache "xray-${XRAY_VER}.zip" "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/${xray_zip}" &
PIDS_DESCARGA+=($!)
descargar_cache "xray-${XRAY_VER}.zip.dgst" "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/${xray_zip}.dgst" &
PIDS_DESCARGA+=($!)
fi
if [ -n "$hyst2_bin" ]; then
descargar_cache "hysteria2-${h2v}-${hyst2_bin}" "https://github.com/apernet/hysteria/releases/download/${HYSTERIA2_VER}/${hyst2_bin}" &
PIDS_DESCARGA+=($!)
descargar_cache "hysteria2-${h2v}-hashes.txt" "https://github.com/apernet/hysteria/releases/download/${HYSTERIA2_VER}/hashes.txt" &
PIDS_DESCARGA+=($!)
fi
if [ -n "$sb_suf" ]; then
descargar_cache "sing-box-${SINGBOX_VER}-${sb_suf}.deb" "https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VER}/sing-box_${SINGBOX_VER}_linux_${sb_suf}.deb" &
PIDS_DESCARGA+=($!)
fi
if [ -n "$zi_suf" ]; then
descargar_cache "zivpn-1.4.9-${zi_suf}" "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-${zi_suf}" &
PIDS_DESCARGA+=($!)
fi
if [ -n "$udp_url" ]; then
descargar_cache "udp-custom-${ARQ_SISTEMA}" "$udp_url" &
PIDS_DESCARGA+=($!)
fi
descargar_cache "webmin_${WEBMIN_VER}_all.deb" "https://github.com/webmin/webmin/releases/download/${WEBMIN_VER}/webmin_${WEBMIN_VER}_all.deb" &
PIDS_DESCARGA+=($!)
descargar_cache "sldns-server" "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server" &
PIDS_DESCARGA+=($!)
descargar_cache "badvpn-udpgw" "$bad_bin" &
PIDS_DESCARGA+=($!)
descargar_cache "udp-custom-config.json" "https://raw.githubusercontent.com/mahpud896/UDP-Custom/main/config/config.json" &
PIDS_DESCARGA+=($!)
return 0
}
esperar_descargas() {
local pid
for pid in "${PIDS_DESCARGA[@]}"; do
kill -0 "$pid" 2>/dev/null && wait "$pid" 2>/dev/null
done
PIDS_DESCARGA=()
return 0
}
if ! command -v figlet >/dev/null 2>&1 || ! command -v lolcat >/dev/null 2>&1; then
apt-get install "${APT_OPC[@]}" -qq figlet lolcat > /dev/null 2>&1 \
|| apt-get install "${APT_OPC[@]}" -qq figlet > /dev/null 2>&1
fi
step() {
local msg="$1"; shift
local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
local i=0 inicio fin dur status
inicio=$(date +%s)
tput civis 2>/dev/null
( "$@" ) >> "$LOG_INSTALACION" 2>&1 &
local pid=$!
printf "     ${GRIS2}│${NC} ${GRIS}%s${NC}" "$msg"
while kill -0 "$pid" 2>/dev/null; do
i=$(( (i + 1) % ${#spin} ))
printf "\r     ${ACC2}%s${NC} ${GRIS}%s${NC}\033[K" "${spin:$i:1}" "$msg"
sleep 0.1
done
wait "$pid"
status=$?
tput cnorm 2>/dev/null
fin=$(date +%s); dur=$(( fin - inicio ))
if [ $status -eq 0 ]; then
printf "\r     ${OKC}✓${NC} ${GRIS}%-50s${NC} ${GRIS2}%4ss${NC}\033[K\n" "$msg" "$dur"
else
printf "\r     ${RED}✗${NC} ${RED}%-50s${NC} ${RED}%4ss${NC}\033[K\n" "$msg" "$dur"
fi
return $status
}
mostrar_banner_instalador() {
clear
echo ""
ui_top
ui_titulo "${WHITE}${BOLD}H E X   A U T O   S C R I P T${NC}"
ui_titulo "${GRIS}instalador  ·  por JotchuaDevz${NC}"
ui_sep
ui_fila "${GRIS}Dominio  ${NC} ${WHITE}${DOMAIN:-N/A}${NC}"
ui_fila "${GRIS}Sistema  ${NC} ${WHITE}${ID:-linux} ${VERSION_ID:-}${NC}   ${GRIS}soporte${NC} ${WHITE}${SUPPORT_LEVEL}${NC}"
ui_fila "${GRIS}Kernel   ${NC} ${WHITE}$(uname -r)${NC}   ${GRIS}arq${NC} ${WHITE}${ARQ_SISTEMA}${NC}"
ui_bot
echo ""
}
echo ""
ui_top
ui_titulo "${WHITE}${BOLD}INSTALADOR HEX AUTO SCRIPT${NC}"
ui_titulo "${GRIS}SSH · Xray · Hysteria 1/2 · ZiVPN · UDP Custom · SlowDNS${NC}"
ui_sep
ui_fila "${WHITE}${BOLD}Sistemas operativos soportados${NC}"
ui_fila ""
ui_fila "  ${OKC}✔${NC} ${WHITE}Debian 12${NC}       ${GRIS}recomendado${NC}"
ui_fila "  ${OKC}✔${NC} ${WHITE}Debian 11${NC}       ${GRIS}soporte legado${NC}"
ui_fila "  ${OKC}✔${NC} ${WHITE}Ubuntu 26.04${NC}    ${GRIS}soportado${NC}"
ui_fila "  ${OKC}✔${NC} ${WHITE}Ubuntu 24.04${NC}    ${GRIS}soportado${NC}"
ui_fila "  ${OKC}✔${NC} ${WHITE}Ubuntu 22.04${NC}    ${GRIS}recomendado${NC}"
ui_fila "  ${OKC}✔${NC} ${WHITE}Ubuntu 20.04${NC}    ${GRIS}soporte legado${NC}"
ui_sep
if [ "$SUPPORT_LEVEL" = "unsupported" ]; then
ui_fila "${RED}✗ Sistema detectado: ${ID} ${VERSION_ID} (no soportado)${NC}"
ui_bot
echo ""
ui_error "Este instalador solo soporta Ubuntu 20.04/22.04/24.04/26.04 y Debian 11/12."
exit 1
fi
ui_fila "${OKC}✔${NC} ${WHITE}Detectado: ${ID} ${VERSION_ID}${NC} ${GRIS}(${SUPPORT_LEVEL})${NC}"
ui_bot
sleep 2
clear
ofus() {
unset txtofus
local str="$1" number=$(expr length "$1") c
for ((i=1; i<=number; i++)); do
c=$(echo "$str" | cut -b "$i")
case "$c" in
".") c="*";; "*") c=".";;
"1") c="@";; "@") c="1";;
"2") c="?";; "?") c="2";;
"4") c="%";; "%") c="4";;
"-") c="K";; "K") c="-";;
esac
txtofus+="$c"
done
echo "$txtofus" | rev
}
validar_key_hextunnel() {
    local keyuser prefijo resto keyraw ip_port valuekey miip resp tmpfile hoy
    local intentos=0 max_intentos=5
    local FREE_KEY="KEY-FREE/PITOGOD_HEX_JT"
    local FREE_KEY_EXPIRY="2026-12-20"

    miip="$(wget -qO- --timeout=5 ipv4.icanhazip.com 2>/dev/null)"
    [[ -z "$miip" ]] && miip="$(hostname -I | awk '{print $1}')"

    while true; do
        ((intentos++))
        [[ $intentos -gt $max_intentos ]] && {
            echo -e "\n  ${RED}✗ Demasiados intentos fallidos. Instalación cancelada.${NC}\n"
            exit 1
        }

        clear
        echo ""
        titulo_ascii "HEX AUTO"
        echo ""
        ui_top
        ui_titulo "${WHITE}${BOLD}ACTIVACIÓN DE LICENCIA${NC}"
        ui_sep
        ui_fila "${GRIS}Servidor ${NC} ${WHITE}${miip}${NC}"
        ui_fila "${GRIS}Intento  ${NC} ${WHITE}${intentos} de ${max_intentos}${NC}"
        ui_bot
        echo ""
        read -r -p "$(echo -e "  ${YELLOW}KEY${NC} ${GRIS}»${NC} ")" keyuser
        echo ""

        if [[ -z "$keyuser" ]]; then
            echo -e "  ${RED}✗ No ingresaste ninguna key.${NC}"
        elif [[ "$keyuser" == "$FREE_KEY" ]]; then
            hoy="$(date +%Y-%m-%d)"
            if [[ "$hoy" > "$FREE_KEY_EXPIRY" ]]; then
                echo -e "  ${RED}✗ La key libre expiró el ${FREE_KEY_EXPIRY}.${NC}"
            else
                ui_ok "${GREEN} ✅ Key libre aplicada, continuando...${NC}"
                sleep 1
                break
            fi
        else
            prefijo="${keyuser%%/*}"
            resto="${keyuser#*/}"
            if [[ "$prefijo" != "HexGen" || "$resto" == "$keyuser" || -z "$resto" ]]; then
                echo -e "  ${RED}✗ Key con formato inválido.${NC}"
            else
                keyraw="$(ofus "$resto")"
                ip_port="$(echo "$keyraw" | cut -d'/' -f1)"
                valuekey="$(echo "$keyraw" | cut -d'/' -f2)"
                tmpfile="$(mktemp)"
                echo -e "  ${YELLOW}⏳ Verificando key...${NC}"
                wget -q --timeout=10 --tries=1 -O "$tmpfile" \
                    "http://${ip_port}/${valuekey}/HexGen/${miip}" 2>/dev/null
                resp="$(tr -d '\r\n' < "$tmpfile" 2>/dev/null)"
                rm -f "$tmpfile" 2>/dev/null

                case "$resp" in
                    "HexGen")
                        ui_ok "${GREEN} ✅Key válida, continuando...${NC}"
                        sleep 1
                        break
                        ;;
                    "KEY INVALIDA!")
                        echo -e "  ${RED}Key expirada o inválida, por favor genera una nueva.${NC}"
                        ;;
                    "KEY DE GENERADOR!"|"KEY DE HEXGEN!")
                        echo -e "  ${YELLOW}Esta key no corresponde a este tipo de instalación.${NC}"
                        ;;
                    *)
                        echo -e "  ${RED}✗ No se pudo contactar al servidor de validación.${NC}"
                        ;;
                esac
            fi
        fi

        read -r -p "$(echo -e "\n  ${CYAN}¿Deseas intentar de nuevo? [s/n]: ${NC}")" reintentar
        [[ "$reintentar" != "s" && "$reintentar" != "S" ]] && {
            echo -e "  ${RED}✗ Instalación cancelada.${NC}"
            exit 1
        }
    done
}

validar_key_hextunnel
clear
ui_top
ui_titulo "${WHITE}${BOLD}CONFIGURACIÓN DE DOMINIO${NC}"
ui_sep
ui_fila "${GRIS}Deja el valor por defecto para usar la IP del servidor.${NC}"
ui_fila "${GRIS}Con dominio real se emite un certificado Let's Encrypt.${NC}"
ui_bot
echo ""
detectar_ip_publica() {
local ip=""
ip=$(curl -4 -s --max-time 5 https://ipv4.icanhazip.com 2>/dev/null | tr -d '[:space:]')
[ -z "$ip" ] && ip=$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null | tr -d '[:space:]')
[ -z "$ip" ] && ip=$(wget -qO- -T 5 -t 1 https://ipinfo.io/ip 2>/dev/null | tr -d '[:space:]')
[ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
printf '%s' "$ip"
}
normalizar_dominio() {
local d="$1"
d="$(printf '%s' "$d" | tr -d '[:space:]' | tr 'A-Z' 'a-z')"
d="${d#http://}"
d="${d#https://}"
d="${d#*@}"
d="${d%%/*}"
d="${d%%:*}"
d="${d%.}"
printf '%s' "$d"
}
es_ipv4() { [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; }
es_fqdn() { [[ "$1" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]]; }
SERVER_IP="$(detectar_ip_publica)"
if [ -t 0 ]; then
ENTRADA_TTY="/dev/stdin"
elif [ -r /dev/tty ]; then
ENTRADA_TTY="/dev/tty"
else
ENTRADA_TTY=""
fi
if [ -n "$ENTRADA_TTY" ]; then
while :; do
read -r -e -i "$SERVER_IP" -p "$(echo -e "  ${YELLOW}Dominio para Xray${NC} ${GRIS}»${NC} ")" DOMAIN < "$ENTRADA_TTY"
DOMAIN="$(normalizar_dominio "${DOMAIN:-$SERVER_IP}")"
if es_ipv4 "$DOMAIN" || es_fqdn "$DOMAIN"; then
break
fi
ui_error "Valor inválido. Usa un dominio (mi.dominio.com) o una IPv4."
done
else
DOMAIN="$(normalizar_dominio "${DOMAIN:-$SERVER_IP}")"
ui_info "Sin terminal interactiva, se usa ${WHITE}${DOMAIN}${NC}"
fi
if [ -z "$DOMAIN" ]; then
ui_error "No se pudo determinar el dominio ni la IP pública del servidor."
exit 1
fi
export DOMAIN
echo ""
preparar_dns_certbot() {
actualizar_indices_apt
local faltantes=()
command -v dig     >/dev/null 2>&1 || faltantes+=(dnsutils)
command -v certbot >/dev/null 2>&1 || faltantes+=(certbot)
command -v curl    >/dev/null 2>&1 || faltantes+=(curl)
command -v wget    >/dev/null 2>&1 || faltantes+=(wget)
command -v openssl >/dev/null 2>&1 || faltantes+=(openssl)
[ "${#faltantes[@]}" -gt 0 ] && apt-get install "${APT_OPC[@]}" -qq "${faltantes[@]}" > /dev/null 2>&1
return 0
}
liberar_puerto_80() {
local s
for s in haproxy nginx xray sslh apache2 lighttpd caddy; do
systemctl stop "$s" 2>/dev/null || true
done
for s in $(systemctl list-units --no-legend --state=running 'ws-proxy@*.service' 2>/dev/null | awk '{print $1}'); do
systemctl stop "$s" 2>/dev/null || true
done
sleep 1
if command -v ss >/dev/null 2>&1 && ss -lntH 2>/dev/null | awk '{print $4}' | grep -qE '(^|[.:])80$'; then
return 1
fi
return 0
}
restaurar_servicios_80() {
local s
for s in xray haproxy nginx; do
systemctl start "$s" 2>/dev/null || true
done
}
ips_del_dominio() { dig +short A "$1" @1.1.1.1 2>/dev/null | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; }
par_cert_coincide() {
local c="$1" k="$2" a b
a=$(openssl x509 -noout -pubkey -in "$c" 2>/dev/null)
b=$(openssl pkey -pubout -in "$k" 2>/dev/null)
[ -n "$a" ] && [ "$a" = "$b" ]
}
fase "Certificados SSL y herramientas de DNS"
iniciar_descargas_paralelas
step "Preparando herramientas de DNS/SSL..." preparar_dns_certbot
iniciar_descargas_paralelas
mkdir -p /etc/xray > /dev/null 2>&1
if es_ipv4 "$DOMAIN"; then
USE_LETSENCRYPT=false
ui_info "Certificado autofirmado para la IP ${WHITE}$DOMAIN${NC}"
ui_aviso "Los clientes deben activar 'allowInsecure' en el TLS del puerto 443."
else
USE_LETSENCRYPT=true
ui_info "Verificando que ${WHITE}$DOMAIN${NC}${GRIS} resuelva a la IP del servidor...${NC}"
[ -z "$SERVER_IP" ] && SERVER_IP="$(detectar_ip_publica)"
DOMAIN_IPS="$(ips_del_dominio "$DOMAIN")"
if [ -z "$DOMAIN_IPS" ]; then
ui_error "El dominio $DOMAIN no resuelve a ninguna IP (falta el registro A)."
ui_error "Crea el registro A y vuelve a ejecutar el script."
exit 1
fi
if ! printf '%s\n' "$DOMAIN_IPS" | grep -qx "$SERVER_IP"; then
ui_error "El dominio $DOMAIN apunta a: $(printf '%s ' $DOMAIN_IPS)"
ui_error "La IP de este servidor es $SERVER_IP."
ui_aviso "Si usas Cloudflare, pon el registro en 'DNS only' (nube gris) y reintenta."
exit 1
fi
ui_ok "Dominio verificado."
if ! liberar_puerto_80; then
ui_error "El puerto 80 sigue ocupado, certbot --standalone no puede validar."
ui_error "Revisa con: ss -lntp | grep ':80'"
exit 1
fi
solicitar_certificado_le() {
certbot certonly --standalone --preferred-challenges http --non-interactive --agree-tos \
--keep-until-expiring --cert-name "$DOMAIN" -d "$DOMAIN" --email "admin@$DOMAIN" >> "$LOG_INSTALACION" 2>&1 && return 0
certbot certonly --standalone --preferred-challenges http --non-interactive --agree-tos \
--keep-until-expiring --cert-name "$DOMAIN" -d "$DOMAIN" --register-unsafely-without-email >> "$LOG_INSTALACION" 2>&1
}
if ! step "Solicitando certificado SSL (Let's Encrypt)..." solicitar_certificado_le; then
ui_error "No se pudo emitir el certificado Let's Encrypt para $DOMAIN."
ui_error "Detalles en $LOG_INSTALACION y /var/log/letsencrypt/letsencrypt.log"
restaurar_servicios_80
exit 1
fi
CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
if [ ! -s "$CERT_PATH" ] || [ ! -s "$KEY_PATH" ]; then
ui_error "Certbot terminó pero no existe $CERT_PATH"
ui_error "Revisa: certbot certificates"
restaurar_servicios_80
exit 1
fi
echo "letsencrypt" > /etc/xray/cert_type
fi
if [ "$USE_LETSENCRYPT" = false ]; then
generar_cert_autofirmado() {
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
-keyout /etc/xray/xray.key \
-out /etc/xray/xray.crt \
-subj "/CN=${DOMAIN}/O=HexTunnel/C=US" > /dev/null 2>&1
}
step "Generando certificado autofirmado..." generar_cert_autofirmado
echo "selfsigned" > /etc/xray/cert_type
else
cp -L "$CERT_PATH" /etc/xray/xray.crt 2>> "$LOG_INSTALACION"
cp -L "$KEY_PATH" /etc/xray/xray.key 2>> "$LOG_INSTALACION"
fi
if [ ! -s /etc/xray/xray.crt ] || [ ! -s /etc/xray/xray.key ]; then
ui_error "No quedó un par certificado/clave válido en /etc/xray/"
exit 1
fi
if ! par_cert_coincide /etc/xray/xray.crt /etc/xray/xray.key; then
ui_error "El certificado y la clave de Xray no coinciden."
exit 1
fi
chmod 644 /etc/xray/xray.crt > /dev/null 2>&1
chmod 600 /etc/xray/xray.key > /dev/null 2>&1
mkdir -p /etc/stunnel > /dev/null 2>&1
cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem 2>/dev/null
chmod 600 /etc/stunnel/stunnel.pem > /dev/null 2>&1
chown root:root /etc/stunnel/stunnel.pem > /dev/null 2>&1
SSH_Port1='22'
SSH_Port2='299'
Stunnel_Port='127.0.0.1:4443'
Stunnel_Port_Num='4443'
Squid_Port1='3128'
Squid_Port2='8000'
WsPorts=('10080' '25' '2082' '2086')
WsPort='10080'
MainPort='666'
BHTTP_PORT1='8180'
HCR_PORT1='8780'
echo ""
ui_top
ui_titulo "${WHITE}${BOLD}CONFIGURACIÓN DE SLOWDNS${NC}"
ui_sep
ui_fila "${GRIS}Nameserver (NS) que apunta a este servidor. Enter = por defecto.${NC}"
ui_bot
echo ""
read -p "$(echo -e "  ${YELLOW}Nameserver SlowDNS${NC} ${GRIS}»${NC} ")" -e -i "ns-miami.hexapps.app" Nameserver
echo ""
Serverkey='819d82813183e4be3ca1ad74387e47c0c993b81c601b2d1473a3f47731c404ae'
Serverpub='7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59'
UDP_PORT=":36712"
HYST2_PORT="36713"
UDP_CUSTOM_PORT="36717"
ZIVPN_PORT="5667"
_default_obfs='HexTunnel'
_default_password='HexTunnel'
ui_top
ui_titulo "${WHITE}${BOLD}CONFIGURACIÓN DE UDP / HYSTERIA${NC}"
ui_sep
ui_fila "${GRIS}Obfs y contraseña que usarán Hysteria 1/2 y ZiVPN.${NC}"
ui_bot
echo ""
if [ -t 0 ]; then
read -e -p "$(echo -e "  ${YELLOW}Obfuscation (obfs)${NC} ${GRIS}»${NC} ")" -i "${_default_obfs}" _input_obfs
OBFS="${_input_obfs:-${_default_obfs}}"
read -e -p "$(echo -e "  ${YELLOW}Contraseña UDP${NC} ${GRIS}»${NC} ")" -i "${_default_password}" _input_pass
PASSWORD="${_input_pass:-${_default_password}}"
else
OBFS="${OBFS:-${_default_obfs}}"
PASSWORD="${PASSWORD:-${_default_password}}"
fi
echo ""
export OBFS PASSWORD
clear
sleep 1.5
Nginx_Port='85'
Dns_1='1.1.1.1'
Dns_2='1.0.0.1'
MyVPS_Time='Africa/Accra'
My_Chat_ID='344472672'
My_Bot_Key='8715170470:AAE8urT5fSWdZ_xgkwwZivN4kgHW9nBVxgY'
function ip_address(){
local IP="$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )"
[ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipv4.icanhazip.com 2>/dev/null )"
[ -z "${IP}" ] && IP="$( wget -qO- -t1 -T2 ipinfo.io/ip 2>/dev/null )"
[ ! -z "${IP}" ] && echo "${IP}" || echo
}
IPADDR="$(ip_address)"
mostrar_banner_instalador
fase "Actualización de índices del sistema"
actualizar_sistema() {
actualizar_indices_apt
}
step "Actualizando (Apt Update)..." actualizar_sistema
systemctl stop systemd-resolved 2>/dev/null
systemctl disable systemd-resolved 2>/dev/null
SSH_SERVICE="ssh"; STUNNEL_SERVICE="stunnel4"; SQUID_SERVICE="squid"; SSLH_SERVICE="sslh"; NGINX_SERVICE="nginx"; SFTP_SUBSYSTEM="internal-sftp"
mkdir -p /etc/stunnel /etc/nginx/conf.d /etc/deekayvpn /var/run/sslh /etc/xray > /dev/null 2>&1
echo "$DOMAIN" > /etc/deekayvpn/domain.txt
ssh-keygen -A >/dev/null 2>&1 || true
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections > /dev/null 2>&1
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections > /dev/null 2>&1
HERRAMIENTAS_BASE=()
command -v ss >/dev/null 2>&1 || HERRAMIENTAS_BASE+=(iproute2)
command -v netfilter-persistent >/dev/null 2>&1 || HERRAMIENTAS_BASE+=(netfilter-persistent iptables-persistent)
command -v jq >/dev/null 2>&1 || HERRAMIENTAS_BASE+=(jq)
command -v curl >/dev/null 2>&1 || HERRAMIENTAS_BASE+=(curl)
instalar_herramientas_base() { apt-get install "${APT_OPC[@]}" -qq "${HERRAMIENTAS_BASE[@]}" > /dev/null 2>&1; }
if [ "${#HERRAMIENTAS_BASE[@]}" -gt 0 ]; then
step "Instalando herramientas base (${#HERRAMIENTAS_BASE[@]})" instalar_herramientas_base
fi
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
nginx haproxy certbot jq figlet git gcc make build-essential perl expect libdbi-perl vnstat socat
libnet-ssleay-perl libauthen-pam-perl libio-pty-perl apt-show-versions openssh-server rsyslog lsof procps
python3
)
AVAILABLE_PACKAGES=()
UNAVAILABLE_PACKAGES=()
PAQUETES_EN_REPO=" $(apt-cache show "${PACKAGE_LIST[@]}" 2>/dev/null | awk '/^Package: /{print $2}' | sort -u | tr '\n' ' ') "
if [[ "${#PAQUETES_EN_REPO}" -lt 5 ]]; then
for pkg in "${PACKAGE_LIST[@]}"; do
if apt-cache show "$pkg" >/dev/null 2>&1; then
AVAILABLE_PACKAGES+=("$pkg")
else
UNAVAILABLE_PACKAGES+=("$pkg")
fi
done
else
for pkg in "${PACKAGE_LIST[@]}"; do
if [[ "$PAQUETES_EN_REPO" == *" $pkg "* ]]; then
AVAILABLE_PACKAGES+=("$pkg")
else
UNAVAILABLE_PACKAGES+=("$pkg")
fi
done
fi
if [[ ${#UNAVAILABLE_PACKAGES[@]} -gt 0 ]]; then
ui_aviso "${YELLOW}No disponibles en este repo (se omiten): ${UNAVAILABLE_PACKAGES[*]}${NC}"
fi
SSH_CLIENT_IP="$(echo "${SSH_CONNECTION:-}" | awk '{print $1}')"
if [[ "$SSH_CLIENT_IP" == *:* ]]; then
echo -e "${CYAN}Tu sesion SSH actual usa IPv6 ($SSH_CLIENT_IP) - se omite deshabilitar IPv6 para no cortar la conexion.${NC}"
else
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null
sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 2>&1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null 2>&1
fi
rm -f /etc/resolv.conf > /dev/null 2>&1
printf 'nameserver %s\nnameserver %s\n' "$Dns_1" "$Dns_2" > /etc/resolv.conf
ln -fs /usr/share/zoneinfo/$MyVPS_Time /etc/localtime > /dev/null 2>&1
cat > /root/.profile <<'EOF_PROFILE'
clear
printf '\033[38;5;44m╔═════════════════════════════════════╗\033[0m\n'
printf '\033[38;5;44m║\033[0m   \033[1;38;5;255mH E X   A U T O   S C R I P T\033[0m    \033[38;5;44m║\033[0m\n'
printf '\033[38;5;44m║\033[0m   \033[38;5;141mpor JotchuaDevz\033[0m                   \033[38;5;44m║\033[0m\n'
printf '\033[38;5;44m╚═════════════════════════════════════╝\033[0m\n'
printf '  \033[38;5;245mEscribe\033[0m \033[1;38;5;221mmenu\033[0m \033[38;5;245mpara abrir el panel.\033[0m\n\n'
EOF_PROFILE
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections > /dev/null 2>&1
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections > /dev/null 2>&1
fase "Instalación de paquetes del sistema"
FAILED_PACKAGES=()
instalar_paquetes_bloque() {
apt-get install "${APT_OPC[@]}" -qq --no-install-suggests "${AVAILABLE_PACKAGES[@]}" > /dev/null 2>&1
}
if ! step "Instalando ${#AVAILABLE_PACKAGES[@]} paquetes (bloque único)" instalar_paquetes_bloque; then
ui_aviso "El bloque falló: se reintenta uno por uno para aislar el paquete culpable."
for pkg in "${AVAILABLE_PACKAGES[@]}"; do
if ! step "Instalando: ${pkg}" apt-get install "${APT_OPC[@]}" -qq "$pkg"; then
FAILED_PACKAGES+=("$pkg")
fi
done
fi
if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
ui_error "${RED}No se pudieron instalar: ${FAILED_PACKAGES[*]}${NC}"
fi
iniciar_descargas_paralelas
systemctl enable "$SSH_SERVICE" >/dev/null 2>&1 || true
systemctl enable rsyslog >/dev/null 2>&1 || true
systemctl restart rsyslog >/dev/null 2>&1 || true
command -v lolcat >/dev/null 2>&1 || gem install lolcat >/dev/null 2>&1
apt -y --purge remove apache2 ufw firewalld >/dev/null 2>&1
systemctl stop nginx > /dev/null 2>&1
fase "Panel Webmin y servicios base"
instalar_webmin() {
local deb="/tmp/webmin_${WEBMIN_VER}_all.deb"
usar_cache "webmin_${WEBMIN_VER}_all.deb" "$deb" \
"https://github.com/webmin/webmin/releases/download/${WEBMIN_VER}/webmin_${WEBMIN_VER}_all.deb" || return 1
[ -s "$deb" ] || return 1
dpkg --install "$deb" > /dev/null 2>&1 || apt-get install -f "${APT_OPC[@]}" >/dev/null 2>&1
rm -f "$deb" >/dev/null 2>&1
return 0
}
step "Instalando panel Webmin" instalar_webmin
sed -i 's|ssl=1|ssl=0|g' /etc/webmin/miniserv.conf > /dev/null 2>&1
systemctl restart webmin >/dev/null 2>&1 || true
cat <<'deekay77' > /etc/zorro-luffy
<br><font color="#C12267">HEX TUNNEL | VPN | SERVICE<br></font><br>
<font color="#b3b300"> x No DDOS<br></font>
<font color="#00cc00"> x No Torrent<br></font>
<font color="#ff1aff"> x No Spamming<br></font>
<font color="blue"> x No Phishing<br></font>
<font color="#A810FF"> x No Hacking<br></font><br>
<font color="red">• BROUGHT TO YOU BY <br></font><font color="#00cccc">https://t.me/RequestLab_X_Canal !<br></font>
deekay77
fase "OpenSSH, SSLH y Stunnel"
rm -f /etc/ssh/sshd_config > /dev/null 2>&1
cat <<'MySSHConfig' > /etc/ssh/sshd_config
Port myPORT1
Port myPORT2
AddressFamily inet
ListenAddress 0.0.0.0
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
MaxSessions 5000
MaxStartups 500:30:1000
LoginGraceTime 30
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
UsePAM yes
X11Forwarding yes
PrintMotd no
ClientAliveInterval 120
ClientAliveCountMax 3
UseDNS no
Banner /etc/zorro-luffy
LogLevel QUIET
AcceptEnv LANG LC_*
Subsystem sftp SFTP_SUBSYSTEM
MySSHConfig
sed -i "s|myPORT1|$SSH_Port1|g" /etc/ssh/sshd_config > /dev/null 2>&1
sed -i "s|myPORT2|$SSH_Port2|g" /etc/ssh/sshd_config > /dev/null 2>&1
sed -i "s|SFTP_SUBSYSTEM|$SFTP_SUBSYSTEM|g" /etc/ssh/sshd_config > /dev/null 2>&1
sed -i -E '/password\s+(requisite|required)\s+pam_(cracklib|pwquality)\.so.*/d' /etc/pam.d/common-password > /dev/null 2>&1
sed -i 's/use_authtok //g' /etc/pam.d/common-password > /dev/null 2>&1
sed -i '/\/bin\/false/d' /etc/shells > /dev/null 2>&1
sed -i '/\/usr\/sbin\/nologin/d' /etc/shells > /dev/null 2>&1
echo '/bin/false' >> /etc/shells; echo '/usr/sbin/nologin' >> /etc/shells
systemctl restart "$SSH_SERVICE" > /dev/null 2>&1
cd /etc/default/ > /dev/null 2>&1
cat << sslh > /etc/default/sslh
RUN=yes
DAEMON=/usr/sbin/sslh
DAEMON_OPTS="--user sslh --listen 127.0.0.1:$MainPort --ssh 127.0.0.1:$SSH_Port1 --http 127.0.0.1:$WsPort --pidfile /var/run/sslh/sslh.pid"
sslh
cat > /etc/tmpfiles.d/sslh.conf <<'EOF_TMPFILES_SSLH'
d /run/sslh 0755 sslh sslh -
EOF_TMPFILES_SSLH
systemd-tmpfiles --create /etc/tmpfiles.d/sslh.conf > /dev/null 2>&1
systemctl daemon-reload > /dev/null 2>&1; systemctl enable "$SSLH_SERVICE" > /dev/null 2>&1; systemctl restart "$SSLH_SERVICE" > /dev/null 2>&1
cd > /dev/null 2>&1
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
sed -i "s|Stunnel_Port|$Stunnel_Port|g" /etc/stunnel/stunnel.conf > /dev/null 2>&1
sed -i "s|MainPort|$MainPort|g" /etc/stunnel/stunnel.conf > /dev/null 2>&1
systemctl enable "$STUNNEL_SERVICE" > /dev/null 2>&1; systemctl restart "$STUNNEL_SERVICE" > /dev/null 2>&1
fase "Proxy WebSocket (Node.js)"
loc=/etc/socksproxy; mkdir -p $loc > /dev/null 2>&1; apt-get install "${APT_OPC[@]}" -qq nodejs > /dev/null 2>&1
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
systemctl daemon-reload > /dev/null 2>&1
for port in "${WsPorts[@]}"; do systemctl enable ws-proxy@$port > /dev/null 2>&1; systemctl restart ws-proxy@$port > /dev/null 2>&1; done
fase "Núcleo Xray / V2Ray"
esperar_descargas
ui_info "Instalando Xray Core estable alineado con Hiddify"
XRAY_VER="v26.3.27"
cat <<'EOF_XRAY_INSTALLER' > /usr/local/sbin/xray-install-version
set -o pipefail
umask 077
version="${1:?Usage: xray-install-version VERSION}"
case "$(uname -m)" in
x86_64|amd64) asset="Xray-linux-64.zip" ;;
i386|i486|i586|i686) asset="Xray-linux-32.zip" ;;
aarch64|arm64) asset="Xray-linux-arm64-v8a.zip" ;;
armv7l|armv7*) asset="Xray-linux-arm32-v7a.zip" ;;
*) echo "Unsupported Xray architecture: $(uname -m)" >&2; exit 1 ;;
esac
tmp_dir=$(mktemp -d /tmp/xray-install.XXXXXX) || exit 1
trap 'rm -rf "$tmp_dir"' EXIT
base_url="https://github.com/XTLS/Xray-core/releases/download/${version}/${asset}"
cache_dir="/tmp/hex-cache"
desde_cache=0
if [ -s "$cache_dir/xray-${version}.zip" ] && [ -s "$cache_dir/xray-${version}.zip.dgst" ]; then
cp -f "$cache_dir/xray-${version}.zip" "$tmp_dir/xray.zip" 2>/dev/null &&
cp -f "$cache_dir/xray-${version}.zip.dgst" "$tmp_dir/xray.zip.dgst" 2>/dev/null && desde_cache=1
fi
if [ "$desde_cache" -eq 0 ]; then
wget -qO "$tmp_dir/xray.zip" "$base_url" 2>/dev/null || { echo "Xray download failed." >&2; exit 1; }
wget -qO "$tmp_dir/xray.zip.dgst" "$base_url.dgst" 2>/dev/null || { echo "Xray digest download failed." >&2; exit 1; }
fi
expected=$(awk -F'= *' 'toupper($1) == "SHA2-256" {print tolower($2); exit}' "$tmp_dir/xray.zip.dgst")
actual=$(sha256sum "$tmp_dir/xray.zip" | awk '{print tolower($1)}')
if [ -z "$expected" ] || [ "$actual" != "$expected" ]; then
[ "$desde_cache" -eq 1 ] || { echo "Xray SHA-256 verification failed." >&2; exit 1; }
rm -f "$cache_dir/xray-${version}.zip" "$cache_dir/xray-${version}.zip.dgst" 2>/dev/null
wget -qO "$tmp_dir/xray.zip" "$base_url" 2>/dev/null || { echo "Xray download failed." >&2; exit 1; }
wget -qO "$tmp_dir/xray.zip.dgst" "$base_url.dgst" 2>/dev/null || { echo "Xray digest download failed." >&2; exit 1; }
expected=$(awk -F'= *' 'toupper($1) == "SHA2-256" {print tolower($2); exit}' "$tmp_dir/xray.zip.dgst")
actual=$(sha256sum "$tmp_dir/xray.zip" | awk '{print tolower($1)}')
[ -n "$expected" ] && [ "$actual" = "$expected" ] || { echo "Xray SHA-256 verification failed." >&2; exit 1; }
fi
unzip -q "$tmp_dir/xray.zip" -d "$tmp_dir/unpacked" 2>/dev/null || exit 1
[ -f "$tmp_dir/unpacked/xray" ] || { echo "Xray binary missing from archive." >&2; exit 1; }
chmod 755 "$tmp_dir/unpacked/xray" > /dev/null 2>&1
if [ -s /etc/xray/config.json ]; then
"$tmp_dir/unpacked/xray" run -test -config /etc/xray/config.json > /dev/null 2>&1 || {
echo "The downloaded Xray version rejected the current configuration." >&2
exit 1
}
fi
install -m 755 "$tmp_dir/unpacked/xray" /usr/local/bin/xray.new > /dev/null 2>&1
mv -f /usr/local/bin/xray.new /usr/local/bin/xray > /dev/null 2>&1
EOF_XRAY_INSTALLER
chmod 700 /usr/local/sbin/xray-install-version
if ! step "Instalando V2Ray..." /usr/local/sbin/xray-install-version "$XRAY_VER"; then
echo -e "${RED}No se pudo instalar una versión verificada de Xray Core ${XRAY_VER}.${NC}"
exit 1
fi
touch /etc/xray/vless.txt > /dev/null 2>&1
chmod 600 /etc/xray/vless.txt > /dev/null 2>&1
if [ "$USE_LETSENCRYPT" = true ]; then
XRAY_TLS_ALLOW_INSECURE="${XRAY_TLS_ALLOW_INSECURE:-0}"
XRAY_CERT_SOURCE="${XRAY_CERT_SOURCE:-letsencrypt}"
else
XRAY_TLS_ALLOW_INSECURE="${XRAY_TLS_ALLOW_INSECURE:-1}"
XRAY_CERT_SOURCE="${XRAY_CERT_SOURCE:-selfsigned}"
fi
{
printf 'XRAY_TLS_ALLOW_INSECURE=%q\n' "$XRAY_TLS_ALLOW_INSECURE"
printf 'XRAY_CERT_SOURCE=%q\n' "$XRAY_CERT_SOURCE"
} > /etc/xray/server.env
chmod 600 /etc/xray/server.env > /dev/null 2>&1
cat << 'EOF' > /etc/xray/config.json
{
"log": { "access": "none", "error": "/var/log/xray/error.log", "loglevel": "error" },
"inbounds": [
{
"tag": "vless-tls-dispatcher",
"port": 443,
"protocol": "vless",
"settings": {
"clients": [],
"decryption": "none",
"fallbacks": [
{ "path": "/httpupgrade", "dest": 10005, "xver": 2 },
{ "path": "/vless-tcp", "dest": 10007, "xver": 2 },
{ "path": "/vmess-hup", "dest": 10011, "xver": 2 },
{ "path": "/vmess-tcp", "dest": 10008, "xver": 2 },
{ "path": "/trojan", "dest": 10013, "xver": 2 },
{ "path": "/vless", "dest": 10003, "xver": 2 },
{ "path": "/vmess", "dest": 10009, "xver": 2 },
{ "alpn": "h2", "dest": 10444, "xver": 2 },
{ "dest": 666 }
]
},
"streamSettings": {
"network": "tcp",
"security": "tls",
"tlsSettings": {
"alpn": ["h2", "http/1.1"],
"certificates": [
{ "certificateFile": "/etc/xray/xray.crt", "keyFile": "/etc/xray/xray.key" }
]
},
"sockopt": { "tcpFastOpen": true }
}
},
{
"tag": "vless-tcp-http",
"listen": "127.0.0.1",
"port": 10007,
"protocol": "vless",
"settings": { "clients": [], "decryption": "none" },
"streamSettings": {
"network": "tcp",
"security": "none",
"tcpSettings": { "header": { "type": "http", "request": { "path": ["/vless-tcp"] } } },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vless-tcp-80",
"listen": "127.0.0.1",
"port": 18080,
"protocol": "vless",
"settings": {
"clients": [],
"decryption": "none",
"fallbacks": [
{ "path": "/httpupgrade", "dest": 10005, "xver": 2 },
{ "path": "/vless-tcp", "dest": 10007, "xver": 2 },
{ "path": "/vmess-hup", "dest": 10011, "xver": 2 },
{ "path": "/vmess-tcp", "dest": 10008, "xver": 2 },
{ "path": "/trojan", "dest": 10013, "xver": 2 },
{ "path": "/vless", "dest": 10003, "xver": 2 },
{ "path": "/vmess", "dest": 10009, "xver": 2 },
{ "path": "/xhttp", "dest": 10004, "xver": 2 },
{ "path": "/vmess-xhttp", "dest": 10010, "xver": 2 },
{ "alpn": "h2", "dest": 10444, "xver": 2 },
{ "dest": 10080 }
]
},
"streamSettings": {
"network": "tcp",
"security": "none",
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vless-ws",
"listen": "127.0.0.1",
"port": 10003,
"protocol": "vless",
"settings": { "clients": [], "decryption": "none" },
"streamSettings": {
"network": "ws",
"security": "none",
"wsSettings": { "path": "/vless" },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vless-xhttp",
"listen": "127.0.0.1",
"port": 10004,
"protocol": "vless",
"settings": { "clients": [], "decryption": "none" },
"streamSettings": {
"network": "xhttp",
"security": "none",
"xhttpSettings": { "path": "/xhttp", "mode": "auto" },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vless-httpupgrade",
"listen": "127.0.0.1",
"port": 10005,
"protocol": "vless",
"settings": { "clients": [], "decryption": "none" },
"streamSettings": {
"network": "httpupgrade",
"security": "none",
"httpupgradeSettings": { "path": "/httpupgrade", "host": "" },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vless-grpc",
"listen": "127.0.0.1",
"port": 10006,
"protocol": "vless",
"settings": { "clients": [], "decryption": "none" },
"streamSettings": {
"network": "grpc",
"security": "none",
"grpcSettings": { "serviceName": "grpc-svc" },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vmess-tcp-http",
"listen": "127.0.0.1",
"port": 10008,
"protocol": "vmess",
"settings": { "clients": [] },
"streamSettings": {
"network": "tcp",
"security": "none",
"tcpSettings": { "header": { "type": "http", "request": { "path": ["/vmess-tcp"] } } },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vmess-ws",
"listen": "127.0.0.1",
"port": 10009,
"protocol": "vmess",
"settings": { "clients": [] },
"streamSettings": {
"network": "ws",
"security": "none",
"wsSettings": { "path": "/vmess" },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vmess-xhttp",
"listen": "127.0.0.1",
"port": 10010,
"protocol": "vmess",
"settings": { "clients": [] },
"streamSettings": {
"network": "xhttp",
"security": "none",
"xhttpSettings": { "path": "/vmess-xhttp", "mode": "auto" },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vmess-httpupgrade",
"listen": "127.0.0.1",
"port": 10011,
"protocol": "vmess",
"settings": { "clients": [] },
"streamSettings": {
"network": "httpupgrade",
"security": "none",
"httpupgradeSettings": { "path": "/vmess-hup", "host": "" },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vmess-grpc",
"listen": "127.0.0.1",
"port": 10012,
"protocol": "vmess",
"settings": { "clients": [] },
"streamSettings": {
"network": "grpc",
"security": "none",
"grpcSettings": { "serviceName": "vmess-grpc-svc" },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "trojan-ws",
"listen": "127.0.0.1",
"port": 10013,
"protocol": "trojan",
"settings": { "clients": [] },
"streamSettings": {
"network": "ws",
"security": "none",
"wsSettings": { "path": "/trojan" },
"sockopt": { "acceptProxyProtocol": true, "tcpFastOpen": true }
}
},
{
"tag": "vless-grpc-ntls",
"port": 8082,
"protocol": "vless",
"settings": { "clients": [], "decryption": "none" },
"streamSettings": {
"network": "grpc",
"security": "none",
"grpcSettings": { "serviceName": "grpc-svc" }
}
},
{
"tag": "vmess-grpc-ntls",
"port": 8083,
"protocol": "vmess",
"settings": { "clients": [] },
"streamSettings": {
"network": "grpc",
"security": "none",
"grpcSettings": { "serviceName": "vmess-grpc-svc" }
}
},
{
"tag": "vless-kcp-ntls",
"port": "8084",
"protocol": "vless",
"settings": { "clients": [], "decryption": "none" },
"streamSettings": {
"network": "mkcp",
"security": "none",
"kcpSettings": {
"mtu": 1350, "tti": 20, "uplinkCapacity": 5, "downlinkCapacity": 20,
"congestion": false, "readBufferSize": 2, "writeBufferSize": 2
}
}
},
{
"tag": "vmess-kcp-ntls",
"port": "8085",
"protocol": "vmess",
"settings": { "clients": [] },
"streamSettings": {
"network": "mkcp",
"security": "none",
"kcpSettings": {
"mtu": 1350, "tti": 20, "uplinkCapacity": 5, "downlinkCapacity": 20,
"congestion": false, "readBufferSize": 2, "writeBufferSize": 2
}
}
}
],
"outbounds": [
{ "protocol": "freedom", "settings": {} },
{ "protocol": "blackhole", "settings": {}, "tag": "blocked" }
]
}
EOF
chmod 600 /etc/xray/config.json > /dev/null 2>&1
mkdir -p /var/log/xray > /dev/null 2>&1
if ! /usr/local/bin/xray run -test -config /etc/xray/config.json > /dev/null 2>&1; then
echo -e "${RED}Xray configuration validation failed. Review the Xray error printed above.${NC}"
exit 1
fi
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
RestartSec=2
LimitNPROC=10000
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload > /dev/null 2>&1
systemctl disable --now haproxy 2>/dev/null || true
systemctl enable xray > /dev/null 2>&1
systemctl restart xray > /dev/null 2>&1

fase "Protocolo BHTTP independiente (puerto 8180)"

install_bhttp_phase() {

mkdir -p /etc/bhttp/bin > /dev/null 2>&1

case "$(uname -m)" in
    x86_64|amd64)   BHTTP_ARCH="amd64" ;;
    aarch64|arm64)  BHTTP_ARCH="arm64" ;;
    *)
        ui_aviso "Arquitectura no soportada para BHTTP: $(uname -m) (solo amd64/arm64). Fase omitida."
        return 1
        ;;
esac

if ss -lntp 2>/dev/null | grep -q ":${BHTTP_PORT1}[[:space:]]" && ! systemctl is-active --quiet bhttp-server; then
    ui_aviso "Puerto ${BHTTP_PORT1} ocupado por otro servicio; no se modificó nada."
    ss -lntp 2>/dev/null | grep ":${BHTTP_PORT1}[[:space:]]"
    return 1
fi

for c in curl ss sysctl awk grep sed systemctl; do
    command -v "$c" >/dev/null 2>&1 || echo "Advertencia: falta el comando '$c', BHTTP podría no instalarse correctamente."
done

BHTTP_BACKUP_DIR="/var/backups/bhttp-hex"
mkdir -p "$BHTTP_BACKUP_DIR" > /dev/null 2>&1
BHTTP_BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"
[[ -x /etc/bhttp/bin/bhttp-server ]] && cp -a /etc/bhttp/bin/bhttp-server "${BHTTP_BACKUP_DIR}/engine-${BHTTP_BACKUP_STAMP}" 2>/dev/null || true
[[ -x /etc/bhttp/bin/bhttp-server ]] && cp -a /etc/bhttp/bin/bhttp-server "${BHTTP_BACKUP_DIR}/engine.previous" 2>/dev/null || true
[[ -f /etc/systemd/system/bhttp-server.service ]] && cp -a /etc/systemd/system/bhttp-server.service "${BHTTP_BACKUP_DIR}/unit-${BHTTP_BACKUP_STAMP}" 2>/dev/null || true

systemctl stop bhttp-server > /dev/null 2>&1 || true

BHTTP_FILENAME="bhttp-server-v2.4.1-btun-compat-keepalive-linux-${BHTTP_ARCH}"
BHTTP_URL="https://raw.githubusercontent.com/JotchuaDevz/BHTTP-LIBS/refs/heads/main/${BHTTP_FILENAME}"

BHTTP_INSTALL_OK=0
ui_info "Descargando BHTTP: ${WHITE}${BHTTP_FILENAME}${NC}"
if curl -fsSL -o "/tmp/${BHTTP_FILENAME}" "$BHTTP_URL"; then
    chmod 755 "/tmp/${BHTTP_FILENAME}"
    if "/tmp/${BHTTP_FILENAME}" --self-test > /dev/null 2>&1; then
        install -m 755 "/tmp/${BHTTP_FILENAME}" /etc/bhttp/bin/bhttp-server
        BHTTP_INSTALL_OK=1
        ui_ok "Self-test BHP1 OK — motor instalado."
    else
        ui_aviso "El binario falló su self-test; se conserva el motor anterior."
    fi
    rm -f "/tmp/${BHTTP_FILENAME}"
else
    ui_error "Fallo al descargar BHTTP desde ${BHTTP_URL}"
fi

if [[ "$BHTTP_INSTALL_OK" -ne 1 && -x "${BHTTP_BACKUP_DIR}/engine.previous" ]]; then
    ui_aviso "Restaurando motor BHTTP anterior (rollback automático)..."
    cp -a "${BHTTP_BACKUP_DIR}/engine.previous" /etc/bhttp/bin/bhttp-server
    chmod 755 /etc/bhttp/bin/bhttp-server
fi

bhttp_mem_mb() { awk '/MemTotal:/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 1024; }
bhttp_adaptive_sessions() {
    local m; m="$(bhttp_mem_mb)"
    if [ "$m" -lt 768 ]; then echo 512
    elif [ "$m" -lt 1536 ]; then echo 1024
    elif [ "$m" -lt 3072 ]; then echo 2048
    elif [ "$m" -lt 6144 ]; then echo 4096
    else echo 8192
    fi
}
BHTTP_MAX_SESSIONS="$(bhttp_adaptive_sessions)"

BHTTP_SYSCTL_FILE="/etc/sysctl.d/bhttp-performance.conf"
bhttp_sysctl_supported() { sysctl -N "$1" >/dev/null 2>&1; }
bhttp_append_sysctl() { local key="$1" val="$2"; bhttp_sysctl_supported "$key" && printf '%s = %s\n' "$key" "$val" >> "$BHTTP_SYSCTL_FILE"; }

cat > "$BHTTP_SYSCTL_FILE" <<'EOF'
EOF
bhttp_append_sysctl fs.file-max 1048576
bhttp_append_sysctl net.core.somaxconn 16384
bhttp_append_sysctl net.core.netdev_max_backlog 16384
bhttp_append_sysctl net.core.rmem_max 16777216
bhttp_append_sysctl net.core.wmem_max 16777216
bhttp_append_sysctl net.ipv4.tcp_rmem "4096 131072 16777216"
bhttp_append_sysctl net.ipv4.tcp_wmem "4096 131072 16777216"
bhttp_append_sysctl net.ipv4.ip_local_port_range "10240 65535"
bhttp_append_sysctl net.ipv4.tcp_max_syn_backlog 16384
bhttp_append_sysctl net.ipv4.tcp_max_tw_buckets 262144
bhttp_append_sysctl net.ipv4.tcp_fin_timeout 15
bhttp_append_sysctl net.ipv4.tcp_tw_reuse 1
bhttp_append_sysctl net.ipv4.tcp_slow_start_after_idle 0
bhttp_append_sysctl net.ipv4.tcp_fastopen 3
bhttp_append_sysctl net.ipv4.tcp_keepalive_time 60
bhttp_append_sysctl net.ipv4.tcp_keepalive_intvl 15
bhttp_append_sysctl net.ipv4.tcp_keepalive_probes 4
bhttp_append_sysctl net.ipv4.tcp_mtu_probing 1

command -v modprobe >/dev/null 2>&1 && modprobe tcp_bbr >/dev/null 2>&1 || true
if bhttp_sysctl_supported net.core.default_qdisc; then bhttp_append_sysctl net.core.default_qdisc fq; fi
if bhttp_sysctl_supported net.ipv4.tcp_available_congestion_control && \
   sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
    bhttp_append_sysctl net.ipv4.tcp_congestion_control bbr
fi
sysctl -p "$BHTTP_SYSCTL_FILE" >/dev/null 2>&1 || true

cat > /etc/systemd/system/bhttp-server.service <<EOF
[Unit]
Description=BHTTP HEX AUTO (backend SSH interno) puerto 8180
After=network-online.target ssh.service sshd.service
Wants=network-online.target
StartLimitIntervalSec=0
[Service]
Type=simple
User=root
ExecStart=/etc/bhttp/bin/bhttp-server --listen 0.0.0.0 --port $BHTTP_PORT1 --backend-host 127.0.0.1 --backend-port $SSH_Port1 --session-ttl 180 --max-sessions $BHTTP_MAX_SESSIONS --request-timeout 30 --read-wait-ms 2 --sequence-wait 6 --max-requests-per-conn 2048
Restart=always
RestartSec=1
TimeoutStopSec=15
KillSignal=SIGTERM
LimitNOFILE=524288
LimitNPROC=131072
TasksMax=infinity
OOMScoreAdjust=-300
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload > /dev/null 2>&1
systemctl enable bhttp-server > /dev/null 2>&1
systemctl reset-failed bhttp-server > /dev/null 2>&1 || true
systemctl restart bhttp-server > /dev/null 2>&1

iptables -C INPUT -p tcp --dport $BHTTP_PORT1 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport $BHTTP_PORT1 -j ACCEPT > /dev/null 2>&1
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save > /dev/null 2>&1
elif command -v iptables-save >/dev/null 2>&1; then
    mkdir -p /etc/iptables > /dev/null 2>&1
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
fi

sleep 0.5
if systemctl is-active --quiet bhttp-server && ss -lnt 2>/dev/null | grep -q ":${BHTTP_PORT1}[[:space:]]"; then
    echo "BHTTP: activo y escuchando en :${BHTTP_PORT1} -> SSH 127.0.0.1:${SSH_Port1}"
else
    ui_error "BHTTP inactivo en :${BHTTP_PORT1}. Revisa: journalctl -u bhttp-server -n 50"
fi

}
install_bhttp_phase

fase "Protocolo HCR independiente (puerto ${HCR_PORT1})"

install_hcr_phase() {

mkdir -p /etc/hcr/bin > /dev/null 2>&1

case "$(uname -m)" in
    x86_64|amd64)   HCR_ARCH="amd64" ;;
    aarch64|arm64)  HCR_ARCH="arm64" ;;
    *)
        ui_aviso "Arquitectura no soportada para HCR: $(uname -m) (solo amd64/arm64). Fase omitida."
        return 1
        ;;
esac

if ss -lntp 2>/dev/null | grep -q ":${HCR_PORT1}[[:space:]]" && ! systemctl is-active --quiet hcr-server; then
    ui_aviso "Puerto ${HCR_PORT1} ocupado por otro servicio; no se modificó nada."
    ss -lntp 2>/dev/null | grep ":${HCR_PORT1}[[:space:]]"
    return 1
fi

for c in curl ss awk grep sed systemctl; do
    command -v "$c" >/dev/null 2>&1 || echo "Advertencia: falta el comando '$c', HCR podría no instalarse correctamente."
done

HCR_BACKUP_DIR="/var/backups/hcr-hex"
mkdir -p "$HCR_BACKUP_DIR" > /dev/null 2>&1
HCR_BACKUP_STAMP="$(date +%Y%m%d-%H%M%S)"
[[ -x /etc/hcr/bin/hcr-server ]] && cp -a /etc/hcr/bin/hcr-server "${HCR_BACKUP_DIR}/engine-${HCR_BACKUP_STAMP}" 2>/dev/null || true
[[ -x /etc/hcr/bin/hcr-server ]] && cp -a /etc/hcr/bin/hcr-server "${HCR_BACKUP_DIR}/engine.previous" 2>/dev/null || true
[[ -f /etc/systemd/system/hcr-server.service ]] && cp -a /etc/systemd/system/hcr-server.service "${HCR_BACKUP_DIR}/unit-${HCR_BACKUP_STAMP}" 2>/dev/null || true

systemctl stop hcr-server > /dev/null 2>&1 || true

HCR_FILENAME="hcr-server-linux-${HCR_ARCH}"
HCR_URL="https://raw.githubusercontent.com/JotchuaDevz/BHTTP-LIBS/refs/heads/main/${HCR_FILENAME}"

HCR_INSTALL_OK=0
if [[ -z "$HCR_URL" ]]; then
    ui_aviso "HCR_URL no está configurada; fase omitida (define el link de descarga)."
    return 1
fi

ui_info "Descargando HCR: ${WHITE}${HCR_FILENAME}${NC}"
if curl -fsSL -o "/tmp/${HCR_FILENAME}" "$HCR_URL"; then
    chmod 755 "/tmp/${HCR_FILENAME}"
    if "/tmp/${HCR_FILENAME}" --help > /dev/null 2>&1; then
        install -m 755 "/tmp/${HCR_FILENAME}" /etc/hcr/bin/hcr-server
        HCR_INSTALL_OK=1
        ui_ok "Binario HCR verificado — motor instalado."
    else
        ui_aviso "El binario falló su verificación; se conserva el motor anterior."
    fi
    rm -f "/tmp/${HCR_FILENAME}"
else
    ui_error "Fallo al descargar HCR desde ${HCR_URL}"
fi

if [[ "$HCR_INSTALL_OK" -ne 1 && -x "${HCR_BACKUP_DIR}/engine.previous" ]]; then
    ui_aviso "Restaurando motor HCR anterior (rollback automático)..."
    cp -a "${HCR_BACKUP_DIR}/engine.previous" /etc/hcr/bin/hcr-server
    chmod 755 /etc/hcr/bin/hcr-server
fi

cat > /etc/systemd/system/hcr-server.service <<EOF
[Unit]
Description=HCR TCP relay (backend SSH interno) puerto ${HCR_PORT1}
After=network-online.target ssh.service sshd.service
Wants=network-online.target
StartLimitIntervalSec=0
[Service]
Type=simple
User=root
ExecStart=/etc/hcr/bin/hcr-server --listen :${HCR_PORT1} --target 127.0.0.1:${SSH_Port1} --transport plain --max-download-frame 6144 --download-poll-timeout 8s --session-timeout 2m --session-stats-interval 0 --max-connections 2048 --max-sessions 32 --max-sessions-per-ip 16
Restart=on-failure
RestartSec=2s
LimitNOFILE=131072
NoNewPrivileges=true
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload > /dev/null 2>&1
systemctl enable hcr-server > /dev/null 2>&1
systemctl reset-failed hcr-server > /dev/null 2>&1 || true
systemctl restart hcr-server > /dev/null 2>&1

iptables -C INPUT -p tcp --dport $HCR_PORT1 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport $HCR_PORT1 -j ACCEPT > /dev/null 2>&1
if command -v netfilter-persistent >/dev/null 2>&1; then
    netfilter-persistent save > /dev/null 2>&1
elif command -v iptables-save >/dev/null 2>&1; then
    mkdir -p /etc/iptables > /dev/null 2>&1
    iptables-save > /etc/iptables/rules.v4 2>/dev/null
fi

sleep 0.5
if systemctl is-active --quiet hcr-server && ss -lnt 2>/dev/null | grep -q ":${HCR_PORT1}[[:space:]]"; then
    echo "HCR: activo y escuchando en :${HCR_PORT1} -> SSH 127.0.0.1:${SSH_Port1}"
else
    ui_error "HCR inactivo en :${HCR_PORT1}. Revisa: journalctl -u hcr-server -n 50"
fi

}
install_hcr_phase

fase "Enrutador HTTP/2 interno (HAProxy)"
cat <<'EOF_H2_ROUTER' > /etc/haproxy/haproxy.cfg
global
    log /dev/log local0
    maxconn 100000
    daemon

defaults
    log global
    mode tcp
    option dontlognull
    timeout connect 5s
    timeout client 1h
    timeout server 1h
    timeout tunnel 1h

frontend h2_internal_router
    bind 127.0.0.1:10444 accept-proxy proto h2
    mode http

    use_backend vless_grpc_h2 if { path_beg /grpc-svc/ }
    use_backend vmess_grpc_h2 if { path_beg /vmess-grpc-svc/ }
    use_backend vless_xhttp_h2 if { path_beg /xhttp }
    use_backend vmess_xhttp_h2 if { path_beg /vmess-xhttp }
    default_backend reject_h2

frontend public_ports_router
    bind 0.0.0.0:80
    bind 0.0.0.0:8080
    bind 0.0.0.0:8880
    bind 0.0.0.0:8081
    mode tcp

    tcp-request inspect-delay 10s
    tcp-request content accept if { req_ssl_hello_type 1 }
    tcp-request content accept if HTTP

    acl is_xhttp payload(0,400) -m sub /xhttp
    acl is_vmess_xhttp payload(0,400) -m sub /vmess-xhttp
    acl is_grpc payload(0,400) -m sub /grpc-svc/
    acl is_vmess_grpc payload(0,400) -m sub /vmess-grpc-svc/

    use_backend vless_xhttp_tcp if is_xhttp
    use_backend vmess_xhttp_tcp if is_vmess_xhttp
    use_backend vless_grpc_tcp if is_grpc
    use_backend vmess_grpc_tcp if is_vmess_grpc
    
    default_backend xray_plain_dispatcher

backend vless_grpc_h2
    mode http
    server xray 127.0.0.1:10006 send-proxy-v2 proto h2

backend vmess_grpc_h2
    mode http
    server xray 127.0.0.1:10012 send-proxy-v2 proto h2

backend vless_xhttp_h2
    mode http
    server xray 127.0.0.1:10004 send-proxy-v2 proto h2

backend vmess_xhttp_h2
    mode http
    server xray 127.0.0.1:10010 send-proxy-v2 proto h2

backend vless_grpc_tcp
    mode tcp
    server xray 127.0.0.1:10006 send-proxy-v2

backend vmess_grpc_tcp
    mode tcp
    server xray 127.0.0.1:10012 send-proxy-v2

backend vless_xhttp_tcp
    mode tcp
    server xray 127.0.0.1:10004 send-proxy-v2

backend vmess_xhttp_tcp
    mode tcp
    server xray 127.0.0.1:10010 send-proxy-v2

backend xray_plain_dispatcher
    mode tcp
    server xray 127.0.0.1:18080 send-proxy-v2

backend reject_h2
    mode http
    http-request return status 404
EOF_H2_ROUTER

if ! haproxy -c -f /etc/haproxy/haproxy.cfg > /dev/null 2>&1; then
echo -e "${RED}Internal HTTP/2 router validation failed.${NC}"
exit 1
fi
mkdir -p /etc/systemd/system/haproxy.service.d > /dev/null 2>&1
cat <<'EOF_H2_UNIT' > /etc/systemd/system/haproxy.service.d/xray-order.conf
[Unit]
After=xray.service network-online.target
Wants=xray.service network-online.target
EOF_H2_UNIT
systemctl daemon-reload > /dev/null 2>&1
systemctl enable haproxy > /dev/null 2>&1
systemctl restart haproxy > /dev/null 2>&1
fase "Tareas automáticas de expiración"
cat <<'EOF_EXP' > /usr/local/bin/exp-check
set -o pipefail
umask 077
now=$(date +%Y-%m-%d)
CONFIG="/etc/xray/config.json"
[ -s "$CONFIG" ] || exit 0
exec 9>/run/lock/xray-config.lock
flock -w 30 9 || { logger -t xray-exp "Timed out waiting for the Xray config lock"; exit 1; }
work_dir=$(mktemp -d /tmp/xray-exp.XXXXXX) || exit 1
trap 'rm -rf "$work_dir"' EXIT
mapfile -t expired_users < <(
for proto in vless vmess trojan; do
db="/etc/xray/${proto}.txt"
[ -f "$db" ] && awk -v d="$now" '$3 < d {print $1}' "$db"
done | sort -u
)
[ "${#expired_users[@]}" -gt 0 ] || exit 0
expired_json=$(printf '%s\n' "${expired_users[@]}" | jq -R . | jq -s .) || exit 1
jq --argjson expired "$expired_json" '
(.inbounds[] | select(((.settings.clients? // null) | type) == "array") | .settings.clients) |=
map(. as $client | select(($expired | index($client.email)) == null)) |
(.inbounds[] | select(((.settings.users? // null) | type) == "array") | .settings.users) |=
map(. as $user | select(($expired | index($user.email)) == null))
' "$CONFIG" > "$work_dir/config.json" || exit 1
if ! /usr/local/bin/xray run -test -config "$work_dir/config.json" >/dev/null 2>&1; then
logger -t xray-exp "Refusing expiry update: generated Xray config failed validation"
exit 1
fi
cp -p "$CONFIG" "$work_dir/config.backup" || exit 1
install -m 600 "$work_dir/config.json" "$CONFIG" || exit 1
if ! systemctl restart xray; then
install -m 600 "$work_dir/config.backup" "$CONFIG"
systemctl restart xray || true
logger -t xray-exp "Expiry update rolled back because Xray failed to restart"
exit 1
fi
for proto in vless vmess trojan; do
db="/etc/xray/${proto}.txt"
[ -f "$db" ] || continue
awk -v d="$now" '$3 >= d {print}' "$db" > "$work_dir/${proto}.txt" || exit 1
install -m 600 "$work_dir/${proto}.txt" "$db" || exit 1
done
EOF_EXP
chmod +x /usr/local/bin/exp-check > /dev/null 2>&1
echo "0 0 * * * root /usr/local/bin/exp-check >/dev/null 2>&1" > /etc/cron.d/xray-expiry
cat <<'EOF_HYST_EXP' > /usr/local/bin/hysteria-exp
now=$(date +%Y-%m-%d)
USER_DB="/etc/hysteria/users.txt"
CONFIG="/etc/hysteria/config.json"
changed=0
if [ -f "$USER_DB" ]; then
mapfile -t expired_users < <(awk -v d="$now" '$2 < d {print $1}' "$USER_DB")
for user in "${expired_users[@]}"; do
jq ".inbounds[0].users |= map(select(.auth_str != \"$user\"))" "$CONFIG" > /tmp/h.json && mv /tmp/h.json "$CONFIG"
sed -i "/^$user /d" "$USER_DB"
changed=1
done
if [ "$changed" -eq 1 ]; then
systemctl restart hysteria-server
fi
fi
EOF_HYST_EXP
chmod +x /usr/local/bin/hysteria-exp > /dev/null 2>&1
echo "0 0 * * * root /usr/local/bin/hysteria-exp >/dev/null 2>&1" > /etc/cron.d/hysteria-expiry
cat <<'EOF_HYST2_EXP' > /usr/local/bin/hysteria2-exp
now=$(date +%Y-%m-%d)
user_db="/etc/hysteria2/users.txt"
if [ -f "$user_db" ]; then
exec 9>/run/lock/hysteria2-config.lock
flock 9
awk -v d="$now" '$3 >= d' "$user_db" > "${user_db}.tmp" && mv "${user_db}.tmp" "$user_db"
fi
EOF_HYST2_EXP
chmod 755 /usr/local/bin/hysteria2-exp > /dev/null 2>&1
echo "5 0 * * * root /usr/local/bin/hysteria2-exp >/dev/null 2>&1" > /etc/cron.d/hysteria2-expiry
cat <<'EOF_ZIVPN_EXP' > /usr/local/bin/zivpn-exp
now=$(date +%Y-%m-%d)
ZIVPN_USER_DB="/etc/zivpn/users.txt"
ZIVPN_CONFIG="/etc/zivpn/config.json"
changed=0
if [ -f "$ZIVPN_USER_DB" ]; then
mapfile -t expired_users < <(awk '$2 < "'"$now"'" && ($3=="" || $3=="active") {print $1}' "$ZIVPN_USER_DB")
for user in "${expired_users[@]}"; do
jq --arg u "$user" '.auth.config |= map(select(. != $u))' "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
awk -v u="$user" 'BEGIN{OFS=" "} $1==u{$3="inactive"} {print}' "$ZIVPN_USER_DB" > /tmp/zdb.$$ && mv /tmp/zdb.$$ "$ZIVPN_USER_DB"
changed=1
done
if [ "$changed" -eq 1 ]; then
systemctl restart zivpn.service
fi
fi
EOF_ZIVPN_EXP
chmod +x /usr/local/bin/zivpn-exp > /dev/null 2>&1
echo "0 0 * * * root /usr/local/bin/zivpn-exp >/dev/null 2>&1" > /etc/cron.d/zivpn-expiry
fase "Nginx, Squid y monitor de servicios"
rm -rf /home/vps/public_html /etc/nginx/sites-* /etc/nginx/nginx.conf > /dev/null 2>&1; mkdir -p /home/vps/public_html > /dev/null 2>&1
cat <<'myNginxC' > /etc/nginx/nginx.conf
user www-data; worker_processes auto; pid /var/run/nginx.pid;
events { multi_accept on; worker_connections 8192; }
http { gzip on; gzip_vary on; gzip_comp_level 5; gzip_types text/plain application/x-javascript text/xml text/css; autoindex on; sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 65; types_hash_max_size 2048; server_tokens off; include /etc/nginx/mime.types; default_type application/octet-stream; access_log /var/log/nginx/access.log; error_log /var/log/nginx/error.log; client_max_body_size 32M; client_header_buffer_size 8m; large_client_header_buffers 8 8m; fastcgi_buffer_size 8m; fastcgi_buffers 8 8m; fastcgi_read_timeout 600; include /etc/nginx/conf.d/*.conf; }
myNginxC
cat <<'myvpsC' > /etc/nginx/conf.d/vps.conf
server { listen Nginx_Port; server_name 127.0.0.1 localhost; root /home/vps/public_html; location / { try_files $uri $uri/ /index.php?$args; } }
myvpsC
sed -i "s|Nginx_Port|$Nginx_Port|g" /etc/nginx/conf.d/vps.conf > /dev/null 2>&1
systemctl restart "$NGINX_SERVICE" > /dev/null 2>&1
rm -rf /etc/squid/squid.con* > /dev/null 2>&1
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
sed -i "s|IP-ADDRESS|$IPADDR|g" /etc/squid/squid.conf > /dev/null 2>&1; sed -i "s|Squid_Port1|$Squid_Port1|g" /etc/squid/squid.conf > /dev/null 2>&1; sed -i "s|Squid_Port2|$Squid_Port2|g" /etc/squid/squid.conf > /dev/null 2>&1
systemctl restart "$SQUID_SERVICE" > /dev/null 2>&1
mkdir -p /etc/deekayvpn/health > /dev/null 2>&1
cat <<'ServiceChecker' > /etc/deekayvpn/service_checker.sh
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
chmod 755 /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
sed -i "s|MYCHATID|$My_Chat_ID|g" /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
sed -i "s|MYBOTID|$My_Bot_Key|g" /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
sed -i "s|IPADDRESS|$IPADDR|g" /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
sed -i "s|STUNNELPORT|$Stunnel_Port_Num|g" /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
sed -i "s|SSLHPORT|$MainPort|g" /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
sed -i "s|SQUIDPORT1|$Squid_Port1|g" /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
sed -i "s|SQUIDPORT2|$Squid_Port2|g" /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
sed -i "s|NGINXPORT|$Nginx_Port|g" /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
sed -i "s|SSHPORT1|$SSH_Port1|g" /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
sed -i "s|SSHPORT2|$SSH_Port2|g" /etc/deekayvpn/service_checker.sh > /dev/null 2>&1
echo "*/3 * * * * root /bin/bash /etc/deekayvpn/service_checker.sh >/dev/null 2>&1" > /etc/cron.d/service-checker
mkdir -p /etc/deekayvpn > /dev/null 2>&1
touch /etc/deekayvpn/ssh_limits.txt > /dev/null 2>&1
cat <<'SSHLimitChecker' > /etc/deekayvpn/ssh_limit_checker.sh
DB="/etc/deekayvpn/ssh_limits.txt"
[ -s "$DB" ] || exit 0
while read -r suser slimit; do
[ -z "$suser" ] && continue
[[ "$slimit" =~ ^[0-9]+$ ]] || continue
[ "$slimit" -le 0 ] && continue
id "$suser" >/dev/null 2>&1 || continue
mapfile -t sessions < <(ps -u "$suser" -o pid=,etimes=,cmd= 2>/dev/null | awk '$0 ~ /sshd/ {print $1" "$2}')
count=${#sessions[@]}
[ "$count" -le "$slimit" ] && continue
excess=$((count - slimit))
mapfile -t sorted < <(printf '%s\n' "${sessions[@]}" | sort -k2,2n)
for ((i=0; i<excess; i++)); do
pid=$(awk '{print $1}' <<< "${sorted[$i]}")
[ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
done
done < "$DB"
SSHLimitChecker
chmod 755 /etc/deekayvpn/ssh_limit_checker.sh > /dev/null 2>&1
echo "* * * * * root /bin/bash /etc/deekayvpn/ssh_limit_checker.sh >/dev/null 2>&1" > /etc/cron.d/ssh-limit-checker
rm -f /etc/logrotate.d/rsyslog > /dev/null 2>&1
cat <<'logrotate' > /etc/logrotate.d/rsyslog
/var/log/syslog /var/log/kern.log /var/log/auth.log /var/log/xray/access.log /var/log/xray/error.log { rotate 7; daily; missingok; notifempty; compress; delaycompress; sharedscripts; postrotate; /usr/lib/rsyslog/rsyslog-rotate; endscript; }
logrotate
chown root:root /var/log > /dev/null 2>&1; chmod 755 /var/log > /dev/null 2>&1; chown syslog:adm /var/log/syslog > /dev/null 2>&1; chmod 640 /var/log/syslog > /dev/null 2>&1
echo "*/5 * * * * root /usr/sbin/logrotate -v -f /etc/logrotate.d/rsyslog >/dev/null 2>&1" > /etc/cron.d/logrotate
echo "0 3 * * * root sync; echo 3 > /proc/sys/vm/drop_caches" > /etc/cron.d/drop-cache
fase "Optimización de kernel, red y límites"
modprobe nf_conntrack 2>/dev/null || true; echo "nf_conntrack" > /etc/modules-load.d/freenet.conf
cat <<'SYSCTL' > /etc/sysctl.d/99-freenet-tuning.conf
fs.file-max = 1048576
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 16384
net.ipv4.ip_local_port_range = 1024 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 10
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_mtu_probing = 1
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
net.netfilter.nf_conntrack_udp_timeout = 60
SYSCTL
sysctl --system > /dev/null 2>&1 || true
mkdir -p /etc/security/limits.d > /dev/null 2>&1
cat <<'LIMITS' > /etc/security/limits.d/99-freenet.conf
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
LIMITS
fase "SlowDNS"
rm -rf /etc/slowdns > /dev/null 2>&1; mkdir -m 777 /etc/slowdns > /dev/null 2>&1
cat > /etc/slowdns/server.key << END
$Serverkey
END
cat > /etc/slowdns/server.pub << END
$Serverpub
END
usar_cache "sldns-server" /etc/slowdns/sldns-server "https://raw.githubusercontent.com/fisabiliyusri/SLDNS/main/slowdns/sldns-server"
chmod +x /etc/slowdns/server.key /etc/slowdns/server.pub /etc/slowdns/sldns-server > /dev/null 2>&1
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT > /dev/null 2>&1
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
systemctl daemon-reload > /dev/null 2>&1; systemctl enable server-sldns > /dev/null 2>&1; systemctl restart server-sldns > /dev/null 2>&1
fase "Cloudflare WARP y núcleo Hysteria v1"
instalar_warp() {
local codename
codename="$(lsb_release -cs 2>/dev/null)"
[ -z "$codename" ] && codename="${VERSION_CODENAME:-stable}"
curl -fsSL --connect-timeout 10 --max-time 60 https://pkg.cloudflareclient.com/pubkey.gpg \
| gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg > /dev/null 2>&1
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${codename} main" \
| tee /etc/apt/sources.list.d/cloudflare-client.list > /dev/null 2>&1
apt-get update \
-o Dir::Etc::sourcelist="sources.list.d/cloudflare-client.list" \
-o Dir::Etc::sourceparts="-" \
-o APT::Get::List-Cleanup="0" > /dev/null 2>&1
apt-get install "${APT_OPC[@]}" -qq cloudflare-warp > /dev/null 2>&1 || return 1
return 0
}
configurar_warp() {
warp-cli --accept-tos disconnect 2>/dev/null || true
warp-cli --accept-tos registration delete 2>/dev/null || true
warp-cli --accept-tos registration new 2>/dev/null || warp-cli --accept-tos register > /dev/null 2>&1
warp-cli --accept-tos mode proxy > /dev/null 2>&1
warp-cli --accept-tos proxy port 40000 > /dev/null 2>&1
warp-cli --accept-tos connect > /dev/null 2>&1
sleep 2
return 0
}
step "Instalando Cloudflare WARP" instalar_warp
step "Registrando y conectando WARP (proxy 40000)" configurar_warp
ARCH=$(uname -m)
case $ARCH in
x86_64)
SUFFIX="amd64"
;;
aarch64)
SUFFIX="arm64"
;;
armv7l|armv6l)
SUFFIX="armel"
;;
*)
echo -e "${RED}Arquitectura no soportada: $ARCH${NC}"
exit 1
;;
esac
esperar_descargas
usar_cache "sing-box-${SINGBOX_VER}-${SUFFIX}.deb" /tmp/sing-box.deb \
"https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VER}/sing-box_${SINGBOX_VER}_linux_${SUFFIX}.deb"
if [ ! -s /tmp/sing-box.deb ]; then
ui_error "${RED}No se pudo descargar el paquete sing-box para ${SUFFIX}${NC}"
exit 1
fi
dpkg -i /tmp/sing-box.deb > /dev/null 2>&1
apt-mark hold sing-box > /dev/null 2>&1
rm -f /tmp/sing-box.deb > /dev/null 2>&1
mkdir -p /etc/hysteria > /dev/null 2>&1
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
chmod 755 /etc/hysteria/config.json /etc/hysteria/hysteria.crt /etc/hysteria/hysteria.key > /dev/null 2>&1
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
systemctl daemon-reload > /dev/null 2>&1; systemctl enable hysteria-server.service > /dev/null 2>&1; systemctl start hysteria-server.service > /dev/null 2>&1
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
systemctl daemon-reload > /dev/null 2>&1; systemctl enable hysteria-nat.service > /dev/null 2>&1; systemctl start hysteria-nat.service > /dev/null 2>&1
HYSTERIA2_VER="app/v2.9.3"
case "$(uname -m)" in
x86_64|amd64) HYSTERIA2_ASSET="hysteria-linux-amd64" ;;
i386|i486|i586|i686) HYSTERIA2_ASSET="hysteria-linux-386" ;;
aarch64|arm64) HYSTERIA2_ASSET="hysteria-linux-arm64" ;;
armv7l|armv7*) HYSTERIA2_ASSET="hysteria-linux-arm" ;;
*) echo "Unsupported Hysteria 2 architecture: $(uname -m)"; exit 1 ;;
esac
HYSTERIA2_RELEASE_URL="https://github.com/apernet/hysteria/releases/download/${HYSTERIA2_VER}"
fase "Núcleo Hysteria 2"
hyst2_tmp=$(mktemp -d /tmp/hysteria2-install.XXXXXX) || exit 1
HYST2_CACHE="${HYSTERIA2_VER//\//-}"
descargar_hysteria2() {
usar_cache "hysteria2-${HYST2_CACHE}-${HYSTERIA2_ASSET}" "$hyst2_tmp/$HYSTERIA2_ASSET" \
"$HYSTERIA2_RELEASE_URL/$HYSTERIA2_ASSET" || return 1
usar_cache "hysteria2-${HYST2_CACHE}-hashes.txt" "$hyst2_tmp/hashes.txt" \
"$HYSTERIA2_RELEASE_URL/hashes.txt" || return 1
[ -s "$hyst2_tmp/$HYSTERIA2_ASSET" ] && [ -s "$hyst2_tmp/hashes.txt" ]
}
esperar_descargas
if ! descargar_hysteria2; then
rm -rf "$hyst2_tmp"
ui_error "${RED}Falló la descarga de Hysteria 2.${NC}"
exit 1
fi
hyst2_expected=$(awk -v asset="$HYSTERIA2_ASSET" '$2 == asset || $2 == "build/" asset || $2 == "*" asset {print tolower($1); exit}' "$hyst2_tmp/hashes.txt")
hyst2_actual=$(sha256sum "$hyst2_tmp/$HYSTERIA2_ASSET" | awk '{print tolower($1)}')
if [ -z "$hyst2_expected" ] || [ "$hyst2_actual" != "$hyst2_expected" ]; then
rm -f "$CACHE_DESCARGAS/hysteria2-${HYST2_CACHE}-${HYSTERIA2_ASSET}" "$CACHE_DESCARGAS/hysteria2-${HYST2_CACHE}-hashes.txt" 2>/dev/null
if descargar_hysteria2; then
hyst2_expected=$(awk -v asset="$HYSTERIA2_ASSET" '$2 == asset || $2 == "build/" asset || $2 == "*" asset {print tolower($1); exit}' "$hyst2_tmp/hashes.txt")
hyst2_actual=$(sha256sum "$hyst2_tmp/$HYSTERIA2_ASSET" | awk '{print tolower($1)}')
fi
fi
if [ -z "$hyst2_expected" ] || [ "$hyst2_actual" != "$hyst2_expected" ]; then
rm -rf "$hyst2_tmp"
ui_error "${RED}Verificación SHA-256 de Hysteria 2 fallida.${NC}"
exit 1
fi
install -m 755 "$hyst2_tmp/$HYSTERIA2_ASSET" /usr/local/bin/hysteria2 > /dev/null 2>&1
rm -rf "$hyst2_tmp" > /dev/null 2>&1
mkdir -p /etc/hysteria2 > /dev/null 2>&1
mkdir -p /usr/local/libexec > /dev/null 2>&1
cat <<'EOF_HYST2_AUTH' > /usr/local/libexec/hysteria2-auth
user_db="/etc/hysteria2/users.txt"
auth="$2"
[ -n "$auth" ] && [ -r "$user_db" ] || exit 1
awk -v token="$auth" '$2 == token {print $1; found=1; exit} END {exit !found}' "$user_db"
EOF_HYST2_AUTH
chmod 700 /usr/local/libexec/hysteria2-auth > /dev/null 2>&1
HYST2_INITIAL_TOKEN=$(cat /proc/sys/kernel/random/uuid)
jq -n \
--arg listen ":$HYST2_PORT" \
--arg cert "/etc/xray/xray.crt" \
--arg key "/etc/xray/xray.key" \
--arg obfs "$OBFS" '
{
listen: $listen,
tls: {cert: $cert, key: $key},
auth: {type: "command", command: "/usr/local/libexec/hysteria2-auth"},
obfs: {type: "salamander", salamander: {password: $obfs}},
masquerade: {
type: "proxy",
proxy: {url: "https://www.microsoft.com/", rewriteHost: true}
}
}
' > /etc/hysteria2/config.json
chmod 600 /etc/hysteria2/config.json > /dev/null 2>&1
printf 'default %s %s\n' "$HYST2_INITIAL_TOKEN" "$(date -d '+365 days' +%Y-%m-%d)" > /etc/hysteria2/users.txt
chmod 600 /etc/hysteria2/users.txt > /dev/null 2>&1
cat <<'EOF_HYST2_SERVICE' > /etc/systemd/system/hysteria2-server.service
[Unit]
Description=Official Hysteria 2 Server
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/hysteria2 server --config /etc/hysteria2/config.json
Restart=on-failure
RestartSec=2s
LimitNOFILE=1048576
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
ReadOnlyPaths=/etc/xray/xray.crt /etc/xray/xray.key
ReadWritePaths=/etc/hysteria2
[Install]
WantedBy=multi-user.target
EOF_HYST2_SERVICE
iptables -C INPUT -p udp --dport "$HYST2_PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport "$HYST2_PORT" -j ACCEPT > /dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1 || true
systemctl daemon-reload > /dev/null 2>&1
systemctl enable hysteria2-server.service > /dev/null 2>&1
if ! systemctl restart hysteria2-server.service > /dev/null 2>&1; then
journalctl -u hysteria2-server -n 50 --no-pager
echo -e "${RED}Hysteria 2 failed to start.${NC}"
exit 1
fi
fase "Arranque persistente y reglas NAT"
cat <<'deekayz' > /etc/deekaystartup
ln -fs /usr/share/zoneinfo/MyTimeZone /etc/localtime
export DEBIAN_FRONTEND=noninteractive
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
echo "nameserver DNS1" > /etc/resolv.conf; echo "nameserver DNS2" >> /etc/resolv.conf
mkdir -p /var/run/sslh; touch /var/run/sslh/sslh.pid; chmod 777 /var/run/sslh/sslh.pid
iptables -C INPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 53 -j ACCEPT
iptables -t nat -C PREROUTING -p udp --dport 53 -j ACCEPT 2>/dev/null || iptables -t nat -I PREROUTING 1 -p udp --dport 53 -j ACCEPT
iptables -t nat -C PREROUTING -p udp --dport 36713 -j ACCEPT 2>/dev/null || iptables -t nat -I PREROUTING 1 -p udp --dport 36713 -j ACCEPT
iptables -t nat -C PREROUTING -p udp --dport 443 -j ACCEPT 2>/dev/null || iptables -t nat -I PREROUTING 1 -p udp --dport 443 -j ACCEPT
IFACE=$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)
iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712 2>/dev/null || iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 20000:50000 -j DNAT --to-destination :36712
deekayz
sed -i "s|MyTimeZone|$MyVPS_Time|g" /etc/deekaystartup > /dev/null 2>&1
sed -i "s|DNS1|$Dns_1|g" /etc/deekaystartup > /dev/null 2>&1
sed -i "s|DNS2|$Dns_2|g" /etc/deekaystartup > /dev/null 2>&1
cat <<'deekayx' > /etc/systemd/system/deekaystartup.service
[Unit]
Description=Custom startup script
ConditionPathExists=/etc/deekaystartup
Before=sslh.service stunnel4.service hysteria2-server.service xray.service
[Service]
Type=oneshot
ExecStart=/etc/deekaystartup
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
deekayx
chmod +x /etc/deekaystartup > /dev/null 2>&1; systemctl enable deekaystartup > /dev/null 2>&1
instalar_udp() {
if [ "$(getconf LONG_BIT)" = "64" ]; then
usar_cache "badvpn-udpgw" /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/jo6qznzwbsf1xhi/badvpn-udpgw64"
else
usar_cache "badvpn-udpgw" /usr/bin/badvpn-udpgw "https://www.dropbox.com/s/8gemt9c6k1fph26/badvpn-udpgw"
fi
chmod +x /usr/bin/badvpn-udpgw > /dev/null 2>&1
cat <<'deekayb' > /etc/systemd/system/badvpn.service
[Unit]
Description=badvpn tun2socks service
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --loglevel none --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10
[Install]
WantedBy=multi-user.target
deekayb
systemctl enable badvpn > /dev/null 2>&1; systemctl start badvpn > /dev/null 2>&1
mkdir -p /root/udp > /dev/null 2>&1
ARCH=$(uname -m)
case $ARCH in
x86_64)
URL="https://raw.githubusercontent.com/mahpud896/UDP-Custom/main/bin/udp-custom-linux-amd64"
;;
aarch64)
URL="https://raw.githubusercontent.com/powermx/udp-custom-arm64/main/udp-custom-linux-arm64"
;;
armv7l|armv6l)
echo -e "${YELLOW}Arquitectura ARM32 no soportada oficialmente, omitiendo...${NC}"
URL=""
exit 1
;;
*)
echo -e "${RED}Arquitectura no soportada: $ARCH${NC}"
URL=""
exit 1
;;
esac
if [ -n "$URL" ]; then
usar_cache "udp-custom-${ARCH}" /root/udp/udp-custom "$URL" || true
if [ -s /root/udp/udp-custom ]; then
chmod +x /root/udp/udp-custom 2>/dev/null || true
echo -e "${GREEN}✓ UDP-Custom descargado para ${ARCH}${NC}"
else
echo -e "${RED}✗ Falló la descarga de UDP-Custom${NC}"
exit 1
fi
fi
usar_cache "udp-custom-config.json" /root/udp/config.json "https://raw.githubusercontent.com/mahpud896/UDP-Custom/main/config/config.json" || true
sed -i "s/\":36712\"/\":36717\"/g" /root/udp/config.json 2>/dev/null || true
chmod 644 /root/udp/config.json 2>/dev/null || true
cat > /etc/systemd/system/udp-custom.service <<EOF
[Unit]
Description=UDP Custom Proxy
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/root/udp
ExecStart=/root/udp/udp-custom server -c /root/udp/config.json
Restart=always
RestartSec=2s
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload > /dev/null 2>&1; systemctl enable udp-custom > /dev/null 2>&1; systemctl start udp-custom 2>/dev/null || true
}
fase "BadVPN, UDP Custom y ZiVPN"
esperar_descargas
step "Instalando UDP Custom..." instalar_udp
instalar_zivpn_bin() {
mkdir -p /etc/zivpn > /dev/null 2>&1
ARCH=$(uname -m)
case $ARCH in
x86_64)  SUFFIX="amd64" ;;
aarch64) SUFFIX="arm64" ;;
armv7l|armv6l) SUFFIX="arm" ;;
*)       SUFFIX=""; echo -e "${RED}Arquitectura no soportada: $ARCH${NC}" ;;
esac
if [ -n "$SUFFIX" ]; then
usar_cache "zivpn-1.4.9-${SUFFIX}" /usr/local/bin/zivpn "https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-${SUFFIX}" || true
chmod +x /usr/local/bin/zivpn 2>/dev/null || true
if [ -s /usr/local/bin/zivpn ]; then
echo -e "${GREEN}✓ ZIVPN instalado para ${ARCH}${NC}"
else
echo -e "${RED}✗ Falló la descarga de ZIVPN${NC}"
exit 1
fi
fi
cp /etc/hysteria/hysteria.crt /etc/zivpn/zivpn.crt 2>/dev/null || true
cp /etc/hysteria/hysteria.key /etc/zivpn/zivpn.key 2>/dev/null || true
chmod 644 /etc/zivpn/zivpn.crt /etc/zivpn/zivpn.key 2>/dev/null || true
cat > /etc/zivpn/config.json <<EOF
{
"listen": ":5667",
"cert": "/etc/zivpn/zivpn.crt",
"key": "/etc/zivpn/zivpn.key",
"obfs": "zivpn",
"auth": {
"mode": "passwords",
"config": ["$PASSWORD"]
}
}
EOF
chmod 644 /etc/zivpn/config.json > /dev/null 2>&1
echo "$PASSWORD $(date -d "+365 days" +"%Y-%m-%d") active" > /etc/zivpn/users.txt
cat > /etc/systemd/system/zivpn.service <<EOF
[Unit]
Description=zivpn VPN Server
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=always
RestartSec=3
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true
LimitNOFILE=1048576
[Install]
WantedBy=multi-user.target
EOF
cat > /etc/systemd/system/zivpn-nat.service <<EOF
[Unit]
Description=Restore ZiVPN UDP NAT rules
After=network-online.target
Wants=network-online.target
Before=zivpn.service
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'IFACE=\$(ip -4 route ls|grep default|grep -Po "(?<=dev )(\\\\S+)"|head -1); [ -n "\$IFACE" ] && (iptables -t nat -C PREROUTING -i "\$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null || iptables -t nat -A PREROUTING -i "\$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667)'
ExecStart=/bin/bash -c 'iptables -C INPUT -p udp --dport 5667 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 5667 -j ACCEPT'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload > /dev/null 2>&1; systemctl enable zivpn.service > /dev/null 2>&1; systemctl start zivpn.service 2>/dev/null || true
systemctl enable zivpn-nat.service > /dev/null 2>&1; systemctl start zivpn-nat.service 2>/dev/null || true
}
step "Instalando ZiVPN..." instalar_zivpn_bin
IFACE="$(ip -4 route ls|grep default|grep -Po '(?<=dev )(\S+)'|head -1)"
vnstat -u -i "$IFACE" 2>/dev/null || true
systemctl enable vnstat > /dev/null 2>&1
systemctl restart vnstat > /dev/null 2>&1
fase "Menú de administración"
mkdir -p /usr/local/bin > /dev/null 2>&1
sed -i '/# HEXTUNNEL_MENU_AUTOSTART_START/,/# HEXTUNNEL_MENU_AUTOSTART_END/d' ~/.bashrc 2>/dev/null || true
cat >> ~/.bashrc <<'EOF_BASHRC_AUTOSTART'
if [[ $- == *i* ]] && [ -z "$HEXTUNNEL_MENU_SHOWN" ]; then
export HEXTUNNEL_MENU_SHOWN=1
menu
fi
EOF_BASHRC_AUTOSTART
cat > /usr/local/bin/menu <<'EOF_MENU'
if [ -f /etc/xray/cert_type ] && grep -q "letsencrypt" /etc/xray/cert_type; then
XRAY_INSECURE="0"
else
XRAY_INSECURE="1"
fi
if [ "$XRAY_INSECURE" = "1" ]; then
INSECURE_PARAM="&allowInsecure=1"
else
INSECURE_PARAM=""
fi
RED='\033[38;5;203m'
GREEN='\033[38;5;84m'
YELLOW='\033[38;5;221m'
BLUE='\033[38;5;39m'
CYAN='\033[38;5;51m'
MAGENTA='\033[38;5;177m'
WHITE='\033[38;5;255m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
BG_TITLE='\033[48;5;24m\033[97m\033[1m'
BG_SEL='\033[48;5;23m\033[38;5;122m\033[1m'
ACC='\033[38;5;44m'
ACC2='\033[38;5;81m'
ACC3='\033[38;5;117m'
VIOLETA='\033[38;5;141m'
ROSA='\033[38;5;212m'
NARANJA='\033[38;5;215m'
GRIS='\033[38;5;245m'
GRIS2='\033[38;5;240m'
OKC='\033[38;5;84m'
M_ANCHO=63
M_LD="$(printf '═%.0s' $(seq 1 $M_ANCHO))"
M_LS="$(printf '─%.0s' $(seq 1 $M_ANCHO))"
LOCALE_UTF8=0
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
*UTF-8*|*utf-8*|*UTF8*|*utf8*) LOCALE_UTF8=1 ;;
esac
if [ "$LOCALE_UTF8" -eq 0 ] && locale -a 2>/dev/null | grep -qi '^C\.utf-\?8$'; then
export LC_ALL=C.UTF-8
LOCALE_UTF8=1
fi
m_plano() { printf '%b' "$1" | sed -e 's/\x1b\[[0-9;]*m//g'; }
m_vis() {
local t; t="$(m_plano "$1")"
if [ "$LOCALE_UTF8" -eq 1 ]; then
printf '%s' "${#t}"
else
printf '%s' "$(printf '%s' "$t" | LC_ALL=C tr -d '\200-\277' | LC_ALL=C wc -c | tr -d ' ')"
fi
}
m_pad() {
local t="$1" a="$2" v r
v=$(m_vis "$t"); r=$(( a - v )); [ "$r" -lt 0 ] && r=0
printf '%s%*s' "$t" "$r" ""
}
m_top()   { printf "${ACC}╔%s╗${NC}\n" "$M_LD"; }
m_sep()   { printf "${ACC}╠%s╣${NC}\n" "$M_LS"; }
m_bot()   { printf "${ACC}╚%s╝${NC}\n" "$M_LD"; }
m_div()   { printf "${ACC}%s${NC}\n" "$M_LS"; }
m_fila() {
local t="$1" v r
v=$(m_vis "$t"); r=$(( M_ANCHO - 2 - v )); [ "$r" -lt 0 ] && r=0
printf "${ACC}║${NC} %b%*s ${ACC}║${NC}\n" "$t" "$r" ""
}
m_titulo() {
local t="$1" v i d
v=$(m_vis "$t"); i=$(( (M_ANCHO - v) / 2 )); [ "$i" -lt 0 ] && i=0
d=$(( M_ANCHO - v - i )); [ "$d" -lt 0 ] && d=0
printf "${ACC}║${NC}%*s%b%*s${ACC}║${NC}\n" "$i" "" "$t" "$d" ""
}
m_encabezado() { m_top; m_titulo "$1"; m_bot; }
m_opcion()  { m_fila "${GRIS2}[${NC}${ACC2}${BOLD}$1${NC}${GRIS2}]${NC} ${WHITE}$2${NC}"; }
m_opcion2() {
printf "${ACC}║${NC} ${GRIS2}[${NC}${ACC2}${BOLD}%s${NC}${GRIS2}]${NC} ${WHITE}%s${NC} ${GRIS2}│${NC} ${GRIS2}[${NC}${ACC2}${BOLD}%s${NC}${GRIS2}]${NC} ${WHITE}%s${NC} ${ACC}║${NC}\n" \
"$1" "$(m_pad "$2" 24)" "$3" "$(m_pad "$4" 24)"
}
m_par() {
printf "${ACC}║${NC}  ${GRIS}%s${NC}${OKC}%s${NC}${ACC}│${NC}  ${GRIS}%s${NC}${OKC}%s${NC}${ACC}║${NC}\n" \
"$(m_pad "$1" 12)" "$(m_pad "$2" 17)" "$(m_pad "$3" 12)" "$(m_pad "$4" 17)"
}
DOMAIN=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || curl -4 -s --max-time 2 ipv4.icanhazip.com)
HYST_CONFIG="/etc/hysteria/config.json"
HYST_USER_DB="/etc/hysteria/users.txt"
touch "$HYST_USER_DB" 2>/dev/null || true
HYST2_CONFIG="/etc/hysteria2/config.json"
HYST2_USER_DB="/etc/hysteria2/users.txt"
HYST2_PORT="${HYST2_PORT:-36713}"
touch "$HYST2_USER_DB" 2>/dev/null || true
ZIVPN_CONFIG="/etc/zivpn/config.json"
ZIVPN_USER_DB="/etc/zivpn/users.txt"
SSH_LIMIT_DB="/etc/deekayvpn/ssh_limits.txt"
mkdir -p /etc/deekayvpn 2>/dev/null || true
touch "$SSH_LIMIT_DB" 2>/dev/null || true
TOKEN_PASS_DB="/etc/deekayvpn/token_password.txt"
TOKEN_USERS_DB="/etc/deekayvpn/token_users.txt"
touch "$TOKEN_USERS_DB" 2>/dev/null || true
server_ip() { curl -4 -s --max-time 2 ipv4.icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}'; }
cpu_count() { nproc 2>/dev/null || echo "1"; }
mem_stats() { free -h 2>/dev/null | awk '/Mem:/ {print $2 "|" $7 "|" $3}'; }
ram_percent() { free 2>/dev/null | awk '/Mem:/ { if ($2>0) printf "%.1f%%", ($3/$2)*100; else print "0.0%" }'; }
cpu_percent() { top -bn1 2>/dev/null | awk -F',' '/Cpu\(s\)/ { gsub("%us","",$1); gsub(" ","",$1); split($1,a,":"); if (a[2] == "") print "0.0%"; else printf "%.1f%%", a[2]+0 }'; }
buffer_mem() { free -m 2>/dev/null | awk '/Mem:/ {print $6 "M"}'; }
server_status() {
local ok=0
for s in ssh stunnel4 squid nginx server-sldns hysteria-server hysteria2-server ws-proxy@10080 xray; do
systemctl is-active --quiet "$s" 2>/dev/null && ok=$((ok+1))
done
[ "$ok" -ge 4 ] && echo -e "${GREEN}EN LÍNEA${NC}" || echo -e "${RED}PROBLEMAS DETECTADOS${NC}"
}
pause_return() { echo -e "\n  ${GRIS2}────────────────────────────────────────${NC}"; echo -e "  ${ACC2}↵${NC} ${GRIS}Presiona ENTER para volver...${NC}"; read -r _; }
add_zivpn() {
clear
m_encabezado "${BOLD}CREAR USUARIO ZIVPN${NC}"
echo -e -n " ${WHITE}Ingresa Contraseña:${NC} "; read -r new_pass
if grep -qw "^$new_pass" "$ZIVPN_USER_DB" 2>/dev/null; then
echo -e "\n${RED}Error: Contraseña ya existe!${NC}"
pause_return; return
fi
echo -e -n " ${WHITE}Validez (Dias):${NC} "; read -r days
if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Numero Invalido.${NC}"; pause_return; return; fi
exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
jq ".auth.config += [\"$new_pass\"]" "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
echo "$new_pass $exp_date active" >> "$ZIVPN_USER_DB"
systemctl restart zivpn.service
OBFS_VAL=$(jq -r '.obfs' "$ZIVPN_CONFIG" 2>/dev/null || echo "zivpn")
echo -e "\n${GREEN}✓ Usuario creado exitosamente!${NC}"
m_div
echo -e " ${BOLD}IP:${NC}          ${YELLOW}$(server_ip)${NC}"
echo -e " ${BOLD}Dominio:${NC}      ${YELLOW}${DOMAIN:-$(server_ip)}${NC}"
echo -e " ${BOLD}Puerto De Rango:${NC}  ${YELLOW}6000-19999${NC}"
echo -e " ${BOLD}Usuario (Contraseña):${NC} ${YELLOW}${new_pass}${NC}"
echo -e " ${BOLD}Obfuscación (obfs):${NC} ${YELLOW}${OBFS_VAL}${NC}"
echo -e " ${BOLD}Fecha de Expiración:${NC} ${YELLOW}${exp_date}${NC}"
m_div
pause_return
}
del_zivpn() {
clear
echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
echo -e "                 ${BOLD}ELIMINAR USUARIO ZIVPN${NC}"
echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "${YELLOW}No Hay Usuarios.${NC}"; pause_return; return; fi
cat -n "$ZIVPN_USER_DB" | awk '{printf "  \033[38;5;240m[\033[38;5;81m%s\033[38;5;240m]\033[0m \033[38;5;245mUser\033[0m \033[38;5;255m%-18s\033[0m \033[38;5;245mExp\033[0m \033[38;5;221m%-12s\033[0m \033[38;5;245mEstado\033[0m \033[38;5;84m%s\033[0m\n", $1, $2, $3, ($4==""?"active":$4)}'
echo ""
echo -e -n " ${WHITE}Ingrese el número de ID del usuario a eliminar:${NC} "; read -r del_id
if ! [[ "$del_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID inválido.${NC}"; pause_return; return; fi
del_pass=$(sed -n "${del_id}p" "$ZIVPN_USER_DB" | awk '{print $1}')
if [ -z "$del_pass" ]; then echo -e "${RED}ID no encontrado.${NC}"; pause_return; return; fi
jq --arg p "$del_pass" '.auth.config |= map(select(. != $p))' "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
sed -i "${del_id}d" "$ZIVPN_USER_DB"
systemctl restart zivpn.service
echo -e "\n${GREEN}✓ Usuario '$del_pass' eliminado exitosamente!${NC}"
pause_return
}
activar_zivpn() {
clear
m_encabezado "${BOLD}ACTIVAR USUARIO ZIVPN${NC}"
if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "${YELLOW}No Hay Usuarios.${NC}"; pause_return; return; fi
cat -n "$ZIVPN_USER_DB" | awk '{printf "  \033[38;5;240m[\033[38;5;81m%s\033[38;5;240m]\033[0m \033[38;5;245mUser\033[0m \033[38;5;255m%-18s\033[0m \033[38;5;245mExp\033[0m \033[38;5;221m%-12s\033[0m \033[38;5;245mEstado\033[0m \033[38;5;84m%s\033[0m\n", $1, $2, $3, ($4==""?"active":$4)}'
echo ""
echo -e -n " ${WHITE}Ingrese el número de ID del usuario a activar:${NC} "; read -r act_id
if ! [[ "$act_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID inválido.${NC}"; pause_return; return; fi
act_pass=$(sed -n "${act_id}p" "$ZIVPN_USER_DB" | awk '{print $1}')
act_exp=$(sed -n "${act_id}p" "$ZIVPN_USER_DB" | awk '{print $2}')
if [ -z "$act_pass" ]; then echo -e "${RED}ID no encontrado.${NC}"; pause_return; return; fi
today=$(date +%Y-%m-%d)
if [ "$act_exp" \< "$today" ]; then
echo -e "\n${RED}✗ No se puede activar, la cuenta ya expiró (${act_exp}). Extiéndela primero.${NC}"
pause_return; return
fi
jq --arg p "$act_pass" '.auth.config |= ((. + [$p]) | unique)' "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
awk -v id="$act_id" 'BEGIN{OFS=" "} NR==id{$3="active"} {print}' "$ZIVPN_USER_DB" > /tmp/zdb.$$ && mv /tmp/zdb.$$ "$ZIVPN_USER_DB"
systemctl restart zivpn.service
echo -e "\n${GREEN}✓ Usuario '$act_pass' activado.${NC}"
pause_return
}
desactivar_zivpn() {
clear
m_encabezado "${BOLD}DESACTIVAR USUARIO ZIVPN${NC}"
if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "${YELLOW}No Hay Usuarios.${NC}"; pause_return; return; fi
cat -n "$ZIVPN_USER_DB" | awk '{printf "  \033[38;5;240m[\033[38;5;81m%s\033[38;5;240m]\033[0m \033[38;5;245mUser\033[0m \033[38;5;255m%-18s\033[0m \033[38;5;245mExp\033[0m \033[38;5;221m%-12s\033[0m \033[38;5;245mEstado\033[0m \033[38;5;84m%s\033[0m\n", $1, $2, $3, ($4==""?"active":$4)}'
echo ""
echo -e -n " ${WHITE}Ingrese el número de ID del usuario a desactivar:${NC} "; read -r deact_id
if ! [[ "$deact_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID inválido.${NC}"; pause_return; return; fi
deact_pass=$(sed -n "${deact_id}p" "$ZIVPN_USER_DB" | awk '{print $1}')
if [ -z "$deact_pass" ]; then echo -e "${RED}ID no encontrado.${NC}"; pause_return; return; fi
jq --arg p "$deact_pass" '.auth.config |= map(select(. != $p))' "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
awk -v id="$deact_id" 'BEGIN{OFS=" "} NR==id{$3="inactive"} {print}' "$ZIVPN_USER_DB" > /tmp/zdb.$$ && mv /tmp/zdb.$$ "$ZIVPN_USER_DB"
systemctl restart zivpn.service
echo -e "\n${GREEN}✓ Usuario '$deact_pass' desactivado (queda guardado, no se borró).${NC}"
pause_return
}
extend_zivpn() {
clear
m_encabezado "${BOLD}EXTENDER USUARIO ZIVPN${NC}"
if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "${YELLOW}Usuarios No Encontrados.${NC}"; pause_return; return; fi
cat -n "$ZIVPN_USER_DB" | awk '{printf "  \033[38;5;240m[\033[38;5;81m%s\033[38;5;240m]\033[0m \033[38;5;245mUser\033[0m \033[38;5;255m%-18s\033[0m \033[38;5;245mExp\033[0m \033[38;5;221m%-12s\033[0m \033[38;5;245mEstado\033[0m \033[38;5;84m%s\033[0m\n", $1, $2, $3, ($4==""?"active":$4)}'
echo ""
echo -e -n " ${WHITE}Ingrese el número de ID del usuario a extender:${NC} "; read -r ext_id
if ! [[ "$ext_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}Número de ID inválido.${NC}"; pause_return; return; fi
ext_pass=$(sed -n "${ext_id}p" "$ZIVPN_USER_DB" | awk '{print $1}')
current_exp=$(sed -n "${ext_id}p" "$ZIVPN_USER_DB" | awk '{print $2}')
if [ -z "$ext_pass" ]; then echo -e "${RED}ID No Encontrado.${NC}"; pause_return; return; fi
echo -e -n " ${WHITE}Agregar Validez (Dias):${NC} "; read -r days
if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Numero Invalido.${NC}"; pause_return; return; fi
new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
awk -v id="$ext_id" -v ne="$new_exp" 'BEGIN{OFS=" "} NR==id{$2=ne; $3="active"} {print}' "$ZIVPN_USER_DB" > /tmp/zdb.$$ && mv /tmp/zdb.$$ "$ZIVPN_USER_DB"
jq --arg p "$ext_pass" '.auth.config |= ((. + [$p]) | unique)' "$ZIVPN_CONFIG" > /tmp/z.json && mv /tmp/z.json "$ZIVPN_CONFIG"
systemctl restart zivpn.service
echo -e "\n${GREEN}✓ Usuario '$ext_pass' Extendido Exitosamente!${NC}\n New Expiry: ${YELLOW}$new_exp${NC}"
pause_return
}
list_zivpn() {
clear
m_encabezado "${BOLD}LISTA DE USUARIOS ZIVPN${NC}"
if [ ! -s "$ZIVPN_USER_DB" ]; then echo -e "\n ${YELLOW}No Hay Usuarios En Linea.${NC}\n"
else
printf " %-5s | %-25s | %-15s | %-10s\n" "ID" "PASSWORD" "EXPIRY DATE" "ESTADO"
m_div
cat -n "$ZIVPN_USER_DB" | while read -r num user exp status; do
status="${status:-active}"
[ "$status" = "active" ] && st_color="${GREEN}" || st_color="${RED}"
printf " [%-3s] | %-25s | %-15s | ${st_color}%-10s${NC}\n" "$num" "$user" "$exp" "$status"
done
m_div
echo -e " Total Usuarios       : ${YELLOW}$(wc -l < "$ZIVPN_USER_DB")${NC}"
echo -e " Total Activos        : ${GREEN}$(awk '{print ($3=="" || $3=="active")}' "$ZIVPN_USER_DB" | grep -c 1)${NC}"
fi
pause_return
}
add_hysteria() {
clear
m_encabezado "${BOLD}CREAR USUARIO HYSTERIA${NC}"
echo -e -n " ${WHITE}Ingresa Contraseña/Cadena de Auth:${NC} "; read -r new_pass
if grep -qw "^$new_pass" "$HYST_USER_DB" 2>/dev/null || jq -e ".inbounds[0].users[] | select(.auth_str == \"$new_pass\")" "$HYST_CONFIG" >/dev/null; then
echo -e "\n${RED}Error: ¡El usuario/contraseña ya existe!${NC}"
pause_return; return
fi
echo -e -n " ${WHITE}Validez (Días):${NC} "; read -r days
if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Número inválido.${NC}"; pause_return; return; fi
exp_date=$(date -d "+${days} days" +"%Y-%m-%d")
jq ".inbounds[0].users += [{\"auth_str\": \"$new_pass\"}]" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
echo "$new_pass $exp_date" >> "$HYST_USER_DB"
systemctl restart hysteria-server
OBFS_VAL=$(jq -r '.inbounds[0].obfs' "$HYST_CONFIG" 2>/dev/null || echo "HexTunnel")
echo -e "\n${GREEN}✓ ¡Usuario creado exitosamente!${NC}"
m_div
echo -e " ${BOLD}IP:${NC}          ${YELLOW}$(server_ip)${NC}"
echo -e " ${BOLD}Dominio:${NC}      ${YELLOW}${DOMAIN:-$(server_ip)}${NC}"
echo -e " ${BOLD}Rango de Puertos:${NC}  ${YELLOW}20000-50000 (-> 36712)${NC}"
echo -e " ${BOLD}Usuario (Contraseña):${NC} ${YELLOW}${new_pass}${NC}"
echo -e " ${BOLD}Obfs:${NC}        ${YELLOW}${OBFS_VAL}${NC}"
echo -e " ${BOLD}Fecha de Expiración:${NC} ${YELLOW}${exp_date}${NC}"
m_div
pause_return
}
del_hysteria() {
clear
echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
echo -e "                 ${BOLD}ELIMINAR USUARIO HYSTERIA${NC}"
echo -e "${RED}══════════════════════════════════════════════════════════════${NC}"
if [ ! -s "$HYST_USER_DB" ]; then echo -e "${YELLOW}No se encontraron usuarios.${NC}"; pause_return; return; fi
cat -n "$HYST_USER_DB" | awk '{printf "  \033[38;5;240m[\033[38;5;81m%s\033[38;5;240m]\033[0m \033[38;5;245mUser\033[0m \033[38;5;255m%-18s\033[0m \033[38;5;245mExp\033[0m \033[38;5;221m%s\033[0m\n", $1, $2, $3}'
echo ""
echo -e -n " ${WHITE}Ingresa el número de ID del usuario a eliminar:${NC} "; read -r del_id
if ! [[ "$del_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID inválido.${NC}"; pause_return; return; fi
del_pass=$(sed -n "${del_id}p" "$HYST_USER_DB" | awk '{print $1}')
if [ -z "$del_pass" ]; then echo -e "${RED}ID no encontrado.${NC}"; pause_return; return; fi
jq ".inbounds[0].users |= map(select(.auth_str != \"$del_pass\"))" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
sed -i "${del_id}d" "$HYST_USER_DB"
systemctl restart hysteria-server
echo -e "\n${GREEN}✓ ¡Usuario '$del_pass' eliminado exitosamente!${NC}"
pause_return
}
extend_hysteria() {
clear
m_encabezado "${BOLD}EXTENDER USUARIO HYSTERIA${NC}"
if [ ! -s "$HYST_USER_DB" ]; then echo -e "${YELLOW}No se encontraron usuarios.${NC}"; pause_return; return; fi
cat -n "$HYST_USER_DB" | awk '{printf "  \033[38;5;240m[\033[38;5;81m%s\033[38;5;240m]\033[0m \033[38;5;245mUser\033[0m \033[38;5;255m%-18s\033[0m \033[38;5;245mExp\033[0m \033[38;5;221m%s\033[0m\n", $1, $2, $3}'
echo ""
echo -e -n " ${WHITE}Ingresa el número de ID del usuario a extender:${NC} "; read -r ext_id
if ! [[ "$ext_id" =~ ^[0-9]+$ ]]; then echo -e "${RED}ID inválido.${NC}"; pause_return; return; fi
ext_pass=$(sed -n "${ext_id}p" "$HYST_USER_DB" | awk '{print $1}')
current_exp=$(sed -n "${ext_id}p" "$HYST_USER_DB" | awk '{print $2}')
if [ -z "$ext_pass" ]; then echo -e "${RED}ID no encontrado.${NC}"; pause_return; return; fi
echo -e -n " ${WHITE}Días a Agregar:${NC} "; read -r days
if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Número inválido.${NC}"; pause_return; return; fi
new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
sed -i "${ext_id}s/.*/$ext_pass $new_exp/" "$HYST_USER_DB"
echo -e "\n${GREEN}✓ ¡Usuario '$ext_pass' extendido exitosamente!${NC}\n Nueva Expiración: ${YELLOW}$new_exp${NC}"
pause_return
}
list_hysteria() {
clear
m_encabezado "${BOLD}LISTA DE USUARIOS HYSTERIA${NC}"
if [ ! -s "$HYST_USER_DB" ]; then echo -e "\n ${YELLOW}No se encontraron usuarios activos.${NC}\n"
else
printf " %-5s | %-25s | %-15s\n" "ID" "PASSWORD (AUTH STRING)" "EXPIRY DATE"
m_div
cat -n "$HYST_USER_DB" | while read -r num user exp; do
printf " [%-3s] | %-25s | %-15s\n" "$num" "$user" "$exp"
done
m_div
echo -e " Total de Usuarios Activos: ${YELLOW}$(wc -l < "$HYST_USER_DB")${NC}"
fi
pause_return
}
speed_hysteria() {
clear
m_encabezado "${BOLD}EDITAR VELOCIDADES SUBIDA/BAJADA${NC}"
current_up=$(jq -r '.inbounds[0].up_mbps' "$HYST_CONFIG" 2>/dev/null || echo "100")
current_down=$(jq -r '.inbounds[0].down_mbps' "$HYST_CONFIG" 2>/dev/null || echo "100")
echo -e " Subida Actual:    ${YELLOW}${current_up} Mbps${NC}"
echo -e " Bajada Actual:    ${YELLOW}${current_down} Mbps${NC}\n"
echo -e -n " ${WHITE}Ingresa Nueva Velocidad de Subida (Mbps):${NC} "; read -r new_up
echo -e -n " ${WHITE}Ingresa Nueva Velocidad de Bajada (Mbps):${NC} "; read -r new_down
if [[ "$new_up" =~ ^[0-9]+$ ]] && [[ "$new_down" =~ ^[0-9]+$ ]]; then
jq ".inbounds[0].up_mbps = $new_up | .inbounds[0].down_mbps = $new_down" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
systemctl restart hysteria-server
echo -e "\n${GREEN}✓ ¡Velocidades actualizadas exitosamente!${NC}"
else echo -e "\n${RED}Entrada inválida. Solo números.${NC}"; fi
pause_return
}
change_obfs_hysteria() {
clear
m_encabezado "${BOLD}CAMBIAR OBFS DE HYSTERIA${NC}"
current_obfs=$(jq -r '.inbounds[0].obfs' "$HYST_CONFIG" 2>/dev/null || echo "HexTunnel")
echo -e " Obfs Actual: ${YELLOW}${current_obfs}${NC}\n"
echo -e -n " ${WHITE}Ingresa Nuevo Obfs:${NC} "; read -r new_obfs
if [ -n "$new_obfs" ]; then
jq ".inbounds[0].obfs = \"$new_obfs\"" "$HYST_CONFIG" > /tmp/h.json && mv /tmp/h.json "$HYST_CONFIG"
systemctl restart hysteria-server
echo -e "\n${GREEN}✓ ¡Obfs actualizado exitosamente a: $new_obfs!${NC}"
else echo -e "\n${RED}Acción cancelada.${NC}"; fi
pause_return
}
print_hysteria2_link() {
local user="$1" token="$2" encoded_token encoded_obfs insecure
encoded_token=$(jq -nr --arg v "$token" '$v|@uri')
encoded_obfs=$(jq -nr --arg v "$(jq -r '.obfs.salamander.password' "$HYST2_CONFIG")" '$v|@uri')
insecure="1"
echo "hysteria2://${encoded_token}@${DOMAIN}:${HYST2_PORT}?insecure=${insecure}&sni=${DOMAIN}&obfs=salamander&obfs-password=${encoded_obfs}#${user}-HY2"
}
add_hysteria2() {
clear
m_encabezado "${BOLD}CREAR CUENTA HYSTERIA 2${NC}"
echo -e -n " ${WHITE}Usuario:${NC} "; read -r user
[[ "$user" =~ ^[A-Za-z0-9._-]+$ ]] || { echo -e "\n${RED}Usuario inválido.${NC}"; pause_return; return; }
if awk -v u="$user" '$1 == u {found=1} END {exit !found}' "$HYST2_USER_DB" 2>/dev/null; then
echo -e "\n${RED}El usuario ya existe.${NC}"; pause_return; return
fi
echo -e -n " ${WHITE}Validez (Días):${NC} "; read -r days
[[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo -e "\n${RED}Validez inválida.${NC}"; pause_return; return; }
echo -e -n " ${WHITE}¿Usar un token/UUID personalizado (ej. el mismo que ya usas en V2Ray)? (y/N):${NC} "; read -r custom_token_prompt
if [[ "$custom_token_prompt" =~ ^[Yy]$ ]]; then
echo -e -n " ${WHITE}Ingresa el token/UUID personalizado:${NC} "; read -r token
if [[ -z "$token" ]] || [[ "$token" =~ [[:space:]] ]]; then
echo -e "\n${RED}Token inválido: no puede estar vacío ni contener espacios.${NC}"; pause_return; return
fi
if awk -v t="$token" '$2 == t {found=1} END {exit !found}' "$HYST2_USER_DB" 2>/dev/null; then
echo -e "\n${RED}Ese token ya está en uso por otro usuario de Hysteria 2.${NC}"; pause_return; return
fi
else
token=$(cat /proc/sys/kernel/random/uuid)
fi
exp=$(date -d "+${days} days" +%Y-%m-%d)
printf '%s %s %s\n' "$user" "$token" "$exp" >> "$HYST2_USER_DB"
chmod 600 "$HYST2_USER_DB"
echo -e "\n${GREEN}✓ Cuenta Hysteria 2 creada.${NC}\nUsuario: $user\nToken: $token\nExpira: $exp\n"
print_hysteria2_link "$user" "$token"
pause_return
}
del_hysteria2() {
clear
m_encabezado "${BOLD}ELIMINAR USUARIO HYSTERIA 2${NC}"
[ -s "$HYST2_USER_DB" ] || { echo -e "${YELLOW}No se encontraron usuarios Hysteria 2.${NC}"; pause_return; return; }
nl -w2 -s'. ' "$HYST2_USER_DB"
echo -e -n " ${WHITE}ID de usuario a eliminar:${NC} "; read -r id
[[ "$id" =~ ^[0-9]+$ ]] || { echo -e "\n${RED}ID inválido.${NC}"; pause_return; return; }
user=$(sed -n "${id}p" "$HYST2_USER_DB" | awk '{print $1}')
[ -n "$user" ] || { echo -e "\n${RED}ID no encontrado.${NC}"; pause_return; return; }
sed -i "${id}d" "$HYST2_USER_DB"
echo -e "\n${GREEN}✓ Usuario Hysteria 2 '$user' eliminado.${NC}"
pause_return
}
extend_hysteria2() {
clear
m_encabezado "${BOLD}EXTENDER USUARIO HYSTERIA 2${NC}"
[ -s "$HYST2_USER_DB" ] || { echo -e "${YELLOW}No se encontraron usuarios Hysteria 2.${NC}"; pause_return; return; }
nl -w2 -s'. ' "$HYST2_USER_DB"
echo -e -n " ${WHITE}ID de usuario a renovar:${NC} "; read -r id
[[ "$id" =~ ^[0-9]+$ ]] || { echo -e "\n${RED}ID inválido.${NC}"; pause_return; return; }
line=$(sed -n "${id}p" "$HYST2_USER_DB")
user=$(awk '{print $1}' <<< "$line"); token=$(awk '{print $2}' <<< "$line"); old_exp=$(awk '{print $3}' <<< "$line")
[ -n "$user" ] || { echo -e "\n${RED}ID no encontrado.${NC}"; pause_return; return; }
echo -e -n " ${WHITE}Días a agregar:${NC} "; read -r days
[[ "$days" =~ ^[0-9]+$ ]] && [ "$days" -gt 0 ] || { echo -e "\n${RED}Validez inválida.${NC}"; pause_return; return; }
base="$old_exp"; [ "$old_exp" \< "$(date +%Y-%m-%d)" ] && base="$(date +%Y-%m-%d)"
new_exp=$(date -d "$base +${days} days" +%Y-%m-%d)
sed -i "${id}s/.*/$user $token $new_exp/" "$HYST2_USER_DB"
echo -e "\n${GREEN}✓ Usuario Hysteria 2 renovado hasta $new_exp.${NC}"
pause_return
}
list_hysteria2() {
clear
m_encabezado "${BOLD}LISTA DE USUARIOS HYSTERIA 2${NC}"
if [ -s "$HYST2_USER_DB" ]; then nl -w2 -s'. ' "$HYST2_USER_DB"; else echo -e "${YELLOW}No se encontraron usuarios.${NC}"; fi
pause_return
}
show_hysteria2() {
clear
m_encabezado "${BOLD}ENLACE HYSTERIA 2${NC}"
[ -s "$HYST2_USER_DB" ] || { echo -e "${YELLOW}No se encontraron usuarios Hysteria 2.${NC}"; pause_return; return; }
nl -w2 -s'. ' "$HYST2_USER_DB"
echo -e -n " ${WHITE}ID de usuario:${NC} "; read -r id
line=$(sed -n "${id}p" "$HYST2_USER_DB")
user=$(awk '{print $1}' <<< "$line"); token=$(awk '{print $2}' <<< "$line")
[ -n "$user" ] || { echo -e "\n${RED}ID no encontrado.${NC}"; pause_return; return; }
echo
print_hysteria2_link "$user" "$token"
pause_return
}
add_xray() {
clear
m_encabezado "${BOLD}CREAR CUENTA XRAY${NC}"
echo -e " [${YELLOW}1${NC}] VLESS (TCP, WS, XHTTP, HTTPUpgrade Y gRPC)"
echo -e " [${YELLOW}2${NC}] VMESS (TCP, WS, XHTTP, HTTPUpgrade Y gRPC)"
echo -e " [${YELLOW}3${NC}] TROJAN (TLS)"
echo -e " [${YELLOW}4${NC}] TODO-EN-UNO (VLESS + VMESS + TROJAN)"
echo -e -n " ${WHITE}Selecciona Protocolo:${NC} "; read -r prot
echo -e -n " ${WHITE}Nombre de usuario:${NC} "; read -r user
if grep -qw "^$user" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null; then
echo -e "${RED}¡El nombre de usuario ya existe!${NC}"; pause_return; return
fi
echo -e -n " ${WHITE}Validez (Días):${NC} "; read -r masa
exp=$(date -d "+${masa} days" +"%Y-%m-%d")
echo -e -n " ${WHITE}¿Quieres usar un UUID personalizado? (y/N):${NC} "; read -r custom_uuid_prompt
if [[ "$custom_uuid_prompt" =~ ^[Yy]$ ]]; then
echo -e -n " ${WHITE}Ingresa el UUID personalizado:${NC} "; read -r uuid
else
uuid=$(cat /proc/sys/kernel/random/uuid)
fi
pass="HexTunnel${uuid:0:6}"
VLESS_TAGS='["vless-tls-dispatcher","vless-tcp-http","vless-plain-public","vless-ws","vless-xhttp","vless-xhttp-80","vless-httpupgrade","vless-grpc","vless-grpc-ntls","vless-kcp-ntls"]'
VMESS_TAGS='["vmess-tcp-http","vmess-ws","vmess-xhttp","vmess-httpupgrade","vmess-grpc","vmess-grpc-ntls","vmess-kcp-ntls"]'
TROJAN_TAGS='["trojan-ws"]'
if [ "$prot" == "1" ]; then
jq --arg uuid "$uuid" --arg user "$user" --argjson tags "$VLESS_TAGS" \
'(.inbounds[] | select(.tag as $t | $tags | index($t)) | .settings.clients) += [{"id": $uuid, "email": $user}]' \
/etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
echo "$user $uuid $exp" >> /etc/xray/vless.txt
clear
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "                   ${BOLD}CUENTA VLESS CREADA${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "Usuario  : $user\nExpira   : $exp"
echo -e "\n${YELLOW}[ VLESS TLS / SHARED PORT 443 ]${NC}\n"
echo -e "TCP HTTP: vless://${uuid}@${DOMAIN}:443?type=tcp&headerType=http&security=tls&encryption=none&host=${DOMAIN}&path=%2Fvless-tcp&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-TCP"
echo -e "WS: vless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-WS"
echo -e "XHTTP: vless://${uuid}@${DOMAIN}:443?type=xhttp&security=tls&encryption=none&path=%2Fxhttp&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}&mode=auto&alpn=h2%2Chttp%2F1.1#${user}-VLESS-XHTTP"
echo -e "HTTPUp: vless://${uuid}@${DOMAIN}:443?type=httpupgrade&security=tls&encryption=none&path=%2Fhttpupgrade&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-HTTPUp"
echo -e "gRPC: vless://${uuid}@${DOMAIN}:443?type=grpc&security=tls&encryption=none&serviceName=grpc-svc&sni=${DOMAIN}${INSECURE_PARAM}&alpn=h2#${user}-VLESS-gRPC"
echo -e "${YELLOW}[ VLESS NTLS (80/8080/8880/8081) ]${NC}"
echo -e "TCP: vless://${uuid}@${DOMAIN}:80?type=tcp&headerType=http&security=none&encryption=none&path=%2Fvless-tcp&host=${DOMAIN}#${user}-VLESS-NTLS-TCP"
echo -e "WS: vless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}-VLESS-NTLS-WS"
echo -e "XHTTP: vless://${uuid}@${DOMAIN}:80?type=xhttp&security=none&encryption=none&path=%2Fxhttp&host=${DOMAIN}&mode=auto#${user}-VLESS-NTLS-XHTTP"
echo -e "HUP: vless://${uuid}@${DOMAIN}:80?type=httpupgrade&security=none&encryption=none&path=%2Fhttpupgrade&host=${DOMAIN}#${user}-VLESS-NTLS-HTTPUp"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
elif [ "$prot" == "2" ]; then
jq --arg uuid "$uuid" --arg user "$user" --argjson tags "$VMESS_TAGS" \
'(.inbounds[] | select(.tag as $t | $tags | index($t)) | .settings.clients) += [{"id": $uuid, "alterId": 0, "email": $user}]' \
/etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
echo "$user $uuid $exp" >> /etc/xray/vmess.txt
clear
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "                   ${BOLD}CUENTA VMESS CREADA${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "Usuario: $user\nExpira: $exp"
echo -e "\n${YELLOW}[ VMESS TLS / PORT 443 ]${NC}"
VMESS_TCP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-TCP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"http\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-tcp\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "TCP: vmess://$(echo -n "$VMESS_TCP_JSON" | base64 -w 0)"
VMESS_WS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-WS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "WS: vmess://$(echo -n "$VMESS_WS_JSON" | base64 -w 0)"
VMESS_XHTTP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-XHTTP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"xhttp\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-xhttp\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "XHTTP: vmess://$(echo -n "$VMESS_XHTTP_JSON" | base64 -w 0)"
VMESS_HUP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-HUP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"httpupgrade\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-hup\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "HTTPUp: vmess://$(echo -n "$VMESS_HUP_JSON" | base64 -w 0)"
VMESS_GRPC_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-gRPC\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"\",\"path\":\"\",\"serviceName\":\"vmess-grpc-svc\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "gRPC: vmess://$(echo -n "$VMESS_GRPC_JSON" | base64 -w 0)"
echo -e "\n${YELLOW}[ VMESS NTLS / PORT 80/8080/8880/8081 ]${NC}"
VMESS_NTCP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-TCP\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"http\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-tcp\",\"tls\":\"\"}"
echo -e "TCP: vmess://$(echo -n "$VMESS_NTCP_JSON" | base64 -w 0)"
VMESS_NWS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-WS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
echo -e "WS: vmess://$(echo -n "$VMESS_NWS_JSON" | base64 -w 0)"
VMESS_NXHTTP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-XHTTP\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"xhttp\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-xhttp\",\"tls\":\"\"}"
echo -e "XHTTP: vmess://$(echo -n "$VMESS_NXHTTP_JSON" | base64 -w 0)"
VMESS_NHUP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-HUP\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"httpupgrade\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-hup\",\"tls\":\"\"}"
echo -e "HTTPUp: vmess://$(echo -n "$VMESS_NHUP_JSON" | base64 -w 0)"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
elif [ "$prot" == "3" ]; then
jq --arg pass "$pass" --arg user "$user" --argjson tags "$TROJAN_TAGS" \
'(.inbounds[] | select(.tag as $t | $tags | index($t)) | .settings.clients) += [{"password": $pass, "email": $user}]' \
/etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
echo "$user $pass $exp" >> /etc/xray/trojan.txt
clear
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "                   ${BOLD}CUENTA TROJAN CREADA${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "Usuario: $user\nContraseña: $pass\nExpira: $exp"
echo -e "\n${YELLOW}TLS (443):${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
elif [ "$prot" == "4" ]; then
jq --arg uuid "$uuid" --arg pass "$pass" --arg user "$user" \
--argjson vtags "$VLESS_TAGS" --argjson mtags "$VMESS_TAGS" --argjson ttags "$TROJAN_TAGS" \
'(.inbounds[] | select(.tag as $t | $vtags | index($t)) | .settings.clients) += [{"id": $uuid, "email": $user}]
| (.inbounds[] | select(.tag as $t | $mtags | index($t)) | .settings.clients) += [{"id": $uuid, "alterId": 0, "email": $user}]
| (.inbounds[] | select(.tag as $t | $ttags | index($t)) | .settings.clients) += [{"password": $pass, "email": $user}]' \
/etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
echo "$user $uuid $exp" >> /etc/xray/vless.txt
echo "$user $uuid $exp" >> /etc/xray/vmess.txt
echo "$user $pass $exp" >> /etc/xray/trojan.txt
clear
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "               ${BOLD}CUENTA TODO-EN-UNO CREADA${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "Usuario: $user\nExpira:   $exp"
m_div
echo -e "\n${YELLOW}[ VLESS TLS / SHARED PORT 443 ]${NC}"
echo -e "TCP HTTP: vless://${uuid}@${DOMAIN}:443?type=tcp&headerType=http&security=tls&encryption=none&host=${DOMAIN}&path=%2Fvless-tcp&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-TCP"
echo -e "WS: vless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-WS"
echo -e "XHTTP: vless://${uuid}@${DOMAIN}:443?type=xhttp&security=tls&encryption=none&path=%2Fxhttp&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}&mode=auto&alpn=h2%2Chttp%2F1.1#${user}-VLESS-XHTTP"
echo -e "HTTPUp: vless://${uuid}@${DOMAIN}:443?type=httpupgrade&security=tls&encryption=none&path=%2Fhttpupgrade&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}-VLESS-HTTPUp"
echo -e "gRPC: vless://${uuid}@${DOMAIN}:443?type=grpc&security=tls&encryption=none&serviceName=grpc-svc&sni=${DOMAIN}${INSECURE_PARAM}&alpn=h2#${user}-VLESS-gRPC"
echo -e "${YELLOW}[ VLESS NTLS (80/8080/8880/8081) ]${NC}"
echo -e "TCP: vless://${uuid}@${DOMAIN}:80?type=tcp&headerType=http&security=none&encryption=none&path=%2Fvless-tcp&host=${DOMAIN}#${user}-VLESS-NTLS-TCP"
echo -e "WS: vless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}-VLESS-NTLS-WS"
echo -e "XHTTP: vless://${uuid}@${DOMAIN}:80?type=xhttp&security=none&encryption=none&path=%2Fxhttp&host=${DOMAIN}&mode=auto#${user}-VLESS-NTLS-XHTTP"
echo -e "HUP: vless://${uuid}@${DOMAIN}:80?type=httpupgrade&security=none&encryption=none&path=%2Fhttpupgrade&host=${DOMAIN}#${user}-VLESS-NTLS-HTTPUp"
echo -e "\n${YELLOW}[ VMESS TLS / PORT 443 ]${NC}"
VMESS_TCP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-TCP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"http\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-tcp\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "TCP: vmess://$(echo -n "$VMESS_TCP_JSON" | base64 -w 0)"
VMESS_WS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-WS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "WS: vmess://$(echo -n "$VMESS_WS_JSON" | base64 -w 0)"
VMESS_XHTTP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-XHTTP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"xhttp\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-xhttp\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "XHTTP: vmess://$(echo -n "$VMESS_XHTTP_JSON" | base64 -w 0)"
VMESS_HUP_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-HUP\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"httpupgrade\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-hup\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "HTTPUp: vmess://$(echo -n "$VMESS_HUP_JSON" | base64 -w 0)"
VMESS_GRPC_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS-gRPC\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"\",\"path\":\"\",\"serviceName\":\"vmess-grpc-svc\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "gRPC: vmess://$(echo -n "$VMESS_GRPC_JSON" | base64 -w 0)"
echo -e "\n${YELLOW}[ VMESS NTLS / PORT 80/8080/8880/8081 ]${NC}"
VMESS_NTCP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-TCP\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"tcp\",\"type\":\"http\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-tcp\",\"tls\":\"\"}"
echo -e "TCP: vmess://$(echo -n "$VMESS_NTCP_JSON" | base64 -w 0)"
VMESS_NWS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-WS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
echo -e "WS: vmess://$(echo -n "$VMESS_NWS_JSON" | base64 -w 0)"
VMESS_NXHTTP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-XHTTP\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"xhttp\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-xhttp\",\"tls\":\"\"}"
echo -e "XHTTP: vmess://$(echo -n "$VMESS_NXHTTP_JSON" | base64 -w 0)"
VMESS_NHUP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-HUP\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"httpupgrade\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-hup\",\"tls\":\"\"}"
echo -e "HTTPUp: vmess://$(echo -n "$VMESS_NHUP_JSON" | base64 -w 0)"
echo -e "\n${YELLOW}[ TROJAN TLS (443) ]${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}"
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
echo -e -n "  ${WHITE}Selecciona usuario a eliminar:${NC} "; read -r idx
if [[ "$idx" == "00" || "$idx" == "0" ]]; then return; fi
if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -le 0 ] || [ "$idx" -gt "${#users[@]}" ]; then
echo -e "${RED}Selección inválida.${NC}"; pause_return; return
fi
user="${users[$((idx-1))]}"
jq "(.inbounds[].settings.clients) |= map(select(.email != \"$user\"))" /etc/xray/config.json > /tmp/x.json && mv /tmp/x.json /etc/xray/config.json
sed -i "/^$user /d" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null
systemctl restart xray
echo -e "\n${GREEN}✓ Usuario $user eliminado exitosamente.${NC}"
pause_return
}
renew_xray() {
clear
m_encabezado "${BOLD}RENOVAR CUENTA XRAY${NC}"
echo -e -n " ${WHITE}Usuario a renovar:${NC} "; read -r user
if ! grep -qw "^$user" /etc/xray/vless.txt /etc/xray/vmess.txt /etc/xray/trojan.txt 2>/dev/null; then
echo -e "${RED}Usuario no encontrado.${NC}"; pause_return; return
fi
echo -e -n " ${WHITE}Días a Agregar:${NC} "; read -r days
for proto in vless vmess trojan; do
if grep -qw "^$user" "/etc/xray/${proto}.txt"; then
current_exp=$(grep -w "^$user" "/etc/xray/${proto}.txt" | awk '{print $3}')
new_exp=$(date -d "$current_exp + $days days" +"%Y-%m-%d")
sed -i "s/^$user .* $current_exp/$(grep -w "^$user" "/etc/xray/${proto}.txt" | awk '{print $1 " " $2}') $new_exp/" "/etc/xray/${proto}.txt"
fi
done
echo -e "\n${GREEN}✓ Usuario '$user' renovado exitosamente.${NC}\nNueva Expiración: $new_exp"
pause_return
}
show_xray() {
clear
m_encabezado "${BOLD}MOSTRAR ENLACES DE CONFIG XRAY${NC}"
echo -e -n " ${WHITE}Usuario a ver:${NC} "; read -r user
local found=0
if grep -qw "^$user" /etc/xray/vless.txt; then
uuid=$(grep -w "^$user" /etc/xray/vless.txt | awk '{print $2}')
echo -e "${YELLOW}VLESS TLS (443):${NC}\nvless://${uuid}@${DOMAIN}:443?type=ws&security=tls&encryption=none&path=%2Fvless&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}"
echo -e "\n${YELLOW}VLESS NTLS (80):${NC}\nvless://${uuid}@${DOMAIN}:80?type=ws&security=none&encryption=none&path=%2Fvless&host=${DOMAIN}#${user}\n"
echo -e "${YELLOW}VLESS NTLS XHTTP (80/8080/8880/8081):${NC}\nvless://${uuid}@${DOMAIN}:8081?type=xhttp&security=none&encryption=none&path=%2Fxhttp&host=${DOMAIN}&mode=auto#${user}-XHTTP\n"
found=1
fi
if grep -qw "^$user" /etc/xray/vmess.txt; then
uuid=$(grep -w "^$user" /etc/xray/vmess.txt | awk '{print $2}')
VMESS_TLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-TLS\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
echo -e "${YELLOW}VMESS TLS (443):${NC}\nvmess://$(echo -n "$VMESS_TLS_JSON" | base64 -w 0)"
VMESS_NTLS_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"\"}"
echo -e "\n${YELLOW}VMESS NTLS (80):${NC}\nvmess://$(echo -n "$VMESS_NTLS_JSON" | base64 -w 0)\n"
VMESS_NTLS_XHTTP_JSON="{\"v\":\"2\",\"ps\":\"${user}-NTLS-XHTTP\",\"add\":\"${DOMAIN}\",\"port\":\"8081\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"xhttp\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess-xhttp\",\"tls\":\"\"}"
echo -e "\n${YELLOW}VMESS NTLS XHTTP (80/8080/8880/8081):${NC}\nvmess://$(echo -n "$VMESS_NTLS_XHTTP_JSON" | base64 -w 0)\n"
found=1
fi
if grep -qw "^$user" /etc/xray/trojan.txt; then
pass=$(grep -w "^$user" /etc/xray/trojan.txt | awk '{print $2}')
echo -e "${YELLOW}TROJAN TLS (443):${NC}\ntrojan://${pass}@${DOMAIN}:443?type=ws&security=tls&path=%2Ftrojan&host=${DOMAIN}&sni=${DOMAIN}${INSECURE_PARAM}#${user}\n"
found=1
fi
if [ "$found" -eq 0 ]; then echo -e "${RED}Usuario no encontrado en ningún protocolo.${NC}"; fi
pause_return
}
list_real_users() { awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "systemd-network" && $1 != "messagebus" {print $1}' /etc/passwd 2>/dev/null; }
display_name_for_user() {
local u="$1"
if grep -qx "$u" "$TOKEN_USERS_DB" 2>/dev/null; then
local nombre
nombre="$(getent passwd "$u" | cut -d: -f5)"
[ -n "$nombre" ] && { echo "$nombre"; return; }
fi
echo "$u"
}
select_user() {
local purpose="$1"
mapfile -t USERS < <(list_real_users)
if [ "${#USERS[@]}" -eq 0 ]; then echo -e "${RED}No se encontraron cuentas de usuario activas.${NC}"; return 1; fi
clear
m_encabezado "${WHITE}${BOLD}$purpose${NC}"
for i in "${!USERS[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "$(display_name_for_user "${USERS[$i]}")"; done
echo -e "\n  [${YELLOW}00${NC}] Atrás\n"
echo -e -n "  ${WHITE}Selecciona un número de cuenta:${NC} "; read -r idx
[[ "$idx" == "00" || "$idx" == "0" ]] && return 1
if ! [[ "$idx" =~ ^[0-9]+$ ]] || [ "$idx" -lt 1 ] || [ "$idx" -gt "${#USERS[@]}" ]; then echo -e "${RED}  Selección inválida.${NC}"; return 1; fi
SELECTED_USER="${USERS[$((idx-1))]}"
return 0
}
create_user() {
clear
m_encabezado "${BOLD}CREAR NUEVO USUARIO SSH${NC}"
echo -e "  ${YELLOW}(Escribe 00 en cualquier campo para cancelar y volver)${NC}\n"
while true; do
echo -e -n "  ${WHITE}Nombre de usuario:${NC} "; read -r user
user="$(echo -n "$user" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "$user" = "00" ] && return
if [ -z "$user" ]; then echo -e "${RED}  Error: El usuario no puede estar vacío.${NC}\n"; continue; fi
if ! [[ "$user" =~ ^[^[:space:]]{1,32}$ ]]; then echo -e "${RED}  Error: El usuario no puede contener espacios (máx 32 caracteres).${NC}\n"; continue; fi
if id "$user" >/dev/null 2>&1; then echo -e "${RED}  Error: El usuario '$user' ya existe.${NC}\n"; continue; fi
break
done
while true; do
echo -e -n "  ${WHITE}Contraseña:${NC} "; read -r pass
pass="$(echo -n "$pass" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "$pass" = "00" ] && return
if [ -z "$pass" ]; then echo -e "${RED}  Error: La contraseña no puede estar vacía.${NC}\n"; continue; fi
if [[ "$pass" =~ [[:space:]] ]]; then echo -e "${RED}  Error: La contraseña no puede contener espacios.${NC}\n"; continue; fi
break
done
while true; do
echo -e -n "  ${WHITE}Válido por (días):${NC} "; read -r days
days="$(echo -n "$days" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "$days" = "00" ] && return
if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -eq 0 ]; then echo -e "${RED}  Error: Debe ser un número de días mayor a 0.${NC}\n"; continue; fi
break
done
while true; do
echo -e -n "  ${WHITE}Límite de conexiones simultáneas (0 = sin límite):${NC} "; read -r conn_limit
conn_limit="$(echo -n "$conn_limit" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "$conn_limit" = "00" ] && return
[ -z "$conn_limit" ] && conn_limit=0
if ! [[ "$conn_limit" =~ ^[0-9]+$ ]]; then echo -e "${RED}  Error: Debe ser un número.${NC}\n"; continue; fi
break
done
ua_err=$(useradd --badname -e "$(date -d "+$days days" +%Y-%m-%d)" -s /bin/false -M "$user" 2>&1 1>/dev/null)
if [ $? -ne 0 ]; then
echo -e "\n${RED}  Error: No se pudo crear el usuario '$user'.${NC}"
echo -e "  ${YELLOW}Detalle:${NC} ${ua_err:-desconocido}"
echo "$(date '+%F %T') create_user FALLÓ useradd user=$user :: ${ua_err:-desconocido}" >> /var/log/deekayvpn-menu-errors.log
pause_return; return
fi
cp_err=$(echo "$user:$pass" | chpasswd 2>&1 1>/dev/null)
if [ $? -ne 0 ]; then
echo -e "\n${RED}  Error: No se pudo establecer la contraseña. Eliminando cuenta incompleta...${NC}"
echo -e "  ${YELLOW}Detalle:${NC} ${cp_err:-desconocido}"
echo "$(date '+%F %T') create_user FALLÓ chpasswd user=$user :: ${cp_err:-desconocido}" >> /var/log/deekayvpn-menu-errors.log
userdel -f "$user" 2>/dev/null
pause_return; return
fi
sed -i "/^$user /d" "$SSH_LIMIT_DB" 2>/dev/null
if [ "$conn_limit" -gt 0 ]; then echo "$user $conn_limit" >> "$SSH_LIMIT_DB"; fi
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
echo -e "  ${BOLD}Límite Conexiones${NC}: ${YELLOW}$([ "$conn_limit" -gt 0 ] && echo "$conn_limit" || echo "Sin límite")${NC}"
m_div
echo -e "  SSH Port   : 22, 299"
echo -e "  SSL/TLS    : 443"
echo -e "  SSL/WS     : 443"
echo -e "  WebSocket  : 80, 8080, 8880, 2082, 2086, 25"
echo -e "  BHTTP      : 8180, 8280"
echo -e "  HCR        : 8780"
echo -e "  SlowDNS    : 53"
echo -e "  BadVPN     : 7300"
echo -e "  UDP Custom : 1-65535"
m_div
echo -e "  ${BOLD}Payload HTTP     :${NC}"
echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
echo -e ""
echo -e "  ${BOLD}Payload Mejorado :${NC}"
echo -e "  ${YELLOW}GET / HTTP/1.1[crlf]Host: bug.com[crlf][crlf]PATCH / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Connection: upgrade[crlf]Upgrade: websocket[crlf][crlf]${NC}"
m_div
echo -e "  ${BOLD}SlowDNS NS ${NC}: ${YELLOW}${CURRENT_NS:-No configurado}${NC}"
echo -e "  ${BOLD}DNS PUB KEY${NC}: 7fbd1f8aa0abfe15a7903e837f78aba39cf61d36f183bd604daa2fe4ef3b7b59"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
pause_return
}
set_token_password() {
clear
m_encabezado "${BOLD}CONTRASEÑA GENERAL DE TOKEN${NC}"
echo -e "  ${YELLOW}(Escribe 00 para cancelar y volver)${NC}\n"
if [ -s "$TOKEN_PASS_DB" ]; then
echo -e "  ${WHITE}Contraseña actual:${NC} ${YELLOW}$(cat "$TOKEN_PASS_DB")${NC}\n"
fi
while true; do
echo -e -n "  ${WHITE}Nueva contraseña general:${NC} "; read -r newpass
newpass="$(echo -n "$newpass" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "$newpass" = "00" ] && return
if [ -z "$newpass" ]; then echo -e "${RED}  Error: La contraseña no puede estar vacía.${NC}\n"; continue; fi
if [[ "$newpass" =~ [[:space:]] ]]; then echo -e "${RED}  Error: La contraseña no puede contener espacios.${NC}\n"; continue; fi
break
done
echo "$newpass" > "$TOKEN_PASS_DB"
actualizados=0
if [ -s "$TOKEN_USERS_DB" ]; then
while IFS= read -r tu; do
[ -z "$tu" ] && continue
if id "$tu" >/dev/null 2>&1; then
if echo "$tu:$newpass" | chpasswd 2>/dev/null; then
actualizados=$((actualizados+1))
fi
else
sed -i "/^$tu$/d" "$TOKEN_USERS_DB" 2>/dev/null
fi
done < "$TOKEN_USERS_DB"
fi
clear
echo -e "${GREEN}  Contraseña general actualizada.${NC}"
echo -e "  ${WHITE}Usuarios Token afectados:${NC} ${YELLOW}$actualizados${NC}"
pause_return
}
create_token_user() {
clear
m_encabezado "${BOLD}CREAR USUARIO TOKEN${NC}"
echo -e "  ${YELLOW}(Escribe 00 en cualquier campo para cancelar y volver)${NC}\n"
if [ ! -s "$TOKEN_PASS_DB" ]; then
echo -e "  ${YELLOW}Aún no hay una contraseña general de Token configurada.${NC}"
while true; do
echo -e -n "  ${WHITE}Establece la contraseña general de Token:${NC} "; read -r initpass
initpass="$(echo -n "$initpass" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "$initpass" = "00" ] && return
if [ -z "$initpass" ]; then echo -e "${RED}  Error: La contraseña no puede estar vacía.${NC}\n"; continue; fi
if [[ "$initpass" =~ [[:space:]] ]]; then echo -e "${RED}  Error: La contraseña no puede contener espacios.${NC}\n"; continue; fi
break
done
echo "$initpass" > "$TOKEN_PASS_DB"
echo ""
fi
token_pass="$(cat "$TOKEN_PASS_DB")"
while true; do
echo -e -n "  ${WHITE}Nombre:${NC} "; read -r user
user="$(echo -n "$user" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "$user" = "00" ] && return
if [ -z "$user" ]; then echo -e "${RED}  Error: El nombre no puede estar vacío.${NC}\n"; continue; fi
if ! [[ "$user" =~ ^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$ ]]; then echo -e "${RED}  Error: Nombre inválido (letras/números/guiones, sin espacios).${NC}\n"; continue; fi
if id "$user" >/dev/null 2>&1; then echo -e "${RED}  Error: El usuario '$user' ya existe.${NC}\n"; continue; fi
break
done
while true; do
echo -e -n "  ${WHITE}Token (nombre de usuario para login):${NC} "; read -r token
token="$(echo -n "$token" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "$token" = "00" ] && return
if [ -z "$token" ]; then echo -e "${RED}  Error: El token no puede estar vacío.${NC}\n"; continue; fi
if ! [[ "$token" =~ ^[^[:space:]]{1,32}$ ]]; then echo -e "${RED}  Error: El token no puede contener espacios (máx 32 caracteres).${NC}\n"; continue; fi
if id "$token" >/dev/null 2>&1; then echo -e "${RED}  Error: El token '$token' ya existe como usuario.${NC}\n"; continue; fi
break
done
while true; do
echo -e -n "  ${WHITE}Válido por (días):${NC} "; read -r days
days="$(echo -n "$days" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ "$days" = "00" ] && return
if ! [[ "$days" =~ ^[0-9]+$ ]] || [ "$days" -eq 0 ]; then echo -e "${RED}  Error: Debe ser un número de días mayor a 0.${NC}\n"; continue; fi
break
done
ua_err=$(useradd --badname -e "$(date -d "+$days days" +%Y-%m-%d)" -s /bin/false -M -c "$user" "$token" 2>&1 1>/dev/null)
if [ $? -ne 0 ]; then
echo -e "\n${RED}  Error: No se pudo crear el usuario '$token'.${NC}"
echo -e "  ${YELLOW}Detalle:${NC} ${ua_err:-desconocido}"
echo "$(date '+%F %T') create_token_user FALLÓ useradd user=$token :: ${ua_err:-desconocido}" >> /var/log/deekayvpn-menu-errors.log
pause_return; return
fi
cp_err=$(echo "$token:$token_pass" | chpasswd 2>&1 1>/dev/null)
if [ $? -ne 0 ]; then
echo -e "\n${RED}  Error: No se pudo establecer la contraseña. Eliminando cuenta incompleta...${NC}"
echo -e "  ${YELLOW}Detalle:${NC} ${cp_err:-desconocido}"
echo "$(date '+%F %T') create_token_user FALLÓ chpasswd user=$token :: ${cp_err:-desconocido}" >> /var/log/deekayvpn-menu-errors.log
userdel -f "$token" 2>/dev/null
pause_return; return
fi
sed -i "/^$token /d" "$SSH_LIMIT_DB" 2>/dev/null
echo "$token 1" >> "$SSH_LIMIT_DB"
sed -i "/^$token$/d" "$TOKEN_USERS_DB" 2>/dev/null
echo "$token" >> "$TOKEN_USERS_DB"
IP=$(curl -s ipv4.icanhazip.com)
clear
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "                ${BOLD}USUARIO TOKEN CREADO EXITOSAMENTE${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "  ${BOLD}Dirección IP${NC}      : ${YELLOW}$IP${NC}"
echo -e "  ${BOLD}Nombre${NC}            : ${YELLOW}$user${NC}"
echo -e "  ${BOLD}Token${NC}             : ${YELLOW}$token${NC}"
echo -e "  ${BOLD}Contraseña (Token)${NC}: ${YELLOW}$token_pass${NC}"
echo -e "  ${BOLD}Expiración${NC}        : ${YELLOW}$(date -d "+$days days" +%Y-%m-%d)${NC}"
echo -e "  ${BOLD}Límite Conexiones${NC} : ${YELLOW}1${NC}"
echo -e "  ${BOLD}BHTTP${NC}             : ${YELLOW}8180, 8280${NC}"
echo -e "  ${BOLD}HCR${NC}               : ${YELLOW}8780${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
pause_return
}
delete_user() {
if ! select_user "DELETE SSH USER"; then pause_return; return; fi
clear; echo -e "${RED}Advertencia: Estás a punto de eliminar al usuario: ${YELLOW}$SELECTED_USER${NC}"
echo -e -n " ${WHITE}¿Estás seguro? [y/N]:${NC} "; read -r ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
pkill -u "$SELECTED_USER" 2>/dev/null
if userdel -r -f "$SELECTED_USER" 2>/dev/null || userdel -f "$SELECTED_USER" 2>/dev/null; then
sed -i "/^$SELECTED_USER /d" "$SSH_LIMIT_DB" 2>/dev/null
sed -i "/^$SELECTED_USER$/d" "$TOKEN_USERS_DB" 2>/dev/null
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
echo -e -n " ${WHITE}Ingresa número de días a agregar:${NC} "; read -r days
if ! [[ "$days" =~ ^[0-9]+$ ]]; then echo -e "${RED}Formato de número inválido.${NC}"; pause_return; return; fi
current=$(chage -l "$SELECTED_USER" 2>/dev/null | awk -F": " '/Account expires/ {print $2}')
if [ "$current" = "never" ] || [ -z "$current" ]; then new_exp=$(date -d "+$days days" +%Y-%m-%d)
else new_exp=$(date -d "$current +$days days" +%Y-%m-%d); fi
chage -E "$new_exp" "$SELECTED_USER"
echo -e "${GREEN}¡Éxito!${NC} Cuenta extendida.\nNueva Fecha de Expiración: ${YELLOW}$new_exp${NC}"
pause_return
}
online_users() {
clear
m_encabezado "${BOLD}MONITOR DE SESIONES ACTIVAS${NC}"
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
restart_service() {
local service_name="$1"
local display_name="$2"
echo -e "Reiniciando ${display_name}..."
systemctl restart $service_name 2>/dev/null || true
echo -e "${GREEN}✓ ${display_name} reiniciado.${NC}"
}
service_control_menu() {
while true; do
clear
m_top
m_titulo "${WHITE}${BOLD}CONTROL DE SERVICIOS${NC}"
m_sep
m_opcion "01" "Reiniciar todos los servicios"
m_opcion "02" "Reiniciar SSH"
m_opcion "03" "Reiniciar proxies WebSocket de Node"
m_opcion "04" "Reiniciar Stunnel y Xray Core"
m_opcion "05" "Reiniciar Squid Proxy y Nginx"
m_opcion "06" "Reiniciar núcleo UDP (SlowDNS / Hysteria / BadVPN)"
m_opcion "00" "${GRIS}Atrás${NC}"
m_bot
echo ""
echo -e -n "  ${WHITE}Selecciona una opción:${NC} "; read -r opt
case "$opt" in
1|01) restart_service "ssh stunnel4 sslh squid nginx server-sldns hysteria-server hysteria2-server badvpn ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086 xray bhttp-server hcr-server" "All Services"; pause_return ;;
2|02) restart_service "ssh" "SSH"; pause_return ;;
3|03) restart_service "ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086" "Node WebSocket Proxies"; pause_return ;;
4|04) restart_service "stunnel4 xray" "Stunnel & Xray Core"; pause_return ;;
5|05) restart_service "squid nginx" "Squid Proxy & Nginx"; pause_return ;;
6|06) restart_service "server-sldns hysteria-server hysteria2-server badvpn" "UDP Core Services"; pause_return ;;
0|00) break ;;
*) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
esac
done
}
backup_snapshot() {
clear; local out="/root/hextunnel_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
echo -e "Empaquetando configuraciones del servidor..."
tar -czf "$out" /etc/ssh /etc/stunnel /etc/squid /etc/hysteria /etc/hysteria2 /etc/deekayvpn /etc/systemd/system/ws-proxy@.service /etc/xray /etc/bhttp /etc/hcr 2>/dev/null
echo -e "\n${GREEN}✓ ¡Respaldo creado exitosamente!${NC}\nUbicación: ${YELLOW}$out${NC}"
pause_return
}
restore_snapshot() {
clear
m_encabezado "${BOLD}RESTAURAR CONFIGURACIÓN${NC}"
shopt -s nullglob
backups=(/root/hextunnel_backup_*.tar.gz)
if [ ${#backups[@]} -eq 0 ]; then echo -e "${RED}  No se encontraron archivos de respaldo en /root/.${NC}"; pause_return; return; fi
echo -e "  Respaldos Disponibles:\n"
for i in "${!backups[@]}"; do printf "  [${YELLOW}%02d${NC}] %s\n" $((i+1)) "$(basename "${backups[$i]}")"; done
echo -e "\n  [${YELLOW}00${NC}] Cancelar\n"
echo -e -n "  ${WHITE}Selecciona respaldo a restaurar:${NC} "; read -r sel
if [[ "$sel" == "00" || "$sel" == "0" ]]; then return; fi
idx=$((sel-1))
if [ -n "${backups[$idx]}" ]; then
echo -e "\nRestaurando ${YELLOW}$(basename "${backups[$idx]}")${NC}..."
tar -xzf "${backups[$idx]}" -C /
systemctl daemon-reload; systemctl restart ssh stunnel4 sslh squid nginx server-sldns hysteria-server badvpn ws-proxy@10080 ws-proxy@25 ws-proxy@2082 ws-proxy@2086 xray bhttp-server hcr-server 2>/dev/null || true
echo -e "${GREEN}✓ ¡Restauración completa!${NC}"
else echo -e "${RED}Selección inválida.${NC}"; fi
pause_return
}
utilities_menu() {
while true; do
clear
m_top
m_titulo "${WHITE}${BOLD}UTILIDADES DEL SISTEMA${NC}"
m_sep
m_opcion "1" "Activar BBR nativo del kernel (rápido y silencioso)"
m_opcion "2" "Verificar desbloqueos de Netflix y streaming"
m_opcion "3" "CheckUser (consulta de cuentas por API)"
m_opcion "4" "SpeedTest By Ockla" 
m_opcion "5" "Cambiar DNS Del Sistema" 
m_opcion "6" "Activar Acceso Root" 
m_opcion "0" "${GRIS}Atrás${NC}"
m_bot
echo ""
echo -e -n "  ${WHITE}Selecciona una opción:${NC} "; read -r subopt
case "$subopt" in
1)
echo -e "\nActivando BBR Nativo del Kernel..."
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1
if [[ "$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null)" == *"bbr"* ]]; then echo -e "${GREEN}✓ ¡BBR Activado Exitosamente!${NC}"
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
3)
clear
if ! command -v check >/dev/null 2>&1; then
echo -e "${YELLOW}CheckUser no está instalado. Instalando...${NC}\n"
bash <(curl -sL https://raw.githubusercontent.com/JotchuaDevz/CheckUser/main/install.sh)
clear
fi
check
;;
4)
Speedtest ;;
5)
ChangeDNS ;;
6) root_pass ;;
0) break ;;
*) echo -e "${RED}Opción inválida.${NC}"; sleep 1 ;;
esac
done
}

root_acces () {
  sed -i '/PermitRootLogin/d' /etc/ssh/sshd_config
  echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
  sed -i '/PasswordAuthentication/d' /etc/ssh/sshd_config
  echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
  systemctl restart ssh 2>/dev/null || service sshd restart 2>/dev/null
}

root_pass () {
  clear
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}                         Activar Acceso Root${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}Esto activará el login root por SSH y cambiará su contraseña.${NC}"
  echo -e "${BOLD}Esta contraseña podrá ser utilizada para\n    acceder al vps como usuario root.${NC}"
  echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
  echo -ne " ${BOLD}¿Activar acceso root? [S/N]: ${NC}"; read -r x
  if [[ "$x" =~ ^[Nn]$ ]]; then
    return 0
  fi
  echo -e "${GREEN}Activando acceso root...${NC}"
  root_acces
  echo -e " ${BOLD}Acceso root Activado.${NC}"
  echo -ne "${BOLD}Nueva contraseña: ${NC}"
  read -rs pass
  echo
  (echo "$pass"; echo "$pass") | passwd root 2>/dev/null
  echo -e "${BOLD}Contraseña root actualizada.${NC}"
  echo -e "${BOLD}Contraseña actual:${NC} ${GREEN}$pass${NC}"
  pause_return
}
ChangeDNS() {
    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                         CAMBIAR DNS${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}DNS actuales:${NC}"
    if command -v resolvectl >/dev/null 2>&1; then
        resolvectl dns
    else
        grep nameserver /etc/resolv.conf 2>/dev/null
    fi
    echo
    read -rp "$(echo -e "${BOLD}DNS primario: ${NC}")" DNS1
    read -rp "$(echo -e "${BOLD}DNS secundario (opcional): ${NC}")" DNS2
    if [ -z "$DNS1" ]; then
        echo -e "${RED}DNS primario vacío.${NC}"
        pause_return
        return 1
    fi

    if command -v resolvectl >/dev/null 2>&1; then
        INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
        if [ -z "$INTERFACE" ]; then
            echo -e "${RED}No se pudo detectar la interfaz.${NC}"
            pause_return
            return 1
        fi
        if [ -n "$DNS2" ]; then
            resolvectl dns "$INTERFACE" "$DNS1" "$DNS2"
        else
            resolvectl dns "$INTERFACE" "$DNS1"
        fi
        resolvectl flush-caches
        echo -e "${GREEN}✓ DNS cambiados correctamente.${NC}"
        echo -e "${GREEN}DNS configurados:${NC}"
        resolvectl dns "$INTERFACE"
    else
        {
            echo "nameserver $DNS1"
            [ -n "$DNS2" ] && echo "nameserver $DNS2"
        } > /etc/resolv.conf
        echo -e "${GREEN}✓ DNS cambiados correctamente.${NC}"
        echo -e "${GREEN}DNS configurados:${NC}"
        grep nameserver /etc/resolv.conf
    fi
    echo
    pause_return
}
Speedtest() {
    if ! command -v speedtest >/dev/null 2>&1; then
        ARCH=$(dpkg --print-architecture)
        case "$ARCH" in
            amd64)
                PACKAGE="speedtest_1.2.0.84-1.ea6b6773cf_amd64.deb"
                ;;
            arm64)
                PACKAGE="speedtest_1.2.0.84-1.ea6b6773cf_arm64.deb"
                ;;
            armhf)
                PACKAGE="speedtest_1.2.0.84-1.ea6b6773cf_armhf.deb"
                ;;
            armel)
                PACKAGE="speedtest_1.2.0.84-1.ea6b6773cf_armel.deb"
                ;;
            i386)
                PACKAGE="speedtest_1.2.0.84-1.ea6b6773cf_i386.deb"
                ;;
            *)
                echo -e "${RED}Arquitectura no compatible: $ARCH${NC}"
                return 1
                ;;
        esac
        echo -e "${GREEN}Instalando Speedtest para $ARCH...${NC}"
        cd /tmp || return 1
        URL="https://packagecloud.io/ookla/speedtest-cli/packages/debian/bookworm/$PACKAGE/download.deb"
        curl -fL -o speedtest.deb "$URL" || {
            echo -e "${RED}No se pudo descargar Speedtest.${NC}"
            return 1
        }
        dpkg -i speedtest.deb >/dev/null 2>&1 || {
            apt-get install -f -y >/dev/null 2>&1
            dpkg -i speedtest.deb >/dev/null 2>&1
        }
        rm -f speedtest.deb
        hash -r
        if ! command -v speedtest >/dev/null 2>&1; then
            echo -e "${RED}Error al instalar Speedtest.${NC}"
            return 1
        fi
        echo -e "${GREEN}Speedtest instalado correctamente.${NC}"
    fi

    clear
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                         SPEEDTEST${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo ""

    if command -v jq >/dev/null 2>&1; then
        local dl=0 ul=0 url=""
        while IFS= read -r linea; do
            local tipo
            tipo=$(echo "$linea" | jq -r '.type' 2>/dev/null)
            case "$tipo" in
                download)
                    dl=$(echo "$linea" | jq -r '(.download.bandwidth*8/1000000)' 2>/dev/null)
                    printf "\r  ${CYAN}▼ Bajada:${NC} %6.2f Mbps   ${GRIS}▲ Subida:${NC} %6.2f Mbps" "$dl" "$ul"
                    ;;
                upload)
                    ul=$(echo "$linea" | jq -r '(.upload.bandwidth*8/1000000)' 2>/dev/null)
                    printf "\r  ${GRIS}▼ Bajada:${NC} %6.2f Mbps   ${CYAN}▲ Subida:${NC} %6.2f Mbps" "$dl" "$ul"
                    ;;
                result)
                    dl=$(echo "$linea" | jq -r '(.download.bandwidth*8/1000000)' 2>/dev/null)
                    ul=$(echo "$linea" | jq -r '(.upload.bandwidth*8/1000000)' 2>/dev/null)
                    url=$(echo "$linea" | jq -r '.result.url' 2>/dev/null)
                    ;;
            esac
        done < <(speedtest --accept-license --accept-gdpr --format=jsonl 2>/dev/null)
        echo ""
        echo ""
        echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
        printf "  ${WHITE}${BOLD}▼ Bajada:${NC} %.2f Mbps\n" "$dl"
        printf "  ${WHITE}${BOLD}▲ Subida:${NC} %.2f Mbps\n" "$ul"
        [ -n "$url" ] && [ "$url" != "null" ] && echo -e "  ${GRIS}Resultado:${NC} $url"
        echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    else
        speedtest --accept-license --accept-gdpr 2>&1 | grep -Ei "Download|Upload|Result"
    fi
    pause_return
}
change_domain() {
clear
m_encabezado "${BOLD}CAMBIAR DOMINIO DEL SERVIDOR${NC}"
current_dom=$(cat /etc/deekayvpn/domain.txt 2>/dev/null || echo "No configurado")
current_cert=$(cat /etc/xray/cert_type 2>/dev/null || echo "desconocido")
echo -e " Dominio/IP Actual: ${YELLOW}$current_dom${NC}  (certificado: ${YELLOW}$current_cert${NC})\n"
echo -e -n " ${WHITE}Ingresa Nuevo Dominio o IP:${NC} "; read -r new_dom
new_dom="$(printf '%s' "$new_dom" | tr -d '[:space:]' | tr 'A-Z' 'a-z')"
new_dom="${new_dom#http://}"; new_dom="${new_dom#https://}"; new_dom="${new_dom#*@}"
new_dom="${new_dom%%/*}"; new_dom="${new_dom%%:*}"; new_dom="${new_dom%.}"
if [ -z "$new_dom" ]; then echo -e "\n${RED}Acción cancelada.${NC}"; pause_return; return; fi
if [ "$new_dom" = "$current_dom" ]; then echo -e "\n${RED}Es el mismo dominio/IP, sin cambios.${NC}"; pause_return; return; fi
if ! [[ "$new_dom" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && ! [[ "$new_dom" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$ ]]; then
echo -e "\n${RED}Formato inválido. Usa mi.dominio.com o una IPv4.${NC}"; pause_return; return
fi
SERVER_IP=$(curl -4 -s --max-time 5 https://ipv4.icanhazip.com 2>/dev/null | tr -d '[:space:]')
[ -z "$SERVER_IP" ] && SERVER_IP=$(hostname -I | awk '{print $1}')
BK_CERT="/etc/xray/.bk-cert-$$"
mkdir -p "$BK_CERT" >/dev/null 2>&1
cp /etc/xray/xray.crt "$BK_CERT/" 2>/dev/null
cp /etc/xray/xray.key "$BK_CERT/" 2>/dev/null
cp /etc/xray/cert_type "$BK_CERT/" 2>/dev/null
restaurar_cert_anterior() {
cp "$BK_CERT/xray.crt" /etc/xray/xray.crt 2>/dev/null
cp "$BK_CERT/xray.key" /etc/xray/xray.key 2>/dev/null
cp "$BK_CERT/cert_type" /etc/xray/cert_type 2>/dev/null
cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem 2>/dev/null
chmod 600 /etc/stunnel/stunnel.pem /etc/xray/xray.key 2>/dev/null
systemctl start xray haproxy nginx stunnel4 2>/dev/null || true
rm -rf "$BK_CERT" 2>/dev/null
}
par_cert_ok() {
local a b
a=$(openssl x509 -noout -pubkey -in /etc/xray/xray.crt 2>/dev/null)
b=$(openssl pkey -pubout -in /etc/xray/xray.key 2>/dev/null)
[ -n "$a" ] && [ "$a" = "$b" ]
}
if [[ "$new_dom" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
echo -e "\n${YELLOW}Generando certificado autofirmado para la IP $new_dom...${NC}"
systemctl stop xray 2>/dev/null || true
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
-keyout /etc/xray/xray.key \
-out /etc/xray/xray.crt \
-subj "/CN=${new_dom}/O=HexTunnel/C=US" > /dev/null 2>&1
echo "selfsigned" > /etc/xray/cert_type
rm -f /etc/cron.d/certbot-renew
NEW_CERT_TYPE="selfsigned"
else
echo -e "\n${YELLOW}Verificando que $new_dom resuelva a $SERVER_IP...${NC}"
command -v dig >/dev/null 2>&1 || apt-get install -y dnsutils >/dev/null 2>&1
DOMAIN_IPS=$(dig +short A "$new_dom" @1.1.1.1 2>/dev/null | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$')
if [ -z "$DOMAIN_IPS" ] || ! printf '%s\n' "$DOMAIN_IPS" | grep -qx "$SERVER_IP"; then
echo -e "\n${RED}✗ ERROR: $new_dom no apunta a $SERVER_IP (resuelve a: $(printf '%s ' $DOMAIN_IPS)).${NC}"
echo -e "  Corrige el registro A (en Cloudflare usa 'DNS only'). No se cambió nada."
rm -rf "$BK_CERT" 2>/dev/null
pause_return; return
fi
echo -e "${GREEN}Dominio verificado. Liberando el puerto 80...${NC}"
command -v certbot >/dev/null 2>&1 || apt-get install -y certbot >/dev/null 2>&1
systemctl stop haproxy nginx xray sslh 2>/dev/null || true
sleep 1
if ss -lntH 2>/dev/null | awk '{print $4}' | grep -qE '(^|[.:])80$'; then
echo -e "\n${RED}✗ El puerto 80 sigue ocupado. Revisa: ss -lntp | grep ':80'${NC}"
restaurar_cert_anterior
pause_return; return
fi
echo -e "${GREEN}Solicitando certificado Let's Encrypt...${NC}"
if ! certbot certonly --standalone --preferred-challenges http --non-interactive --agree-tos \
--keep-until-expiring --cert-name "$new_dom" -d "$new_dom" --email "admin@${new_dom}" >/dev/null 2>&1; then
if ! certbot certonly --standalone --preferred-challenges http --non-interactive --agree-tos \
--keep-until-expiring --cert-name "$new_dom" -d "$new_dom" --register-unsafely-without-email >/dev/null 2>&1; then
echo -e "\n${RED}✗ Falló la emisión del certificado. Revisa /var/log/letsencrypt/letsencrypt.log${NC}"
restaurar_cert_anterior
pause_return; return
fi
fi
if [ ! -s "/etc/letsencrypt/live/${new_dom}/fullchain.pem" ]; then
echo -e "\n${RED}✗ No se encontró el certificado emitido. Revisa: certbot certificates${NC}"
restaurar_cert_anterior
pause_return; return
fi
cp -L "/etc/letsencrypt/live/${new_dom}/fullchain.pem" /etc/xray/xray.crt
cp -L "/etc/letsencrypt/live/${new_dom}/privkey.pem" /etc/xray/xray.key
echo "letsencrypt" > /etc/xray/cert_type
NEW_CERT_TYPE="letsencrypt"
mkdir -p /etc/letsencrypt/renewal-hooks/pre /etc/letsencrypt/renewal-hooks/post /etc/letsencrypt/renewal-hooks/deploy > /dev/null 2>&1
cat <<'EOF_PRE' > /etc/letsencrypt/renewal-hooks/pre/hex-tunnel-stop.sh
#!/bin/bash
systemctl stop haproxy nginx xray 2>/dev/null || true
sleep 1
EOF_PRE
cat <<'EOF_POST' > /etc/letsencrypt/renewal-hooks/post/hex-tunnel-start.sh
#!/bin/bash
systemctl start xray haproxy nginx 2>/dev/null || true
EOF_POST
cat <<'EOF_RENEW' > /etc/letsencrypt/renewal-hooks/deploy/hex-tunnel.sh
#!/bin/bash
set -e
for domain in $RENEWED_DOMAINS; do
install -m 644 "/etc/letsencrypt/live/$domain/fullchain.pem" /etc/xray/xray.crt
install -m 600 "/etc/letsencrypt/live/$domain/privkey.pem" /etc/xray/xray.key
cat "/etc/letsencrypt/live/$domain/privkey.pem" "/etc/letsencrypt/live/$domain/fullchain.pem" > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem
systemctl restart xray stunnel4 2>/dev/null || true
systemctl restart hysteria2-server 2>/dev/null || true
break
done
EOF_RENEW
chmod +x /etc/letsencrypt/renewal-hooks/pre/hex-tunnel-stop.sh /etc/letsencrypt/renewal-hooks/post/hex-tunnel-start.sh /etc/letsencrypt/renewal-hooks/deploy/hex-tunnel.sh > /dev/null 2>&1
echo "17 3 * * * root certbot renew --quiet" > /etc/cron.d/certbot-renew
chmod 644 /etc/cron.d/certbot-renew > /dev/null 2>&1
fi
chmod 644 /etc/xray/xray.crt > /dev/null 2>&1
chmod 600 /etc/xray/xray.key > /dev/null 2>&1
if ! par_cert_ok; then
echo -e "\n${RED}✗ El certificado y la clave no coinciden. Se restaura el anterior.${NC}"
restaurar_cert_anterior
pause_return; return
fi
cat /etc/xray/xray.key /etc/xray/xray.crt > /etc/stunnel/stunnel.pem 2>/dev/null
chmod 600 /etc/stunnel/stunnel.pem > /dev/null 2>&1
chown root:root /etc/stunnel/stunnel.pem > /dev/null 2>&1
if ! /usr/local/bin/xray run -test -config /etc/xray/config.json >/dev/null 2>&1; then
echo -e "\n${RED}✗ Xray no validó la configuración con el nuevo certificado. Se restaura el anterior.${NC}"
restaurar_cert_anterior
pause_return; return
fi
echo "$new_dom" > /etc/deekayvpn/domain.txt
DOMAIN="$new_dom"
if [ "$NEW_CERT_TYPE" = "letsencrypt" ]; then INSECURE_PARAM=""; else INSECURE_PARAM="&allowInsecure=1"; fi
systemctl restart xray stunnel4 2>/dev/null || true
systemctl start haproxy 2>/dev/null || true
systemctl start sslh 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true
systemctl restart hysteria2-server 2>/dev/null || true
rm -rf "$BK_CERT" 2>/dev/null
if systemctl is-active --quiet xray; then
echo -e "\n${GREEN}✓ Dominio actualizado a: $new_dom${NC}"
echo -e "${GREEN}✓ Certificado regenerado (${NEW_CERT_TYPE}) y servicios reiniciados.${NC}"
else
echo -e "\n${RED}✗ Xray no quedó activo. Revisa: journalctl -u xray -n 40${NC}"
fi
echo -e "${YELLOW}Nota: los enlaces vless/vmess/trojan que ya diste a usuarios usaban el dominio/cert${NC}"
echo -e "${YELLOW}anterior. Genera enlaces nuevos desde el menú de Xray (opción 4, Mostrar Enlaces).${NC}"
pause_return
}
change_slowdns() {
clear
m_encabezado "${BOLD}CAMBIAR NAMESERVER DE SLOWDNS${NC}"
svc_file="/etc/systemd/system/server-sldns.service"
if [ ! -f "$svc_file" ]; then echo -e "${RED}Archivo de servicio SlowDNS no encontrado.${NC}"; pause_return; return; fi
current_ns=$(grep 'ExecStart=' "$svc_file" | sed 's/.*server\.key \([^ ]*\) .*/\1/')
echo -e " Nameserver Actual: ${YELLOW}$current_ns${NC}\n"
echo -e -n " ${WHITE}Ingresa Nuevo Nameserver (ej. ns1.dominio.com):${NC} "; read -r new_ns
if [ -n "$new_ns" ] && [ "$new_ns" != "$current_ns" ]; then
sed -i "s/$current_ns/$new_ns/g" "$svc_file" > /dev/null 2>&1
systemctl daemon-reload; systemctl restart server-sldns > /dev/null 2>&1
echo -e "\n${GREEN}✓ Nameserver de SlowDNS actualizado a: $new_ns${NC}"
else echo -e "\n${RED}Acción cancelada o se ingresó el mismo NS.${NC}"; fi
pause_return
}
change_status() {
clear
m_encabezado "${BOLD}CAMBIAR MENSAJE DE STATUS (WS)${NC}"
proxy_file="/etc/socksproxy/proxy.js"
if [ ! -f "$proxy_file" ]; then echo -e "${RED}Archivo proxy.js no encontrado.${NC}"; pause_return; return; fi
line_num=$(grep -n "clientSocket.write('HTTP/1.1 101" "$proxy_file" | head -n1 | cut -d: -f1)
if [ -z "$line_num" ]; then echo -e "${RED}No se encontró la línea de status en proxy.js.${NC}"; pause_return; return; fi
current_status=$(sed -n "${line_num}p" "$proxy_file" | sed 's/^[[:space:]]*//')
echo -e " Línea Actual:\n ${YELLOW}${current_status}${NC}\n"
echo -e " Escribe el mensaje completo, libre: texto plano o HTML"
echo -e " (ej: <font color=\"red\">Mi Texto</font> <b>Extra</b>)."
echo -e " Nota: no uses comillas simples (') dentro del mensaje.\n"
echo -e -n " ${WHITE}Nuevo Mensaje de Status:${NC} "; read -r new_status
if [ -n "$new_status" ]; then
esc_msg=$(printf '%s' "$new_status" | sed "s/'/’/g")
awk -v ln="$line_num" -v msg="$esc_msg" 'NR==ln{printf "            clientSocket.write(%cHTTP/1.1 101 %s\\r\\n\\r\\n%c);\n", 39, msg, 39; next} {print}' "$proxy_file" > "${proxy_file}.tmp" && mv "${proxy_file}.tmp" "$proxy_file"
for u in $(systemctl list-units --all --type=service --no-legend 'ws-proxy@*' 2>/dev/null | awk '{print $1}'); do systemctl restart "$u"; done
echo -e "\n${GREEN}✓ Mensaje de status actualizado.${NC}"
else echo -e "\n${RED}Acción cancelada.${NC}"; fi
pause_return
}
change_banner() {
clear
m_encabezado "${BOLD}EDITAR BANNER (SSH / STUNNEL)${NC}"
echo -e " Se abrirá el banner en nano para que lo edites a tu gusto."
echo -e " Guarda con ${YELLOW}CTRL+O${NC} + ENTER y sal con ${YELLOW}CTRL+X${NC}.\n"
echo -e -n " ${WHITE}Presiona ENTER para continuar o escribe 0 para cancelar:${NC} "; read -r conf
if [ "$conf" = "0" ]; then echo -e "\n${RED}Acción cancelada.${NC}"; pause_return; return; fi
nano /etc/zorro-luffy
systemctl restart ssh stunnel4 2>/dev/null
echo -e "\n${GREEN}✓ Banner actualizado y servicios reiniciados.${NC}"
pause_return
}
advanced_menu() {
while true; do
clear
m_top
m_titulo "${WHITE}${BOLD}CONFIGURACIÓN AVANZADA${NC}"
m_sep
m_opcion "01" "Ver JSON crudo de Hysteria"
m_opcion "02" "Ver logs de servicios (journalctl)"
m_opcion "03" "Cambiar dominio/IP del servidor"
m_opcion "04" "Cambiar nameserver de SlowDNS (NS)"
m_fila "${WHITE}[${RED}05${WHITE}]${NC} ${RED}Desinstalar el script completo (peligro)${NC}"
m_opcion "06" "Cambiar mensaje de status (WS, HTML/texto libre)"
m_opcion "07" "Editar banner (SSH / Stunnel)"
m_opcion "08" "Reiniciar núcleo UDP (SlowDNS/Hysteria/ZiVPN/UDP-Custom)"
m_opcion "00" "${GRIS}Atrás${NC}"
m_bot
echo ""
echo -e -n "  ${WHITE}Selecciona una opción:${NC} "; read -r opt
case "$opt" in
1|01) clear; cat /etc/hysteria/config.json 2>/dev/null || echo "No encontrado."; pause_return ;;
2|02)
clear; echo -e "[1] SSH  [2] WS-Proxies  [3] Hysteria  [4] Stunnel  [5] SlowDNS  [6] Xray  [7] Hysteria 2\n"
echo -e -n " ${WHITE}Selecciona log:${NC} "; read -r lopt
case "$lopt" in
1) journalctl -u ssh -n 50 --no-pager ;;
2) journalctl -u ws-proxy@10080 -n 50 --no-pager ;;
3) journalctl -u hysteria-server -n 50 --no-pager ;;
4) journalctl -u stunnel4 -n 50 --no-pager ;;
5) journalctl -u server-sldns -n 50 --no-pager ;;
6) journalctl -u xray -n 50 --no-pager ;;
7) journalctl -u hysteria2-server -n 50 --no-pager ;;
esac; pause_return ;;
3|03) change_domain ;;
4|04) change_slowdns ;;
6|06) change_status ;;
7|07) change_banner ;;
8|08) restart_service "server-sldns hysteria-server hysteria2-server badvpn udp-custom zivpn" "UDP Core Services"; pause_return ;;
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
echo -e -n "  ${WHITE}¿Estás completamente seguro? [y/N]:${NC} "; read -r ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
echo -e "\n  ${YELLOW}▸${NC} ${GRIS}Deteniendo servicios...${NC}"
systemctl stop ws-proxy@* server-sldns badvpn hysteria-server hysteria2-server sslh stunnel4 squid nginx xray bhttp-server hcr-server 2>/dev/null || true
systemctl disable ws-proxy@* server-sldns badvpn hysteria-server hysteria2-server xray bhttp-server hcr-server 2>/dev/null || true
echo -e "  ${YELLOW}▸${NC} ${GRIS}Eliminando archivos...${NC}"
rm -f /etc/systemd/system/ws-proxy@.service /etc/systemd/system/server-sldns.service /etc/systemd/system/badvpn.service /etc/systemd/system/xray.service /etc/systemd/system/hysteria2-server.service /etc/systemd/system/bhttp-server.service /etc/systemd/system/hcr-server.service
rm -f /etc/cron.d/service-checker /etc/cron.d/logrotate /etc/cron.d/xray-expiry /etc/cron.d/hysteria-expiry /etc/cron.d/hysteria2-expiry /etc/sysctl.d/99-freenet-tuning.conf /etc/security/limits.d/99-freenet.conf
rm -rf /etc/deekayvpn /etc/slowdns /etc/socksproxy /etc/xray /etc/hysteria /etc/hysteria2 /etc/bhttp /etc/hcr /usr/local/bin/hysteria2 /usr/local/libexec/hysteria2-auth /usr/local/bin/menu /usr/bin/menu /usr/bin/Menu
systemctl daemon-reload; sysctl --system >/dev/null 2>&1 || true
echo -e "${GREEN}✓ Eliminación completa.${NC}"
else echo -e "  ${GRIS}Cancelado.${NC}"; fi
pause_return
}
draw_item() { printf "${ACC}║${NC}  ${WHITE}[${YELLOW}%s${WHITE}]${NC} %-56s${ACC}║${NC}\n" "$1" "$2"; }
draw_header() {
local os_name os_ver os arch cores ip hora estado ram cpu buf dom
os_name=$(. /etc/os-release 2>/dev/null; echo "${ID:-UNKNOWN}" | tr '[:lower:]' '[:upper:]')
os_ver=$(. /etc/os-release 2>/dev/null; echo "${VERSION_ID:-}")
os="${os_name} ${os_ver}"
arch=$(uname -m)
cores=$(cpu_count)
ip=$(server_ip)
hora=$(date '+%H:%M %Z')
estado=$(server_status)
ram=$(ram_percent)
cpu=$(cpu_percent)
buf=$(buffer_mem)
dom="${DOMAIN:-$ip}"
m_top
m_titulo "${WHITE}${BOLD}H E X   A U T O${NC}${GRIS}   ·   By JotchuaDevz${NC}"
m_sep
m_fila "$(printf "${GRIS}%s${NC}${WHITE}%s${NC}${GRIS}%s${NC}${WHITE}%s${NC}${GRIS}%s${NC}${WHITE}%s${NC}" \
"$(m_pad "SO" 7)" "$(m_pad "$os" 18)" "$(m_pad "ARQ" 6)" "$(m_pad "$arch" 10)" "$(m_pad "CPU" 6)" "$cores")"
m_fila "$(printf "${GRIS}%s${NC}${WHITE}%s${NC}${GRIS}%s${NC}${WHITE}%s${NC}" \
"$(m_pad "IP" 7)" "$(m_pad "$ip" 18)" "$(m_pad "HORA" 6)" "$hora")"
m_fila "$(printf "${GRIS}%s${NC}${WHITE}%s${NC}" "$(m_pad "HOST" 7)" "$dom")"
m_fila "$(printf "${GRIS}%s${NC}%s" "$(m_pad "ESTADO" 7)" "$estado")"
m_sep
m_titulo "${WHITE}${BOLD}PUERTOS EN SERVICIO${NC}"
m_par "SSH"          "22, 299"        "System-DNS"  "53"
m_par "WEB-Nginx"    "85"             "SSL"         "443"
m_par "SSL/PYTHON"   "443"            "Squid"       "3128, 8000"
m_par "WS/PYTHON"    "80, 8080, 8880" "BadVPN"      "7300"
m_par "WS/PYTHON"    "2082, 2086, 25" "XRAY NTLS"   "80, 8080, 8880"
m_par "XRAY TLS"     "443"            "SlowDNS"     "53"
m_par "BHTTP"        "8180, 8280"     "SOCKS"       "127.0.0.1:1080"
m_par "HCR"          "8780"           "Hysteria 1"  "20000-50000"
m_par "Hysteria 2"   "36713/UDP"      ""            ""
m_par "UDP Custom"   "1-65535"        ""            ""
m_par "ZiVPN"        "6000-19999"     ""            ""
m_sep
m_fila "$(printf "${GRIS}%s${NC}${YELLOW}%s${NC}${GRIS}%s${NC}${YELLOW}%s${NC}${GRIS}%s${NC}${YELLOW}%s${NC}" \
"$(m_pad "RAM" 7)" "$(m_pad "$ram" 13)" "$(m_pad "CPU" 6)" "$(m_pad "$cpu" 12)" "$(m_pad "BUFFER" 8)" "$buf")"
m_bot
}
while true; do
clear; draw_header; echo
m_top
m_titulo "${WHITE}${BOLD}MENÚ PRINCIPAL${NC}"
m_sep
m_opcion2 "01" "Cuentas SSH (Legado)"     "02" "Cuentas Xray (V2Ray)"
m_opcion2 "03" "Cuentas Hysteria (UDP)"   "04" "Cuentas Hysteria 2 (UDP)"
m_opcion2 "05" "Cuentas ZiVPN (UDP)"      "06" "Conexiones Activas"
m_opcion2 "07" "Control de Servicios"     "08" "Backup y Restaurar"
m_opcion2 "09" "Utilidades (BBR/Netflix)" "10" "Configuración Avanzada"
m_opcion2 "11" "Reiniciar Servidor"       "12" "Gestión BHTTP"
m_opcion "13" "Gestión HCR"
m_opcion "00" "${GRIS}Salir${NC}"
m_bot
echo ""
echo -e -n "  ${BG_SEL} ► ${NC} ${ACC3}Selecciona una opción:${NC} "
read -r opt
case "$opt" in
1|01)
while true; do
clear
m_top
m_titulo "${WHITE}${BOLD}GESTIÓN DE CUENTAS SSH${NC}"
m_sep
m_opcion "1" "Crear usuario SSH"
m_opcion "2" "Extender expiración"
m_opcion "3" "Eliminar usuario SSH"
m_opcion "4" "Listar todas las cuentas"
m_opcion "5" "Crear usuario Token"
m_opcion "6" "Contraseña general (Token)"
m_opcion "0" "${GRIS}Atrás${NC}"
m_bot
echo -e -n "  ${BG_SEL} ► ${NC} "; read -r sub
case "$sub" in 1) create_user;; 2) extend_user;; 3) delete_user;; 4) clear; i=1; while IFS= read -r u; do echo "$i. $(display_name_for_user "$u")"; i=$((i+1)); done < <(list_real_users); pause_return;; 5) create_token_user;; 6) set_token_password;; 0) break;; esac
done ;;
2|02)
while true; do
clear
m_top
m_titulo "${WHITE}${BOLD}GESTIÓN DE CUENTAS XRAY${NC}"
m_sep
m_opcion "1" "Agregar cuenta Xray"
m_opcion "2" "Renovar cuenta Xray"
m_opcion "3" "Eliminar cuenta Xray"
m_opcion "4" "Mostrar enlaces de configuración"
m_opcion "5" "Forzar eliminación de cuentas expiradas"
m_opcion "6" "Actualizar versión de Xray Core"
m_opcion "0" "${GRIS}Atrás${NC}"
m_bot
echo -e -n "  ${BG_SEL} ► ${NC} "; read -r sub
case "$sub" in 1) add_xray;; 2) renew_xray;; 3) del_xray;; 4) show_xray;; 5) /usr/local/bin/exp-check; echo "Usuarios Xray expirados eliminados."; pause_return;; 6) systemctl stop xray; XRAY_VER="v26.5.9"; echo "Reinstalando Xray Core ${XRAY_VER}..."; wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/Xray-linux-64.zip"; unzip -q -o /tmp/xray.zip -d /tmp/xray/ && mv -f /tmp/xray/xray /usr/local/bin/xray; systemctl start xray; echo -e "${GREEN}✓ ¡Xray Restaurado a ${XRAY_VER}!${NC}"; pause_return;; 0) break;; esac
done ;;
3|03)
while true; do
clear
m_top
m_titulo "${WHITE}${BOLD}GESTIÓN DE CUENTAS HYSTERIA${NC}"
m_sep
m_opcion "1" "Agregar cuenta Hysteria"
m_opcion "2" "Renovar cuenta Hysteria"
m_opcion "3" "Eliminar cuenta Hysteria"
m_opcion "4" "Listar todas las cuentas"
m_opcion "5" "Editar velocidades de subida/bajada"
m_opcion "6" "Cambiar obfs"
m_opcion "0" "${GRIS}Atrás${NC}"
m_bot
echo -e -n "  ${BG_SEL} ► ${NC} "; read -r sub
case "$sub" in 1) add_hysteria;; 2) extend_hysteria;; 3) del_hysteria;; 4) list_hysteria;; 5) speed_hysteria;; 6) change_obfs_hysteria;; 0) break;; esac
done ;;
4|04)
while true; do
clear
m_top
m_titulo "${WHITE}${BOLD}GESTIÓN DE CUENTAS HYSTERIA 2${NC}"
m_sep
m_opcion "1" "Agregar cuenta Hysteria 2"
m_opcion "2" "Renovar cuenta Hysteria 2"
m_opcion "3" "Eliminar cuenta Hysteria 2"
m_opcion "4" "Listar todas las cuentas"
m_opcion "5" "Mostrar enlace de cuenta"
m_opcion "0" "${GRIS}Atrás${NC}"
m_bot
echo -e -n "  ${BG_SEL} ► ${NC} "; read -r sub
case "$sub" in 1) add_hysteria2;; 2) extend_hysteria2;; 3) del_hysteria2;; 4) list_hysteria2;; 5) show_hysteria2;; 0) break;; esac
done ;;
5|05)
while true; do
clear
m_top
m_titulo "${WHITE}${BOLD}GESTIÓN DE CUENTAS ZIVPN${NC}"
m_sep
m_opcion "1" "Agregar cuenta ZiVPN"
m_opcion "2" "Renovar cuenta ZiVPN"
m_opcion "3" "Eliminar cuenta ZiVPN"
m_opcion "4" "Listar todas las cuentas"
m_opcion "5" "Activar cuenta"
m_opcion "6" "Desactivar cuenta"
m_opcion "0" "${GRIS}Atrás${NC}"
m_bot
echo -e -n "  ${BG_SEL} ► ${NC} "; read -r sub
case "$sub" in 1) add_zivpn;; 2) extend_zivpn;; 3) del_zivpn;; 4) list_zivpn;; 5) activar_zivpn;; 6) desactivar_zivpn;; 0) break;; esac
done ;;
6|06) online_users ;;
7|07) service_control_menu ;;
8|08)
clear
m_top
m_titulo "${WHITE}${BOLD}BACKUP Y RESTAURACIÓN${NC}"
m_sep
m_opcion "1" "Respaldar configuraciones del sistema"
m_opcion "2" "Restaurar desde respaldo"
m_opcion "0" "${GRIS}Atrás${NC}"
m_bot
echo ""
echo -e -n "  ${BG_SEL} ► ${NC} ${ACC3}Selecciona una opción:${NC} "; read -r subopt
case "$subopt" in 1) backup_snapshot;; 2) restore_snapshot;; esac ;;
9|09) utilities_menu ;;
10) advanced_menu ;;
11) clear; echo -e -n " ${WHITE}¿Reiniciar el servidor ahora? [y/N]:${NC} "; read -r ans; [[ "$ans" =~ ^[Yy]$ ]] && reboot ;;
12)
BHTTP_UNIT="bhttp-server.service"
BHTTP_BIN="/etc/bhttp/bin/bhttp-server"
BHTTP_SYSCTL="/etc/sysctl.d/bhttp-performance.conf"
BHTTP_BK_DIR="/var/backups/bhttp-hex"
while true; do
clear
m_top
m_titulo "${WHITE}${BOLD}GESTIÓN BHTTP${NC}"
m_sep
bh_port=$(grep -oE -- '--port [0-9]+' /etc/systemd/system/$BHTTP_UNIT 2>/dev/null | awk '{print $2}')
bh_backend=$(grep -oE -- '--backend-port [0-9]+' /etc/systemd/system/$BHTTP_UNIT 2>/dev/null | awk '{print $2}')
bh_sessions=$(grep -oE -- '--max-sessions [0-9]+' /etc/systemd/system/$BHTTP_UNIT 2>/dev/null | awk '{print $2}')
bh_state=$(systemctl is-active $BHTTP_UNIT 2>/dev/null || echo "inactivo")
m_fila "  Puerto: ${YELLOW}${bh_port:-N/D}${NC}  Backend SSH: ${YELLOW}${bh_backend:-N/D}${NC}  Sesiones: ${YELLOW}${bh_sessions:-N/D}${NC}  Estado: ${YELLOW}${bh_state}${NC}"
m_sep
m_opcion "1" "Cambiar puerto BHTTP"
m_opcion "2" "Cambiar puerto backend SSH"
m_opcion "3" "Ajustar máximo de sesiones"
m_opcion "4" "Ver logs (journalctl)"
m_opcion "5" "Autoprueba (self-test + backend + listener)"
m_opcion "6" "Rollback al motor anterior"
m_opcion "7" "Reiniciar BHTTP"
m_opcion "0" "${GRIS}Atrás${NC}"
m_bot
echo ""
echo -e -n "  ${BG_SEL} ► ${NC} ${ACC3}Selecciona una opción:${NC} "; read -r bhopt
case "$bhopt" in
1)
read -rp "$(echo -e "${BOLD}Nuevo puerto BHTTP: ${NC}")" newport
if [[ "$newport" =~ ^[0-9]+$ ]] && [ "$newport" -ge 1 ] && [ "$newport" -le 65535 ]; then
    if ss -lntp 2>/dev/null | grep -q ":${newport}[[:space:]]"; then
        echo -e "${RED}✗ El puerto $newport ya está ocupado.${NC}"
    else
        sed -i "s/--port [0-9]\+/--port $newport/" /etc/systemd/system/$BHTTP_UNIT
        iptables -C INPUT -p tcp --dport $newport -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport $newport -j ACCEPT >/dev/null 2>&1
        command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1
        systemctl daemon-reload; systemctl restart $BHTTP_UNIT
        echo -e "${GREEN}✓ Puerto BHTTP cambiado a $newport.${NC}"
    fi
else
    echo -e "${RED}✗ Puerto inválido.${NC}"
fi
pause_return ;;
2)
read -rp "$(echo -e "${BOLD}Nuevo puerto backend SSH: ${NC}")" newbackend
if [[ "$newbackend" =~ ^[0-9]+$ ]] && [ "$newbackend" -ge 1 ] && [ "$newbackend" -le 65535 ]; then
    sed -i "s/--backend-port [0-9]\+/--backend-port $newbackend/" /etc/systemd/system/$BHTTP_UNIT
    systemctl daemon-reload; systemctl restart $BHTTP_UNIT
    if ss -lnt 2>/dev/null | grep -q ":${newbackend}[[:space:]]"; then
        echo -e "${GREEN}✓ Backend SSH cambiado a $newbackend.${NC}"
    else
        echo -e "${YELLOW}⚠ Backend cambiado, pero no detecto un listener SSH en :$newbackend. Revisa antes de probar la app.${NC}"
    fi
else
    echo -e "${RED}✗ Puerto inválido.${NC}"
fi
pause_return ;;
3)
read -rp "$(echo -e "${BOLD}Máximo de sesiones simultáneas (actual: ${bh_sessions:-N/D}): ${NC}")" newsessions
if [[ "$newsessions" =~ ^[0-9]+$ ]] && [ "$newsessions" -ge 1 ] && [ "$newsessions" -le 32768 ]; then
    sed -i "s/--max-sessions [0-9]\+/--max-sessions $newsessions/" /etc/systemd/system/$BHTTP_UNIT
    systemctl daemon-reload; systemctl restart $BHTTP_UNIT
    echo -e "${GREEN}✓ Máximo de sesiones ajustado a $newsessions.${NC}"
else
    echo -e "${RED}✗ Valor inválido (1-32768).${NC}"
fi
pause_return ;;
4)
journalctl -u $BHTTP_UNIT -n 80 --no-pager
pause_return ;;
5)
echo -e "  ${BG_SEL} AUTOPRUEBA BHTTP ${NC}"
if [ -x "$BHTTP_BIN" ]; then
    "$BHTTP_BIN" --self-test && echo -e "${GREEN}✓ Self-test BHP1 PASS${NC}" || echo -e "${RED}✗ Self-test BHP1 FAIL${NC}"
else
    echo -e "${RED}✗ Binario BHTTP no encontrado en $BHTTP_BIN${NC}"
fi
if [ -n "$bh_backend" ] && ss -lnt 2>/dev/null | grep -q ":${bh_backend}[[:space:]]"; then
    echo -e "${GREEN}✓ SSH backend 127.0.0.1:$bh_backend PASS${NC}"
else
    echo -e "${RED}✗ SSH backend no escucha en :${bh_backend:-N/D}${NC}"
fi
if systemctl is-active --quiet $BHTTP_UNIT && [ -n "$bh_port" ] && ss -lnt 2>/dev/null | grep -q ":${bh_port}[[:space:]]"; then
    echo -e "${GREEN}✓ Listener :$bh_port + autostart PASS${NC}"
else
    echo -e "${RED}✗ Listener :${bh_port:-N/D} no está activo/escuchando${NC}"
fi
pause_return ;;
6)
if [ -x "${BHTTP_BK_DIR}/engine.previous" ]; then
    read -rp "$(echo -e "${YELLOW}Esto restaura el motor BHTTP anterior. Escribe SI para confirmar: ${NC}")" rbconfirm
    if [ "$rbconfirm" = "SI" ]; then
        systemctl stop $BHTTP_UNIT >/dev/null 2>&1 || true
        cp -a "${BHTTP_BK_DIR}/engine.previous" "$BHTTP_BIN"
        chmod 755 "$BHTTP_BIN"
        systemctl start $BHTTP_UNIT
        echo -e "${GREEN}✓ Motor BHTTP anterior restaurado.${NC}"
    else
        echo -e "  ${GRIS}Cancelado.${NC}"
    fi
else
    echo -e "${RED}✗ No hay motor anterior guardado en ${BHTTP_BK_DIR}.${NC}"
fi
pause_return ;;
7)
systemctl restart $BHTTP_UNIT
sleep .5
systemctl is-active --quiet $BHTTP_UNIT && echo -e "${GREEN}✓ BHTTP reiniciado y activo.${NC}" || echo -e "${RED}✗ BHTTP no quedó activo. Revisa: journalctl -u $BHTTP_UNIT${NC}"
pause_return ;;
0) break ;;
esac
done
;;
13)
HCR_UNIT="hcr-server.service"
HCR_BIN="/etc/hcr/bin/hcr-server"
HCR_BK_DIR="/var/backups/hcr-hex"
while true; do
clear
m_top
m_titulo "${WHITE}${BOLD}GESTIÓN HCR${NC}"
m_sep
hcr_port=$(grep -oE -- '--listen :[0-9]+' /etc/systemd/system/$HCR_UNIT 2>/dev/null | grep -oE '[0-9]+')
hcr_target=$(grep -oE -- '--target [^ ]+' /etc/systemd/system/$HCR_UNIT 2>/dev/null | awk '{print $2}')
hcr_transport=$(grep -oE -- '--transport [a-z]+' /etc/systemd/system/$HCR_UNIT 2>/dev/null | awk '{print $2}')
hcr_state=$(systemctl is-active $HCR_UNIT 2>/dev/null || echo "inactivo")
m_fila "  Puerto: ${YELLOW}${hcr_port:-N/D}${NC}  Destino: ${YELLOW}${hcr_target:-N/D}${NC}  Transporte: ${YELLOW}${hcr_transport:-N/D}${NC}  Estado: ${YELLOW}${hcr_state}${NC}"
m_sep
m_opcion "1" "Cambiar puerto HCR"
m_opcion "2" "Cambiar destino (backend SSH)"
m_opcion "3" "Cambiar transporte (plain/tls/auto)"
m_opcion "4" "Ver logs (journalctl)"
m_opcion "5" "Autoprueba (binario + listener)"
m_opcion "6" "Rollback al motor anterior"
m_opcion "7" "Reiniciar HCR"
m_opcion "0" "${GRIS}Atrás${NC}"
m_bot
echo ""
echo -e -n "  ${BG_SEL} ► ${NC} ${ACC3}Selecciona una opción:${NC} "; read -r hcropt
case "$hcropt" in
1)
read -rp "$(echo -e "${BOLD}Nuevo puerto HCR: ${NC}")" newport
if [[ "$newport" =~ ^[0-9]+$ ]] && [ "$newport" -ge 1 ] && [ "$newport" -le 65535 ]; then
    if ss -lntp 2>/dev/null | grep -q ":${newport}[[:space:]]"; then
        echo -e "${RED}✗ El puerto $newport ya está ocupado.${NC}"
    else
        sed -i "s/--listen :[0-9]\+/--listen :$newport/" /etc/systemd/system/$HCR_UNIT
        iptables -C INPUT -p tcp --dport $newport -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport $newport -j ACCEPT >/dev/null 2>&1
        command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1
        systemctl daemon-reload; systemctl restart $HCR_UNIT
        echo -e "${GREEN}✓ Puerto HCR cambiado a $newport.${NC}"
    fi
else
    echo -e "${RED}✗ Puerto inválido.${NC}"
fi
pause_return ;;
2)
read -rp "$(echo -e "${BOLD}Nuevo destino (HOST:PUERTO, ej. 127.0.0.1:22): ${NC}")" newtarget
if [[ "$newtarget" =~ ^[A-Za-z0-9.-]+:[0-9]+$ ]]; then
    sed -i "s|--target [^ ]\+|--target $newtarget|" /etc/systemd/system/$HCR_UNIT
    systemctl daemon-reload; systemctl restart $HCR_UNIT
    echo -e "${GREEN}✓ Destino cambiado a $newtarget.${NC}"
else
    echo -e "${RED}✗ Destino inválido. Usa HOST:PUERTO.${NC}"
fi
pause_return ;;
3)
read -rp "$(echo -e "${BOLD}Transporte (plain/tls/auto): ${NC}")" newtransport
if [[ "$newtransport" == "plain" || "$newtransport" == "tls" || "$newtransport" == "auto" ]]; then
    sed -i "s/--transport [a-z]\+/--transport $newtransport/" /etc/systemd/system/$HCR_UNIT
    if [[ "$newtransport" != "plain" ]] && ! grep -q -- '--tls-cert' /etc/systemd/system/$HCR_UNIT; then
        sed -i "s|--transport $newtransport|--transport $newtransport --tls-cert /etc/xray/xray.crt --tls-key /etc/xray/xray.key|" /etc/systemd/system/$HCR_UNIT
    fi
    systemctl daemon-reload; systemctl restart $HCR_UNIT
    if systemctl is-active --quiet $HCR_UNIT; then
        echo -e "${GREEN}✓ Transporte cambiado a $newtransport.${NC}"
    else
        echo -e "${RED}✗ El servicio no quedó activo con transporte $newtransport. Revisa: journalctl -u $HCR_UNIT${NC}"
    fi
else
    echo -e "${RED}✗ Transporte inválido.${NC}"
fi
pause_return ;;
4)
journalctl -u $HCR_UNIT -n 80 --no-pager
pause_return ;;
5)
echo -e "  ${BG_SEL} AUTOPRUEBA HCR ${NC}"
if [ -x "$HCR_BIN" ]; then
    "$HCR_BIN" --help > /dev/null 2>&1 && echo -e "${GREEN}✓ Binario HCR responde${NC}" || echo -e "${RED}✗ Binario HCR no responde${NC}"
else
    echo -e "${RED}✗ Binario HCR no encontrado en $HCR_BIN${NC}"
fi
if [ -n "$hcr_port" ] && systemctl is-active --quiet $HCR_UNIT && ss -lnt 2>/dev/null | grep -q ":${hcr_port}[[:space:]]"; then
    echo -e "${GREEN}✓ Listener :$hcr_port + autostart PASS${NC}"
else
    echo -e "${RED}✗ Listener :${hcr_port:-N/D} no está activo/escuchando${NC}"
fi
pause_return ;;
6)
if [ -x "${HCR_BK_DIR}/engine.previous" ]; then
    read -rp "$(echo -e "${YELLOW}Esto restaura el motor HCR anterior. Escribe SI para confirmar: ${NC}")" rbconfirm
    if [ "$rbconfirm" = "SI" ]; then
        systemctl stop $HCR_UNIT >/dev/null 2>&1 || true
        cp -a "${HCR_BK_DIR}/engine.previous" "$HCR_BIN"
        chmod 755 "$HCR_BIN"
        systemctl start $HCR_UNIT
        echo -e "${GREEN}✓ Motor HCR anterior restaurado.${NC}"
    else
        echo -e "  ${GRIS}Cancelado.${NC}"
    fi
else
    echo -e "${RED}✗ No hay motor anterior guardado en ${HCR_BK_DIR}.${NC}"
fi
pause_return ;;
7)
systemctl restart $HCR_UNIT
sleep .5
systemctl is-active --quiet $HCR_UNIT && echo -e "${GREEN}✓ HCR reiniciado y activo.${NC}" || echo -e "${RED}✗ HCR no quedó activo. Revisa: journalctl -u $HCR_UNIT${NC}"
pause_return ;;
0) break ;;
esac
done
;;
0|00) clear; exit 0 ;;
esac
done
EOF_MENU
sed -i "s|DOMAIN_PLACEHOLDER|$DOMAIN|g" /usr/local/bin/menu > /dev/null 2>&1
chmod +x /usr/local/bin/menu > /dev/null 2>&1
cp /usr/local/bin/menu /usr/bin/menu > /dev/null 2>&1
cp /usr/local/bin/menu /usr/bin/Menu > /dev/null 2>&1
if [ "$USE_LETSENCRYPT" = true ]; then
mkdir -p /etc/letsencrypt/renewal-hooks/pre /etc/letsencrypt/renewal-hooks/post /etc/letsencrypt/renewal-hooks/deploy > /dev/null 2>&1
cat <<'EOF_PRE' > /etc/letsencrypt/renewal-hooks/pre/hex-tunnel-stop.sh
#!/bin/bash
systemctl stop haproxy nginx xray 2>/dev/null || true
sleep 1
EOF_PRE
cat <<'EOF_POST' > /etc/letsencrypt/renewal-hooks/post/hex-tunnel-start.sh
#!/bin/bash
systemctl start xray haproxy nginx 2>/dev/null || true
EOF_POST
cat <<'EOF_RENEW' > /etc/letsencrypt/renewal-hooks/deploy/hex-tunnel.sh
#!/bin/bash
set -e
for domain in $RENEWED_DOMAINS; do
install -m 644 "/etc/letsencrypt/live/$domain/fullchain.pem" /etc/xray/xray.crt
install -m 600 "/etc/letsencrypt/live/$domain/privkey.pem" /etc/xray/xray.key
cat "/etc/letsencrypt/live/$domain/privkey.pem" "/etc/letsencrypt/live/$domain/fullchain.pem" > /etc/stunnel/stunnel.pem
chmod 600 /etc/stunnel/stunnel.pem
systemctl restart xray stunnel4 2>/dev/null || true
systemctl restart hysteria2-server 2>/dev/null || true
break
done
EOF_RENEW
chmod +x /etc/letsencrypt/renewal-hooks/pre/hex-tunnel-stop.sh /etc/letsencrypt/renewal-hooks/post/hex-tunnel-start.sh /etc/letsencrypt/renewal-hooks/deploy/hex-tunnel.sh > /dev/null 2>&1
echo "17 3 * * * root certbot renew --quiet" > /etc/cron.d/certbot-renew
chmod 644 /etc/cron.d/certbot-renew > /dev/null 2>&1
fi
fase "Verificación final"
chown -R www-data:www-data /home/vps/public_html > /dev/null 2>&1
servicio_estado() {
if systemctl is-active --quiet "$1" 2>/dev/null; then
printf "${OKC}● activo${NC}"
else
printf "${RED}● inactivo${NC}"
fi
}
esperar_descargas
rm -rf "$CACHE_DESCARGAS" > /dev/null 2>&1
TIEMPO_TOTAL="$(tiempo_transcurrido)"
clear
echo ""
titulo_ascii "HEX AUTO"
echo ""
ui_top
ui_titulo "${WHITE}${BOLD}INSTALACIÓN COMPLETADA${NC}"
ui_sep
ui_fila "${GRIS}Dominio      ${NC} ${WHITE}${DOMAIN}${NC}"
ui_fila "${GRIS}IP servidor  ${NC} ${WHITE}${IPADDR}${NC}"
ui_fila "${GRIS}Certificado  ${NC} ${WHITE}$(cat /etc/xray/cert_type 2>/dev/null || echo desconocido)${NC}"
ui_fila "${GRIS}SlowDNS NS   ${NC} ${WHITE}${Nameserver}${NC}"
ui_fila "${GRIS}Obfs / clave ${NC} ${WHITE}${OBFS} / ${PASSWORD}${NC}"
ui_fila "${GRIS}Duración     ${NC} ${WHITE}${TIEMPO_TOTAL}${NC}   ${GRIS}registro${NC} ${WHITE}${LOG_INSTALACION}${NC}"
ui_sep
ui_fila "${WHITE}${BOLD}Servicios${NC}"
ui_fila "  ${GRIS}SSH${NC} $(servicio_estado "$SSH_SERVICE")   ${GRIS}Xray${NC} $(servicio_estado xray)   ${GRIS}Stunnel${NC} $(servicio_estado "$STUNNEL_SERVICE")"
ui_fila "  ${GRIS}Nginx${NC} $(servicio_estado "$NGINX_SERVICE")   ${GRIS}Squid${NC} $(servicio_estado "$SQUID_SERVICE")   ${GRIS}SSLH${NC} $(servicio_estado "$SSLH_SERVICE")"
ui_fila "  ${GRIS}Hysteria 1${NC} $(servicio_estado hysteria-server)   ${GRIS}Hysteria 2${NC} $(servicio_estado hysteria2-server)"
ui_fila "  ${GRIS}SlowDNS${NC} $(servicio_estado server-sldns)   ${GRIS}ZiVPN${NC} $(servicio_estado zivpn)   ${GRIS}UDP${NC} $(servicio_estado udp-custom)"
ui_fila "  ${GRIS}BHTTP${NC} $(servicio_estado "bhttp-server") ($BHTTP_PORT1) Créditos A @DarkZFull"
ui_fila "  ${GRIS}HCR${NC} $(servicio_estado "hcr-server") ($HCR_PORT1)"
ui_sep
ui_fila "${GRIS}Escribe${NC} ${YELLOW}${BOLD}menu${NC} ${GRIS}para abrir el panel de administración.${NC}"
ui_bot
echo ""
history -c > /dev/null 2>&1; rm /root/full.sh 2>/dev/null || true
ui_aviso "Se recomienda reiniciar el servidor para aplicar todos los cambios."
for i in {5..1}; do
printf "\r  ${ACC2}●${NC} ${GRIS}Finalizando en${NC} ${WHITE}%s${NC}${GRIS}...${NC}\033[K" "$i"
sleep 1
done
printf "\r  ${OKC}✓${NC} ${WHITE}${BOLD}Listo.${NC}\033[K\n"
if [ "$REINICIAR_AL_FINAL" = "si" ]; then
ui_info "Reiniciando ahora..."
sleep 1
reboot
else
ui_info "Cuando quieras aplicar todo, ejecuta: ${WHITE}reboot${NC}"
fi