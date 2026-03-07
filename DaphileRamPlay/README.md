# Daphile RAM Play Auto — LMS Plugin

Automatically activates **"Play from RAM"** on [Daphile](https://www.daphile.com) at the start of every track, for **all clients** including **iPeng**, any browser, and every LMS-compatible app.

---

## The Problem

Daphile's "Play from RAM" feature loads the audio file into RAM before playback, reducing disk I/O and improving sound quality. However, this button is only available in the Daphile web interface — it cannot be triggered from mobile clients like **iPeng** or other LMS controllers.

## The Solution

This plugin intercepts the LMS "new song" event and automatically calls Daphile's internal RAM play API, making it work transparently for every client.

### How it works

Daphile exposes an internal HTTP endpoint:
```
GET /cgi-bin/ramplay.json?cmd=start&player=<mac>
GET /cgi-bin/ramplay.json?cmd=status&player=<mac>
```

Response logic (note: inverted status naming):
- `{"status":"start"}` → RAM play **NOT** active → activate it
- `{"status":"stop"}` → RAM play **ACTIVE** ✅

---

## Installation

### Method 1 — Via LMS Plugin Repository (recommended)

1. Open **Advanced Media Server Settings → Manage Plugins**
2. Scroll to **"Additional Repositories"**
3. Add this URL:
   ```
   https://raw.githubusercontent.com/emiliorusso/daphile-ramplay-plugin/main/repo.xml
   ```
4. Click **Apply**
5. Find **"Daphile RAM Play Auto"** in the plugin list and enable it
6. Restart the server

### Method 2 — Manual upload

1. Download this repository as ZIP
2. Extract the `DaphileRamPlay` folder
3. Upload it to your LMS plugins directory:
   ```
   /var/daphile/mediaserver/Plugins/DaphileRamPlay/
   ```
4. Restart the server

---

## Configuration

After installation go to **Advanced Media Server Settings → Manage Plugins → Daphile RAM Play Auto → Settings**:

| Setting | Default | Description |
|---|---|---|
| **Enable** | On | Enable/disable the plugin |
| **Delay** | 3 seconds | Wait time before activating RAM play after track starts |

The delay is necessary to give Daphile time to start loading the file before the RAM copy begins. If you experience issues, try increasing the delay.

---

## Requirements

- Daphile (any recent version)
- LMS / Lyrion Music Server 8.0+
- RAM Drive must be enabled in Daphile (it is by default — 1.5GB tmpfs)

---

## Known Limitations

- Files larger than the available RAM Drive (~1.5GB by default on Daphile) cannot be fully loaded into RAM. Daphile handles this gracefully.
- DSD files may be very large — test with your setup.

---

## Technical Notes

Discovered via Chrome DevTools (F12 → Network tab) by reverse engineering the Daphile web interface button call. The plugin runs entirely on localhost (127.0.0.1) since it executes on the same machine as Daphile.

---

## Contributing

Pull requests welcome! If you find bugs or want to add features, open an issue or PR.

---

## Author

**Emilio Russo** — Italian hi-fi enthusiast running Daphile on a Fujitsu Futro thin client with JLSounds Hi-Rez Audio 2.0 (XMOS USB→I2S) at 384kHz PCM / Native DSD.

---

## License

MIT License — free to use, modify and distribute.
