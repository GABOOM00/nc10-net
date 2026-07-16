#!/usr/bin/env bash
#
# gaboom — Comando principale del progetto: mostra l'aiuto e lancia gli altri comandi
# Uso:  gaboom help        (elenco di tutti i comandi)
#       gaboom net|set|fix|server   (scorciatoie)
#

VERDE='\033[0;32m'; GIALLO='\033[1;33m'; CIANO='\033[0;36m'; RESET='\033[0m'

mostra_help() {
    echo ""
    echo -e "${CIANO}=============================================${RESET}"
    echo -e "${CIANO}   GABOOM — Comandi disponibili sull'NC10${RESET}"
    echo -e "${CIANO}=============================================${RESET}"
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
    ""|help|-h|--help)
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
