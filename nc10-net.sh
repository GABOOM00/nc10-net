#!/usr/bin/env bash
#
# nc10-net - Menu di connessione per Samsung NC10 (wpa_supplicant)
# Eseguibile in qualsiasi momento:  sudo nc10-net
#

. /usr/local/lib/nc10-lib.sh || { echo "Libreria nc10-lib mancante: rilancia install.sh"; exit 1; }

richiedi_root

controlla_comandi() {
    local mancanti=""
    for cmd in wpa_supplicant dhclient iw ip; do
        command -v "$cmd" >/dev/null 2>&1 || mancanti="$mancanti $cmd"
    done
    if [ -n "$mancanti" ]; then
        err "Comandi mancanti:$mancanti"
        echo "    Installa con: sudo apt install wpasupplicant isc-dhcp-client iw"
        exit 1
    fi
}

connetti_sistema() {
    leggi_config
    if [ -z "$TIPO" ]; then
        err "Nessuna rete di sistema impostata."
        echo "    Impostala con:  sudo nc10-set"
        return 1
    fi

    case "$TIPO" in
        wifi)
            info "Rete di sistema: WiFi \"$SSID\""
            connetti_wifi "$SSID" "$PASS"
            ;;
        usb)
            info "Rete di sistema: telefono via cavo USB"
            connetti_usb
            ;;
        ethernet)
            info "Rete di sistema: cavo ethernet"
            connetti_ethernet
            ;;
        *)
            err "Tipo di rete di sistema sconosciuto: $TIPO (correggi con: sudo nc10-set)"
            return 1
            ;;
    esac
}

connetti_altra_rete() {
    local wifi
    wifi=$(trova_interfaccia_wifi)
    if [ -z "$wifi" ]; then
        err "Nessuna interfaccia WiFi trovata."
        return 1
    fi

    resetta_interfaccia "$wifi"
    scegli_ssid_numerato "$wifi" || { err "Annullato."; return 1; }

    read -rsp "Password di \"$SSID_SCELTO\" (lascia vuoto se la rete e' aperta): " pass
    echo ""

    if connetti_wifi "$SSID_SCELTO" "$pass"; then
        echo ""
        read -rp "Vuoi impostare \"$SSID_SCELTO\" come nuova rete di sistema? [s/n]: " salva
        if [ "$salva" = "s" ] || [ "$salva" = "S" ]; then
            salva_config "wifi" "$SSID_SCELTO" "$pass"
        fi
        return 0
    else
        err "Connessione a \"$SSID_SCELTO\" fallita. Controlla la password."
        return 1
    fi
}

# ================= MENU PRINCIPALE =================
controlla_comandi
leggi_config

DESCR_SISTEMA="non impostata - usa: sudo nc10-set"
case "$TIPO" in
    wifi)     DESCR_SISTEMA="WiFi \"$SSID\"" ;;
    usb)      DESCR_SISTEMA="telefono via cavo USB" ;;
    ethernet) DESCR_SISTEMA="cavo ethernet" ;;
esac

while true; do
    echo ""
    echo "===================================="
    echo "   NC10 - Come vuoi connetterti?"
    echo "===================================="
    echo "  1) Rete di sistema ($DESCR_SISTEMA)"
    echo "  2) Telefono via cavo USB"
    echo "  3) Un'altra rete WiFi (con elenco)"
    echo "  4) Ripara la rete (nc10-fix)"
    echo "  5) Non connettermi / Esci"
    echo ""
    read -rp "Scelta [1-5]: " scelta

    case "$scelta" in
        1) connetti_sistema && break ;;
        2) connetti_usb && break ;;
        3) connetti_altra_rete && break ;;
        4) /usr/local/bin/nc10-fix --da-menu; leggi_config ;;
        5) echo "Ok, nessuna connessione. Ciao!"; break ;;
        *) err "Scelta non valida, riprova." ;;
    esac

    if [ "$scelta" != "4" ]; then
        echo ""
        read -rp "Vuoi riprovare? [s/n]: " riprova
        [ "$riprova" != "s" ] && [ "$riprova" != "S" ] && break
    fi
done

echo ""
read -rp "Premi INVIO per chiudere..."
