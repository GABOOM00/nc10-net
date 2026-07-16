#!/usr/bin/env bash
#
# nc10-set — Imposta, cambia, mostra o rimuove la "rete di sistema"
# Uso:  sudo nc10-set
#

. /usr/local/lib/nc10-lib.sh || { echo "Libreria nc10-lib mancante: rilancia install.sh"; exit 1; }

richiedi_root

imposta_wifi() {
    local wifi
    wifi=$(trova_interfaccia_wifi)
    if [ -z "$wifi" ]; then
        err "Nessuna interfaccia WiFi trovata."
        return 1
    fi

    pulisci_connessioni
    resetta_interfaccia "$wifi"
    scegli_ssid_numerato "$wifi" || { err "Annullato."; return 1; }

    read -rsp "Password di \"$SSID_SCELTO\" (lascia vuoto se la rete e' aperta): " pass
    echo ""

    read -rp "Vuoi provare subito la connessione? [s/n]: " prova
    if [ "$prova" = "s" ] || [ "$prova" = "S" ]; then
        if connetti_wifi "$SSID_SCELTO" "$pass"; then
            salva_config "wifi" "$SSID_SCELTO" "$pass"
        else
            err "Connessione fallita: NON salvo. Riprova controllando la password."
            return 1
        fi
    else
        salva_config "wifi" "$SSID_SCELTO" "$pass"
    fi
}

mostra_config() {
    leggi_config
    echo ""
    if [ -z "$TIPO" ]; then
        echo "Nessuna rete di sistema impostata."
    else
        echo "Rete di sistema attuale:"
        case "$TIPO" in
            wifi)     echo "  Tipo: WiFi — SSID: $SSID (password salvata)" ;;
            usb)      echo "  Tipo: telefono via cavo USB" ;;
            ethernet) echo "  Tipo: cavo ethernet" ;;
            *)        echo "  Tipo sconosciuto: $TIPO" ;;
        esac
    fi
}

while true; do
    echo ""
    echo "========================================"
    echo "   NC10 — Gestione rete di sistema"
    echo "========================================"
    echo "  1) Imposta una rete WiFi come sistema"
    echo "  2) Imposta il telefono USB come sistema"
    echo "  3) Imposta il cavo ethernet come sistema"
    echo "  4) Mostra la rete di sistema attuale"
    echo "  5) Rimuovi la rete di sistema"
    echo "  6) Esci"
    echo ""
    read -rp "Scelta [1-6]: " scelta

    case "$scelta" in
        1) imposta_wifi ;;
        2) salva_config "usb" "" "" ;;
        3) salva_config "ethernet" "" "" ;;
        4) mostra_config ;;
        5)
            if [ -f "$CONFIG" ]; then
                rm -f "$CONFIG"
                ok "Rete di sistema rimossa."
            else
                echo "Non c'era nessuna rete di sistema impostata."
            fi
            ;;
        6) break ;;
        *) err "Scelta non valida, riprova." ;;
    esac
done
