# nc10-net

Sistema di gestione della connessione per Samsung NC10 con Linux (antiX o altre distro senza NetworkManager — usa `wpa_supplicant` + `dhclient`).

L'idea centrale è la **rete di sistema**: registri una sola connessione predefinita (WiFi, telefono USB o cavo) e tutto il resto ruota attorno a quella. Il riparatore automatico elimina le connessioni sovrapposte lasciando attiva solo la predefinita.

## I 4 comandi

| Comando | Cosa fa |
|---|---|
| `sudo nc10-net` | Menu di connessione (parte anche da solo al login) |
| `sudo nc10-set` | Imposta / cambia / mostra / rimuove la rete di sistema |
| `sudo nc10-fix` | Diagnosi e riparazione automatica dei problemi di rete |
| `nc10-server`   | Connessione SSH al server domestico |
| `gaboom help`   | Elenco di tutti i comandi, con spiegazione |

`gaboom` funziona anche come scorciatoia: `gaboom net`, `gaboom set`, `gaboom fix`, `gaboom server` lanciano i rispettivi comandi (con sudo automatico dove serve).

### nc10-net (menu)

1. **Rete di sistema** — si connette alla predefinita, qualunque essa sia (WiFi, USB o cavo)
2. **Telefono via cavo USB** — guida al tethering
3. **Un'altra rete WiFi** — mostra l'**elenco numerato** di tutti gli SSID trovati: scegli col numero (o scrivi il nome), inserisci la password, e alla fine puoi salvarla come nuova rete di sistema
4. **Ripara la rete** — lancia nc10-fix
5. **Esci**

### nc10-fix (riparatore)

Controlla e risolve in automatico, in quest'ordine:

1. Processi `wpa_supplicant`/`dhclient` doppi (causa delle reti sovrapposte)
2. Gestori di rete concorrenti attivi (NetworkManager, connman, wicd)
3. Configurazioni residue di **Ceni** in `/etc/network/interfaces` — vengono **commentate, non cancellate**, con backup automatico in `/etc/network/interfaces.backup-nc10`
4. Interfacce con IP doppi o in stato incastrato (flush + reset)
5. Verifica finale che la scheda WiFi scansioni correttamente

Per ripristinare la configurazione originale di Ceni, se mai servisse:

```bash
sudo cp /etc/network/interfaces.backup-nc10 /etc/network/interfaces
```

## Requisiti

```bash
which wpa_supplicant dhclient iw ip
```

Se manca qualcosa: `sudo apt install wpasupplicant isc-dhcp-client iw`
Per nc10-server: `sudo apt install openssh-client`

## Installazione

```bash
git clone https://github.com/TUO-UTENTE/nc10-net.git
cd nc10-net
chmod +x *.sh
sudo ./install.sh
```

Poi, nell'ordine:

```bash
sudo nc10-fix    # pulisce i pasticci esistenti
sudo nc10-set    # scegli la tua rete di sistema (es. la WiFi Vodafone di casa)
sudo nc10-net    # connettiti
```

Per il server SSH, configura una volta sola IP e utente:

```bash
sudo nano /usr/local/bin/nc10-server
```

## Aggiornamento dopo un nuovo commit

```bash
cd nc10-net
git pull
sudo ./install.sh
```

La rete di sistema salvata in `/etc/nc10-net.conf` **non viene toccata** dall'aggiornamento: non devi reinserire SSID e password.

## Disinstallazione

```bash
sudo rm /usr/local/bin/nc10-net /usr/local/bin/nc10-set /usr/local/bin/nc10-fix /usr/local/bin/nc10-server
sudo rm /usr/local/lib/nc10-lib.sh /etc/sudoers.d/nc10-net /etc/nc10-net.conf
rm ~/.config/autostart/nc10-net.desktop
```

## Risoluzione problemi

- **"Device or resource busy" in scansione** → `sudo nc10-fix` (processi sovrapposti o Ceni attivo)
- **"Rete connessa ma internet non risponde"** → `sudo nc10-fix`, poi riprova; se persiste, riavvia il modem
- **La rete di casa non appare nell'elenco** → verifica che il modem trasmetta sui 2,4 GHz (l'NC10 non vede i 5 GHz)
- **Errori SSL/certificati con git** → controlla la data con `date` (batteria tampone dell'NC10 probabilmente scarica)
