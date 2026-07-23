# Kiosk Display – Home Assistant OS Add-on

[![Home Assistant Add-on](https://img.shields.io/badge/Home%20Assistant-Add--on-blue.svg)](https://www.home-assistant.io/)
[![Architecture](https://img.shields.io/badge/Architecture-aarch64%20%7C%20amd64-green.svg)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Übersicht

Dieses Add-on verwandelt einen an deinen **Home Assistant OS** Server angeschlossenen HDMI-Monitor
in ein **Kiosk-Display**. Es startet Chromium im Vollbild-Kiosk-Modus und zeigt automatisch dein
Home Assistant Dashboard an – ohne dass Raspberry Pi OS installiert werden muss.

**Unterstützte Plattformen**: Raspberry Pi 4/5 (aarch64), Intel NUC, x86-64 Mini-PCs

## Features

| Feature | Beschreibung |
|---------|-------------|
| 🖥️ **Chromium Kiosk** | Vollbild-Browser mit optimierten Flags für ressourcenschwache Geräte |
| 🔐 **Auto-Login** | Automatisches Einloggen via Long-Lived Access Token oder Benutzername/Passwort |
| 🌐 **REST API** | 19 API-Endpunkte zur Steuerung von Display, Browser, Eingabe und System |
| 👆 **Touchscreen** | Plug-and-Play für USB- und HDMI-Touchscreens mit automatischem Mapping |
| 🎮 **GPU-Erkennung** | Automatische Erkennung und Optimierung für RPi VC4/V3D, Intel, AMD |
| 🖵 **Multi-Monitor** | Unterstützung für mehrere Bildschirme und HDMI-Ausgang-Auswahl |
| 🔄 **Watchdog** | Automatischer Neustart bei Browser- oder Display-Server-Abstürzen (10s Intervall) |
| 🔃 **Display-Rotation** | Rotation um 0°, 90°, 180° oder 270° |
| 🔊 **Audio** | HDMI-Audio-Auswahl und Lautstärke-Steuerung |
| ⌨️ **Bildschirmtastatur** | Optionale On-Screen-Keyboard-Unterstützung |
| 🌙 **Dark Mode** | Erzwungener Dunkelmodus für den Browser |
| 🔍 **Zoom** | Konfigurierbarer Zoom-Level (25–500%) |

## Architektur

```
Home Assistant OS
 └── Kiosk Display Container (Debian Bookworm)
      ├── s6-overlay v3 (Process Management)
      │    ├── init-config    → GPU/Monitor-Erkennung, Konfiguration
      │    ├── display-server → Cage (Wayland) | Weston | Xorg
      │    ├── kiosk-browser  → Chromium im Kiosk-Modus
      │    ├── api-server     → Python aiohttp REST API
      │    └── watchdog       → Health Monitoring (alle 10s)
      │
      ├── Display Stack Priorität:
      │    1. ✅ Cage   (Wayland - Standard, minimal)
      │    2. ✅ Weston (Wayland - Fallback, mehr Features)
      │    3. ⚠️ Xorg   (Legacy - letzte Alternative)
      │
      └── Hardware
           ├── /dev/dri/card0  → GPU (DRM/KMS)
           ├── /dev/input/*    → Touchscreen / Eingabegeräte
           └── HDMI / DSI      → Monitor-Ausgang
```

## Quick Start

```bash
# 1. Repository hinzufügen (Einstellungen → Add-ons → Add-on Store → ⋮ → Repositories)
# 2. "Kiosk Display" installieren
# 3. Konfigurieren:
```

```yaml
dashboard: "lovelace/default_view"
token: "dein_long_lived_access_token"
```

```bash
# 4. Starten und Logs prüfen
```

## Konfiguration

| Option | Typ | Standard | Beschreibung |
|--------|-----|----------|-------------|
| `ha_url` | URL | *leer* | HA URL (leer = interne Supervisor-URL) |
| `dashboard` | String | *leer* | Dashboard-Pfad (z.B. `lovelace/default_view`) |
| `username` | String | *leer* | HA-Benutzername für Auto-Login |
| `password` | Passwort | *leer* | HA-Passwort für Auto-Login |
| `token` | Passwort | *leer* | Long-Lived Access Token (empfohlen) |
| `zoom` | Integer | `100` | Zoom-Level in % (25–500) |
| `dark_mode` | Boolean | `true` | Dunkelmodus erzwingen |
| `refresh_interval` | Integer | `0` | Auto-Reload in Sekunden (0=aus) |
| `screen_timeout` | Integer | `0` | Bildschirm-Timeout in Sekunden (0=aus) |
| `rotate_display` | Liste | `normal` | Rotation: `normal`, `90`, `180`, `270` |
| `output_number` | Integer | `0` | HDMI-Ausgang (0=Auto) |
| `audio_sink` | String | `auto` | Audio-Ausgang |
| `cursor_timeout` | Integer | `5` | Mauszeiger ausblenden nach X Sekunden |
| `touch_enabled` | Boolean | `true` | Touchscreen aktivieren |
| `touch_mapping` | String | `auto` | Touch-zu-Display-Zuordnung |
| `onscreen_keyboard` | Boolean | `false` | Bildschirmtastatur aktivieren |
| `display_server` | Liste | `auto` | `auto`, `cage`, `weston`, `xorg` |
| `browser_flags` | String | *leer* | Zusätzliche Chromium-Flags |
| `api_enabled` | Boolean | `true` | REST API aktivieren |
| `api_port` | Port | `8099` | REST API Port |

## REST API

### Display

| Methode | Endpunkt | Beschreibung |
|---------|----------|-------------|
| `POST` | `/api/display/on` | Bildschirm ein |
| `POST` | `/api/display/off` | Bildschirm aus |
| `POST` | `/api/display/toggle` | Bildschirm umschalten |
| `GET` | `/api/display/status` | Status abfragen |
| `POST` | `/api/display/brightness` | Helligkeit setzen `{"brightness": 80}` |
| `GET` | `/api/display/screenshot` | Screenshot als PNG |

### Browser

| Methode | Endpunkt | Beschreibung |
|---------|----------|-------------|
| `POST` | `/api/browser/reload` | Seite neu laden |
| `POST` | `/api/browser/restart` | Browser neu starten |
| `POST` | `/api/browser/url` | URL ändern `{"url": "http://..."}` |
| `POST` | `/api/browser/fullscreen` | Vollbild umschalten |

### Eingabe

| Methode | Endpunkt | Beschreibung |
|---------|----------|-------------|
| `POST` | `/api/input/key` | Taste senden `{"key": "F5"}` |
| `POST` | `/api/input/mouse` | Maus bewegen `{"x": 100, "y": 200}` |
| `POST` | `/api/input/text` | Text eingeben `{"text": "Hallo"}` |

### System & HA

| Methode | Endpunkt | Beschreibung |
|---------|----------|-------------|
| `GET` | `/api/system/info` | System-Informationen |
| `POST` | `/api/system/restart` | Add-on neu starten |
| `GET` | `/api/health` | Health Check |
| `POST` | `/api/ha/dashboard` | Dashboard wechseln `{"dashboard": "lovelace/..."}` |
| `POST` | `/api/ha/kiosk-mode` | Kiosk-Modus `{"enable": true}` |

### Beispiel: HA Automation

```yaml
rest_command:
  kiosk_screen_off:
    url: "http://localhost:8099/api/display/off"
    method: POST
  kiosk_screen_on:
    url: "http://localhost:8099/api/display/on"
    method: POST

automation:
  - alias: "Kiosk Display nachts ausschalten"
    trigger:
      - platform: time
        at: "23:00:00"
    action:
      - service: rest_command.kiosk_screen_off
```

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| Bildschirm bleibt schwarz | HDMI-Kabel prüfen, Logs checken, `display_server: xorg` testen |
| Chromium stürzt ab | Wird automatisch repariert. Bei Dauerproblemen: Profil löschen |
| Touch funktioniert nicht | `touch_enabled: true` setzen, `/dev/input/` prüfen |
| Login schlägt fehl | Token in HA-Profil prüfen, Credentials überprüfen |
| Kein GPU-Zugriff | `full_access: true` in config.yaml, `/dev/dri/card0` prüfen |
| Performance-Probleme | `zoom` reduzieren, `refresh_interval` erhöhen |

## FAQ

**Welche Geräte werden unterstützt?**
Raspberry Pi 4/5 (aarch64) und x86-64 Systeme (Intel NUC, Mini-PCs).

**Unterstützt das Add-on Touchscreens?**
Ja, die meisten USB-Touchscreens werden automatisch erkannt.

**Kann ich mehrere Dashboards wechseln?**
Ja, über die REST API (`/api/ha/dashboard`) oder durch Neukonfiguration.

**Funktioniert das Add-on mit Kiosk Mode (HACS)?**
Ja, der `?kiosk` URL-Parameter wird automatisch angehängt.

**Wie viel RAM braucht das Add-on?**
Chromium benötigt ca. 200–400 MB RAM. Ein RPi 4 mit 2 GB reicht aus.

## Contributing

Pull Requests sind willkommen! Bei größeren Änderungen bitte zuerst ein Issue eröffnen.

## License

MIT
