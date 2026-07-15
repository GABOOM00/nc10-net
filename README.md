# nc10-net

Menu di connessione all'avvio per Samsung NC10 con Linux (antiX o altre distro **senza** NetworkManager — usa `wpa_supplicant` + `dhclient`).

All'accensione appare un menu che chiede come vuoi connetterti:

1. **WiFi di casa (Vodafone)** — si connette da solo
2. **Telefono via cavo USB** — ti dice di collegare il telefono, attivare il tethering USB e premere Invio
3. **Un'altra rete WiFi** — mostra le reti trovate e chiede SSID e password
4. **Esci** — nessuna connessione

Incluso anche **nc10-server**: comando per collegarsi via SSH al server domestico con un colpo solo.

## Requisiti

```bash
which wpa_supplicant dhclient iw ip
```

Se manca qualcosa:

```bash
sudo apt install wpasupplicant isc-dhcp-client iw
```

Per `nc10-server` serve anche il client SSH: `sudo apt install openssh-client`

## Installazione

```bash
git clone https://github.com/TUO-UTENTE/nc10-net.git
cd nc10-net
chmod +x install.sh nc10-net.sh nc10-server.sh
sudo ./install.sh
```

L'installer:
- installa i comandi `nc10-net` e `nc10-server`
- crea una regola sudo **solo per nc10-net** così l'avvio automatico non chiede la password
- imposta l'avvio automatico del menu al login

## Configurazione (una volta sola)

**WiFi di casa:**

```bash
sudo nano /usr/local/bin/nc10-net
```

```bash
HOME_SSID="Vodafone-XXXXXXX"   # nome esatto della tua rete
HOME_PASS="TUA-PASSWORD"       # password della rete
```

**Server domestico:**

```bash
sudo nano /usr/local/bin/nc10-server
```

```bash
SERVER_IP="192.168.1.XX"       # IP del server
SERVER_USER="tuo-utente"       # utente sul server
```

Consiglio: nella pagina del modem Vodafone (di solito `192.168.1.1`) imposta una **prenotazione DHCP** per il server, così il suo IP non cambia mai.

## Uso

```bash
sudo nc10-net     # menu di connessione (parte da solo anche al login)
nc10-server       # SSH verso il server di casa
```

## Aggiornamento dopo un nuovo commit

```bash
cd nc10-net
git pull
sudo ./install.sh
```

(l'installer sovrascrive i comandi — poi rimetti HOME_SSID/HOME_PASS e SERVER_IP/SERVER_USER)

## Disinstallazione

```bash
sudo rm /usr/local/bin/nc10-net /usr/local/bin/nc10-server
sudo rm /etc/sudoers.d/nc10-net
rm ~/.config/autostart/nc10-net.desktop
```

## Risoluzione problemi

- **La WiFi di casa non si connette** → controlla che `HOME_SSID` sia scritto esattamente come appare nella scansione (maiuscole comprese).
- **Il tethering USB non viene trovato** → attiva il tethering *sul telefono* dopo aver collegato il cavo, poi riprova.
- **"Server non risponde" con nc10-server** → prima connettiti alla rete di casa con `sudo nc10-net`, verifica che il server sia acceso e che l'IP sia giusto.
- **Errori SSL/certificati con git** → controlla la data del sistema con `date` (la batteria tampone dell'NC10 potrebbe essere scarica e riportare l'orologio indietro).
