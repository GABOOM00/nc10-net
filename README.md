# nc10-net

Menu di connessione all'avvio per Samsung NC10 (o qualsiasi PC Linux con NetworkManager).

All'accensione del computer appare un menu che chiede come vuoi connetterti:

1. **WiFi di casa (Vodafone)** — si connette da solo
2. **Telefono via cavo USB** — ti dice di collegare il telefono, attivare il tethering USB e premere Invio
3. **Un'altra rete WiFi** — mostra le reti disponibili e ti chiede SSID e password (la rete viene salvata per le volte successive)
4. **Esci** — nessuna connessione

## Requisiti

- NetworkManager (comando `nmcli`). Verifica con:

```bash
nmcli --version
```

Se non c'è, installalo:

```bash
sudo apt install network-manager
```

## Installazione

```bash
git clone https://github.com/TUO-UTENTE/nc10-net.git
cd nc10-net
chmod +x install.sh nc10-net.sh
./install.sh
```

Poi **configura la tua WiFi di casa** (una volta sola):

```bash
sudo nano /usr/local/bin/nc10-net
```

e modifica le righe in cima:

```bash
HOME_SSID="Vodafone-XXXXXXX"   # nome esatto della tua rete
HOME_PASS=""                   # password (vuota se la rete è già salvata)
```

Fatto. Al prossimo riavvio il menu appare da solo. Puoi anche lanciarlo a mano in qualsiasi momento con:

```bash
nc10-net
```

## Disinstallazione

```bash
sudo rm /usr/local/bin/nc10-net
rm ~/.config/autostart/nc10-net.desktop
```

## Risoluzione problemi

- **"nmcli non trovato"** → installa NetworkManager (vedi sopra). Se la tua distro usa un altro sistema (es. `wicd` o solo `wpa_supplicant`), questo script non funzionerà così com'è.
- **Il tethering USB non viene trovato** → assicurati di attivare il tethering *sul telefono* dopo aver collegato il cavo, poi rilancia lo script.
- **La WiFi di casa non si connette** → controlla che `HOME_SSID` sia scritto esattamente come appare nella lista reti (maiuscole comprese).
