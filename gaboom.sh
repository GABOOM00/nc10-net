#!/usr/bin/env bash
#
# gaboom - Comando principale del progetto: dashboard, help e lancio comandi
# Uso:  gaboom            (dashboard)
#       gaboom help       (elenco comandi)
#       gaboom net|set|fix|server
#

GABOOM_VERSIONE="2.7.0"

# Riconoscimento automatico del terminale:
# - versione LEGGERA (testo puro, zero escape) su ROXTerm, console pura,
#   terminali datati, locale non UTF-8 o output rediretto
# - versione PESANTE (colori) su terminali moderni (Termius, ssh da PC, ecc.)
terminale_moderno() {
    # Output non interattivo (pipe/file): sempre leggera
    [ -t 1 ] || return 1
    # ROXTerm si annuncia con queste variabili: versione leggera
    if [ -n "$ROXTERM_ID" ] || [ -n "$ROXTERM_PID" ] || [ -n "$ROXTERM_NUM" ]; then
        return 1
    fi
    # Terminali senza capacita' dichiarate
    command -v tput >/dev/null 2>&1 || return 1
    [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ] || return 1
    case "$TERM" in
        dumb|linux|vt*|"") return 1 ;;
    esac
    # Codifica non UTF-8: meglio leggera
    locale 2>/dev/null | grep -qi 'utf-*8' || return 1
    return 0
}

if terminale_moderno; then
    VERDE='\033[0;32m'; ROSSO='\033[0;31m'; GIALLO='\033[1;33m'; CIANO='\033[0;36m'; RESET='\033[0m'
else
    VERDE=''; ROSSO=''; GIALLO=''; CIANO=''; RESET=''
fi

banner() {
    echo -e "${CIANO}"
    cat <<'EOF'
  ____    _    ____   ___   ___  __  __
 / ___|  / \  | __ ) / _ \ / _ \|  \/  |
| |  _  / _ \ |  _ \| | | | | | | |\/| |
| |_| |/ ___ \| |_) | |_| | |_| | |  | |
 \____/_/   \_\____/ \___/ \___/|_|  |_|
EOF
    echo -e "${RESET}"
    echo "  gaboom v$GABOOM_VERSIONE - $(date '+%d/%m/%Y') $(date '+%H:%M')"
}

titolo() {
    echo ""
    echo -e "${GIALLO}$1${RESET}"
    echo "  --------------------------------------------"
}

riga() {
    # $1 = etichetta, $2 = valore
    printf "  %-12s : %s\n" "$1" "$2"
}

stato_servizio() {
    # $1 = etichetta, $2 = nome processo da cercare
    # Il pattern [x]yz impedisce al grep di rilevare se stesso (falsi positivi)
    local pattern="[${2:0:1}]${2:1}"
    if ps -eo args= 2>/dev/null | grep -q "$pattern"; then
        printf "  %-12s : $(echo -e "${VERDE}[+] ATTIVO${RESET}")\n" "$1"
    elif command -v "$2" >/dev/null 2>&1; then
        printf "  %-12s : [-] spento\n" "$1"
    else
        printf "  %-12s : [ ] non installato\n" "$1"
    fi
}

mostra_info() {
    banner

    # ================= SYSTEM =================
    titolo "SYSTEM"
    riga "Host"   "$(hostname 2>/dev/null)"
    if [ -f /etc/os-release ]; then
        riga "OS" "$(. /etc/os-release && echo "$PRETTY_NAME")"
    fi
    riga "Kernel" "$(uname -r)"
    riga "Arch"   "$(uname -m)"
    riga "Shell"  "$(basename "${SHELL:-sconosciuta}")"
    if [ -r /sys/devices/virtual/dmi/id/product_name ]; then
        riga "Model" "$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)"
    fi
    riga "Uptime" "$(uptime -p 2>/dev/null | sed 's/up //' || uptime | sed 's/.*up \([^,]*\),.*/\1/')"

    # ================= RESOURCES =================
    titolo "RESOURCES"
    local cpu_modello carico
    cpu_modello=$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo 2>/dev/null)
    carico=$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null)
    riga "CPU"    "${cpu_modello:-sconosciuta}"
    riga "Load"   "${carico:-n/d}"
    riga "Memory" "$(free -m 2>/dev/null | awk '/^Mem/ {print $3 " MB / " $2 " MB"}')"
    riga "Swap"   "$(free -m 2>/dev/null | awk '/^Swap/ {if ($2==0) print "assente"; else print $3 " MB / " $2 " MB"}')"
    riga "Disk"   "$(df -h / 2>/dev/null | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')"
    local temp=""
    if [ -r /sys/class/thermal/thermal_zone0/temp ]; then
        temp="$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 )) C"
    elif command -v acpi >/dev/null 2>&1; then
        temp=$(acpi -t 2>/dev/null | awk -F', ' '{print $2}' | head -n1)
    fi
    riga "Temp" "${temp:-non rilevabile}"

    # ================= NETWORK =================
    titolo "NETWORK"
    local iface ip4 ip6 gw ssh_porta ts_ip
    iface=$(ip route 2>/dev/null | awk '/^default/ {print $5; exit}')
    if [ -n "$iface" ]; then
        ip4=$(ip -o -4 addr show "$iface" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
        ip6=$(ip -o -6 addr show "$iface" scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)
        gw=$(ip route | awk '/^default/ {print $3; exit}')
        riga "Interface" "$iface"
        riga "LAN"       "${ip4:-nessuno}"
        riga "IPv6"      "${ip6:-nessuno}"
        riga "Gateway"   "${gw:-nessuno}"
        if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
            riga "Internet" "$(echo -e "${VERDE}[+] FUNZIONA${RESET}")"
        else
            riga "Internet" "$(echo -e "${GIALLO}[!] NON RISPONDE${RESET} (prova: gaboom fix)")"
        fi
    else
        riga "Connessione" "$(echo -e "${GIALLO}[!] NESSUNA${RESET} (usa: gaboom net)")"
    fi
    ssh_porta=$(awk '/^[Pp]ort / {print $2; exit}' /etc/ssh/sshd_config 2>/dev/null)
    riga "SSH Port" "${ssh_porta:-22 (default)}"
    if command -v tailscale >/dev/null 2>&1; then
        ts_ip=$(tailscale ip -4 2>/dev/null | head -n1)
        riga "Tailscale" "${ts_ip:-attivo ma senza IP}"
    else
        riga "Tailscale" "[ ] non installato"
    fi

    # --- Rete di sistema (nc10-net) ---
    if [ -r /etc/nc10-net.conf ]; then
        local TIPO="" SSID=""
        . /etc/nc10-net.conf 2>/dev/null
        case "$TIPO" in
            wifi)     riga "Rete sistema" "WiFi \"$SSID\"" ;;
            usb)      riga "Rete sistema" "telefono via cavo USB" ;;
            ethernet) riga "Rete sistema" "cavo ethernet" ;;
            *)        riga "Rete sistema" "non impostata (gaboom set)" ;;
        esac
    elif [ -f /etc/nc10-net.conf ]; then
        riga "Rete sistema" "impostata (sudo gaboom per i dettagli)"
    else
        riga "Rete sistema" "non impostata (gaboom set)"
    fi

    # --- Server domestico ---
    local srv_ip
    srv_ip=$(grep -m1 '^SERVER_IP=' /usr/local/bin/nc10-server 2>/dev/null | cut -d'"' -f2)
    if [ -n "$srv_ip" ] && [ "$srv_ip" != "192.168.1.XX" ]; then
        if ping -c 1 -W 2 "$srv_ip" >/dev/null 2>&1; then
            riga "Server" "$(echo -e "$srv_ip ${VERDE}[+] ACCESO${RESET} (gaboom server)")"
        else
            riga "Server" "$(echo -e "$srv_ip ${GIALLO}[!] NON RAGGIUNGIBILE${RESET}")"
        fi
    else
        riga "Server" "non configurato"
    fi

    # ================= SERVICES =================
    titolo "SERVICES"
    stato_servizio "SSH"         "sshd"
    stato_servizio "Docker"      "dockerd"
    stato_servizio "Tailscale"   "tailscaled"
    stato_servizio "Code Server" "code-server"
    stato_servizio "Bettercap"   "bettercap"
    if command -v wg >/dev/null 2>&1; then
        if [ -n "$(wg show interfaces 2>/dev/null)" ]; then
            riga "WireGuard" "$(echo -e "${VERDE}[+] ATTIVO${RESET} ($(wg show interfaces 2>/dev/null))")"
        else
            riga "WireGuard" "[-] spento"
        fi
    else
        riga "WireGuard" "[ ] non installato"
    fi
    if command -v docker >/dev/null 2>&1 && pgrep -x dockerd >/dev/null 2>&1; then
        riga "Containers" "$(docker ps -q 2>/dev/null | wc -l) attivi"
    else
        riga "Containers" "n/d"
    fi

    # ================= STATUS =================
    titolo "STATUS"
    if command -v apt >/dev/null 2>&1; then
        local agg
        agg=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
        if [ "$agg" -gt 0 ]; then
            riga "Updates" "$agg pacchetti aggiornabili (sudo apt upgrade)"
        else
            riga "Updates" "sistema aggiornato"
        fi
    fi
    echo ""
}

mostra_help() {
    echo ""
    echo -e "${CIANO}=============================================${RESET}"
    echo -e "${CIANO}   GABOOM v$GABOOM_VERSIONE - Comandi disponibili${RESET}"
    echo -e "${CIANO}=============================================${RESET}"
    echo ""
    echo -e "  ${VERDE}gaboom${RESET}             Dashboard completa: sistema, risorse,"
    echo "                     rete, servizi e aggiornamenti"
    echo ""
    echo -e "  ${VERDE}sudo nc10-net${RESET}      Menu di connessione"
    echo "                     1) Rete di sistema (predefinita)"
    echo "                     2) Telefono via cavo USB"
    echo "                     3) Un'altra rete WiFi (elenco numerato)"
    echo "                     4) Ripara la rete"
    echo ""
    echo -e "  ${VERDE}sudo nc10-set${RESET}      Gestisce la rete di sistema:"
    echo "                     imposta, cambia, mostra o rimuove la"
    echo "                     connessione predefinita (WiFi, USB o cavo)"
    echo ""
    echo -e "  ${VERDE}sudo nc10-fix${RESET}      Riparatore automatico: chiude le reti"
    echo "                     sovrapposte, ferma i gestori concorrenti,"
    echo "                     neutralizza i residui di Ceni (con backup)"
    echo "                     e resetta le interfacce"
    echo ""
    echo -e "  ${VERDE}nc10-server${RESET}        Connessione SSH al server domestico"
    echo ""
    echo -e "  ${VERDE}gaboom help${RESET}        Mostra questo aiuto"
    echo ""
    echo -e "${GIALLO}Scorciatoie:${RESET} gaboom net | gaboom set | gaboom fix | gaboom server"
    echo ""
    echo -e "${GIALLO}File utili:${RESET}"
    echo "  /etc/nc10-net.conf                     rete di sistema salvata"
    echo "  /etc/network/interfaces.backup-nc10    backup pre-riparazione"
    echo ""
    echo -e "${GIALLO}Aggiornamento:${RESET} cd nc10-net && git pull && sudo ./install.sh"
    echo ""
}

case "$1" in
    ""|info)
        mostra_info
        ;;
    help|-h|--help)
        mostra_help
        ;;
    net)
        exec sudo /usr/local/bin/nc10-net
        ;;
    set)
        exec sudo /usr/local/bin/nc10-set
        ;;
    fix)
        exec sudo /usr/local/bin/nc10-fix
        ;;
    server)
        exec /usr/local/bin/nc10-server
        ;;
    *)
        echo "Comando sconosciuto: $1"
        mostra_help
        exit 1
        ;;
esac
