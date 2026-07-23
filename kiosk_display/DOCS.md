# Kiosk Display – Dokumentation

## Übersicht

Das **Kiosk Display** Add-on verwandelt deinen Home Assistant OS Server in ein Kiosk-Display.
Es startet einen Wayland-Compositor (Cage oder Weston) direkt auf dem HDMI-Ausgang und öffnet
Chromium im Vollbild-Modus mit deinem gewünschten Home Assistant Dashboard.

### Unterstützte Hardware

| Gerät | Architektur | GPU | Status |
|-------|-------------|-----|--------|
| Raspberry Pi 4 (2/4/8 GB) | aarch64 | VideoCore VI (V3D) | ✅ Vollständig |
| Raspberry Pi 5 | aarch64 | VideoCore VII | ✅ Vollständig |
| Intel NUC / x86 Mini-PC | amd64 | Intel HD/UHD/Iris | ✅ Vollständig |
| x86-64 mit AMD GPU | amd64 | AMDGPU/Radeon | ✅ Vollständig |
| Virtuelle Maschine | amd64 | virtio-gpu | ⚠️ Eingeschränkt |

---

## Installation

### Schritt 1: Repository hinzufügen

1. Gehe in Home Assistant zu **Einstellungen** → **Add-ons** → **Add-on Store**
2. Klicke oben rechts auf das **⋮** Menü → **Repositories**
3. Füge die Repository-URL hinzu und klicke **Hinzufügen**

### Schritt 2: Add-on installieren

1. Aktualisiere die Seite (F5)
2. Suche nach **Kiosk Display**
3. Klicke auf **Installieren**

### Schritt 3: Konfigurieren

1. Wechsle zum Tab **Konfiguration**
2. Setze mindestens:
   - `dashboard`: Pfad zum Dashboard (z.B. `lovelace/default_view`)
   - `token`: Dein Long-Lived Access Token (empfohlen)
3. Speichere die Konfiguration

### Schritt 4: Starten

1. Klicke auf **Starten**
2. Überprüfe die **Logs** auf Fehler
3. Dein Dashboard sollte auf dem angeschlossenen Monitor erscheinen

### Long-Lived Access Token erstellen

1. Gehe zu **Profil** (unten links in Home Assistant)
2. Scrolle zu **Langzeit-Zugriffstoken**
3. Klicke **Token erstellen**
4. Kopiere den Token und füge ihn in die Add-on-Konfiguration ein

---

## Konfigurationsreferenz

### Verbindung & Authentifizierung

| Option | Typ | Standard | Beschreibung |
|--------|-----|----------|--------------|
| `ha_url` | URL | *leer* | URL deiner Home Assistant Instanz. Leer lassen = interne Supervisor-URL (`http://supervisor/core`) |
| `dashboard` | String | *leer* | Pfad zum Dashboard, z.B. `lovelace/default_view` oder `lovelace-kiosk/0` |
| `username` | String | *leer* | HA-Benutzername für Auto-Login |
| `password` | Passwort | *leer* | HA-Passwort für Auto-Login |
| `token` | Passwort | *leer* | Long-Lived Access Token (bevorzugt gegenüber Benutzername/Passwort) |

### Darstellung

| Option | Typ | Standard | Beschreibung |
|--------|-----|----------|--------------|
| `zoom` | Integer | `100` | Zoom-Level in Prozent (25–500) |
| `dark_mode` | Boolean | `true` | Erzwingt den Dunkelmodus im Browser |
| `rotate_display` | Liste | `normal` | Display-Rotation: `normal`, `90`, `180`, `270` |
| `output_number` | Integer | `0` | HDMI-Ausgang (0=Auto, 1=HDMI-0, 2=HDMI-1) |
| `cursor_timeout` | Integer | `5` | Mauszeiger nach X Sekunden ausblenden (0=nie) |

### Verhalten

| Option | Typ | Standard | Beschreibung |
|--------|-----|----------|--------------|
| `refresh_interval` | Integer | `0` | Seite automatisch nach X Sekunden neu laden (0=deaktiviert) |
| `screen_timeout` | Integer | `0` | Bildschirm nach X Sekunden Inaktivität ausschalten (0=deaktiviert) |
| `display_server` | Liste | `auto` | Display-Server: `auto` (empfohlen), `cage`, `weston`, `xorg` |
| `browser_flags` | String | *leer* | Zusätzliche Chromium-Flags (nur für Experten) |

### Touchscreen

| Option | Typ | Standard | Beschreibung |
|--------|-----|----------|--------------|
| `touch_enabled` | Boolean | `true` | Touchscreen-Unterstützung aktivieren |
| `touch_mapping` | String | `auto` | Touch-zu-Display-Zuordnung (`auto` oder manuelle Angabe) |
| `onscreen_keyboard` | Boolean | `false` | Bildschirmtastatur aktivieren |

### Audio

| Option | Typ | Standard | Beschreibung |
|--------|-----|----------|--------------|
| `audio_sink` | String | `auto` | Audio-Ausgang (`auto` oder spezifischer Sink-Name) |

### REST API

| Option | Typ | Standard | Beschreibung |
|--------|-----|----------|--------------|
| `api_enabled` | Boolean | `true` | REST API aktivieren |
| `api_port` | Port | `8099` | Port für den API-Server |

---

## Auto-Login

### Methode 1: Long-Lived Access Token (Empfohlen)

Das Token wird sicher gespeichert und an Chromium übergeben. Vorteile:
- Kein Passwort im Klartext
- Token kann jederzeit in HA widerrufen werden
- Funktioniert zuverlässig mit Single Sign-On

```yaml
token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### Methode 2: Benutzername / Passwort

Chromium wird über eine Hilfsseite eingeloggt, die den HA Auth-Flow automatisch durchläuft.

```yaml
username: "kiosk"
password: "dein_sicheres_passwort"
```

> **Empfehlung**: Erstelle einen eigenen HA-Benutzer "kiosk" mit eingeschränkten Rechten.

### Methode 3: Kein Login

Wenn weder Token noch Credentials konfiguriert sind, navigiert der Browser direkt zur URL.
In diesem Fall musst du dich manuell einloggen (z.B. über Touchscreen).

---

## REST API

Die API ist erreichbar unter `http://<HA_IP>:8099/api/` oder über HA Ingress.

### Display-Steuerung

| Methode | Endpunkt | Beschreibung | Request Body |
|---------|----------|--------------|-------------|
| `POST` | `/api/display/on` | Bildschirm einschalten | – |
| `POST` | `/api/display/off` | Bildschirm ausschalten | – |
| `POST` | `/api/display/toggle` | Bildschirm ein-/ausschalten | – |
| `GET` | `/api/display/status` | Bildschirm-Status abfragen | – |
| `POST` | `/api/display/brightness` | Helligkeit setzen | `{"brightness": 80}` |
| `GET` | `/api/display/screenshot` | Screenshot als PNG | – |

### Browser-Steuerung

| Methode | Endpunkt | Beschreibung | Request Body |
|---------|----------|--------------|-------------|
| `POST` | `/api/browser/reload` | Seite neu laden | – |
| `POST` | `/api/browser/restart` | Browser neu starten | – |
| `POST` | `/api/browser/url` | URL ändern | `{"url": "http://..."}` |
| `POST` | `/api/browser/fullscreen` | Vollbild umschalten | – |
| `POST` | `/api/browser/js` | JavaScript ausführen* | `{"code": "..."}` |

*\* Erfordert Chrome DevTools Protocol (zukünftiges Feature)*

### Eingabe-Steuerung

| Methode | Endpunkt | Beschreibung | Request Body |
|---------|----------|--------------|-------------|
| `POST` | `/api/input/key` | Tastendruck senden | `{"key": "F5"}` |
| `POST` | `/api/input/mouse` | Maus bewegen | `{"x": 100, "y": 200}` |
| `POST` | `/api/input/text` | Text eingeben | `{"text": "Hallo"}` |

### System

| Methode | Endpunkt | Beschreibung | Request Body |
|---------|----------|--------------|-------------|
| `GET` | `/api/system/info` | System-Informationen | – |
| `POST` | `/api/system/restart` | Add-on neu starten | – |
| `GET` | `/api/health` | Health Check | – |

### Home Assistant Integration

| Methode | Endpunkt | Beschreibung | Request Body |
|---------|----------|--------------|-------------|
| `POST` | `/api/ha/dashboard` | Dashboard wechseln | `{"dashboard": "lovelace/wohnzimmer"}` |
| `POST` | `/api/ha/kiosk-mode` | Kiosk-Modus umschalten | `{"enable": true}` |

### Beispiele mit cURL

```bash
# Bildschirm ausschalten
curl -X POST http://192.168.1.100:8099/api/display/off

# Screenshot abrufen
curl http://192.168.1.100:8099/api/display/screenshot -o screenshot.png

# Dashboard wechseln
curl -X POST http://192.168.1.100:8099/api/ha/dashboard \
  -H "Content-Type: application/json" \
  -d '{"dashboard": "lovelace/kueche"}'

# Browser URL ändern
curl -X POST http://192.168.1.100:8099/api/browser/url \
  -H "Content-Type: application/json" \
  -d '{"url": "http://192.168.1.100:8123/lovelace/bad?kiosk"}'

# Taste senden (F5 = Reload)
curl -X POST http://192.168.1.100:8099/api/input/key \
  -H "Content-Type: application/json" \
  -d '{"key": "F5"}'

# System-Informationen
curl http://192.168.1.100:8099/api/system/info
```

### Verwendung in HA Automationen

```yaml
# Bildschirm bei Sonnenuntergang einschalten
automation:
  - alias: "Kiosk Display einschalten"
    trigger:
      - platform: sun
        event: sunset
    action:
      - service: rest_command.kiosk_screen_on

rest_command:
  kiosk_screen_on:
    url: "http://localhost:8099/api/display/on"
    method: POST
  kiosk_screen_off:
    url: "http://localhost:8099/api/display/off"
    method: POST
  kiosk_reload:
    url: "http://localhost:8099/api/browser/reload"
    method: POST
```

---

## Display-Rotation

Die Rotation wird direkt auf Compositor-Ebene angewendet:

| Wert | Beschreibung | Cage | Weston | Xorg |
|------|-------------|------|--------|------|
| `normal` | Keine Rotation | Standard | `transform=normal` | `--rotate normal` |
| `90` | 90° im Uhrzeigersinn | `-r` | `transform=90` | `--rotate left` |
| `180` | 180° gedreht | `-r -r` | `transform=180` | `--rotate inverted` |
| `270` | 270° im Uhrzeigersinn | `-r -r -r` | `transform=270` | `--rotate right` |

---

## Touchscreen-Setup

### Automatische Erkennung

Die meisten USB-Touchscreens werden automatisch erkannt, wenn `touch_enabled: true` gesetzt ist.
Das Add-on verwendet `libinput` und `evtest` zur Erkennung.

### Unterstützte Touchscreens

- USB-HID Touchscreens (die meisten günstigen Displays)
- HDMI-Touchscreens mit USB-Rückkanal
- DSI-Touchscreens (Raspberry Pi Official Touchscreen)
- Kapazitive und resistive Touchscreens

### Touch-Mapping bei Multi-Monitor

Wenn mehrere Monitore angeschlossen sind, muss der Touchscreen dem richtigen Display zugeordnet werden.
Setze `touch_mapping` auf den gewünschten Output-Namen (z.B. `HDMI-A-1`).

---

## Audio-Konfiguration

### Automatische Erkennung

Mit `audio_sink: auto` wird der erste verfügbare HDMI-Audio-Ausgang verwendet.

### Manueller Sink

1. Finde den korrekten Sink-Namen in den Logs oder per:
   ```
   pactl list sinks short
   ```
2. Setze `audio_sink` auf den gewünschten Namen

---

## Multi-Monitor-Setup

### HDMI-Ausgang wählen

Mit `output_number` kannst du festlegen, welcher Ausgang verwendet wird:

| Wert | Bedeutung |
|------|-----------|
| `0` | Automatisch (erster verbundener Monitor) |
| `1` | HDMI-0 / erster Ausgang |
| `2` | HDMI-1 / zweiter Ausgang |

### Erkannte Ausgänge

Das Add-on erkennt automatisch:
- **HDMI-A-1** / **HDMI-A-2**: Standard HDMI-Ausgänge
- **DSI-1**: Raspberry Pi DSI-Anschluss
- **DP-1**: DisplayPort

---

## Troubleshooting

### Bildschirm bleibt schwarz

1. Überprüfe, ob ein Monitor angeschlossen und eingeschaltet ist
2. Prüfe die Add-on-Logs auf Fehlermeldungen
3. Versuche `display_server: xorg` als Fallback
4. Stelle sicher, dass `/dev/dri/card0` verfügbar ist

### Chromium stürzt ab

1. Das Add-on repariert automatisch das Chromium-Profil
2. Bei wiederholten Abstürzen: Lösche `/data/chromium-profile` manuell
3. Prüfe, ob genügend RAM verfügbar ist (min. 2 GB empfohlen)

### Touch funktioniert nicht

1. Prüfe, ob `touch_enabled: true` gesetzt ist
2. Überprüfe, ob der Touchscreen unter `/dev/input/` erkannt wird
3. Teste mit `evtest` in den Logs

### Login schlägt fehl

1. Überprüfe den Token in HA unter **Profil** → **Langzeit-Zugriffstoken**
2. Stelle sicher, dass der Token nicht abgelaufen ist
3. Bei Benutzername/Passwort: Prüfe die Zugangsdaten

### Kein GPU-Zugriff

1. Prüfe, ob `full_access: true` in der config.yaml steht
2. Überprüfe, ob `/dev/dri/card0` existiert
3. Bei virtuellen Maschinen: Stelle sicher, dass GPU-Passthrough aktiviert ist

---

## Architektur

```
┌─────────────────────────────────────────────┐
│               Home Assistant OS              │
│  ┌─────────────────────────────────────────┐ │
│  │        Kiosk Display Container          │ │
│  │                                         │ │
│  │  ┌──────────┐   ┌──────────────────┐   │ │
│  │  │ s6-init  │──▶│  init-config     │   │ │
│  │  └──────────┘   │  (GPU/Monitor    │   │ │
│  │                  │   Detection)     │   │ │
│  │                  └────────┬─────────┘   │ │
│  │                           │             │ │
│  │                  ┌────────▼─────────┐   │ │
│  │                  │  display-server  │   │ │
│  │                  │  Cage│Weston│Xorg│   │ │
│  │                  └────────┬─────────┘   │ │
│  │                           │             │ │
│  │          ┌────────────────┼──────┐      │ │
│  │          │                │      │      │ │
│  │  ┌───────▼──────┐ ┌──────▼───┐ ┌▼────┐ │ │
│  │  │kiosk-browser │ │api-server│ │watch│ │ │
│  │  │  (Chromium)  │ │ (Python) │ │ dog │ │ │
│  │  └──────────────┘ └──────────┘ └─────┘ │ │
│  └─────────────────────────────────────────┘ │
│                     │                        │
│              ┌──────▼──────┐                 │
│              │  HDMI / DSI │                 │
│              │   Monitor   │                 │
│              └─────────────┘                 │
└─────────────────────────────────────────────┘
```

### Display-Server Priorität

1. **Cage** (Wayland) – Standard, minimaler Overhead
2. **Weston** (Wayland) – Fallback, mehr Features
3. **Xorg** (X11) – Letzte Alternative, Legacy-Kompatibilität

### Chromium-Flags

Das Add-on startet Chromium mit optimierten Flags für Kiosk-Betrieb:

- `--kiosk` / `--start-fullscreen`: Vollbild ohne Browserleisten
- `--no-sandbox`: Erforderlich im Container
- `--ozone-platform=wayland`: Wayland-native Darstellung
- `--enable-gpu` / `--ignore-gpu-blocklist`: GPU-Beschleunigung
- `--disk-cache-size=0`: Kein Festplatten-Cache
- `--disable-background-networking`: Keine Hintergrund-Netzwerkaktivität

---

## Sicherheitshinweise

- **Eigener Benutzer**: Erstelle einen separaten HA-Benutzer "kiosk" mit eingeschränkten Rechten
- **Token statt Passwort**: Verwende Long-Lived Access Token anstelle von Klartext-Passwörtern
- **Netzwerk**: Die REST API ist standardmäßig auf Port 8099 erreichbar – beschränke den Zugriff ggf. per Firewall
- **`full_access: true`**: Das Add-on benötigt vollen Hardware-Zugriff für GPU/DRM – dies ist ein Sicherheits-Tradeoff
