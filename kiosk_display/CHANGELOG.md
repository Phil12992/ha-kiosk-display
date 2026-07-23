# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

## [1.0.0] - 2024-07-23

### Hinzugefügt
- Initiale Veröffentlichung
- Chromium im Kiosk-Modus mit optimierten Flags
- Wayland-Unterstützung via Cage Compositor (Standard)
- Weston als Wayland-Fallback
- Xorg + Openbox als letzte Alternative
- Automatische GPU-Erkennung (Raspberry Pi VC4/V3D, Intel, AMD)
- Automatische HDMI-Monitor-Erkennung (HDMI-0, HDMI-1, DSI)
- Display-Rotation (0°, 90°, 180°, 270°)
- Multi-Monitor-Unterstützung
- USB- und HDMI-Touchscreen-Erkennung
- Touch-zu-Display-Mapping
- Bildschirmtastatur-Unterstützung (squeekboard)
- HDMI-Audio-Auswahl
- Automatischer Login via Long-Lived Access Token
- Automatischer Login via Benutzername/Passwort
- Kiosk Mode URL-Parameter
- Konfigurierbarer Zoom
- Konfigurierbarer Dark Mode
- Automatisches Neuladen der Seite
- Bildschirm-Timeout
- Cursor-Timeout
- REST API mit 19 Endpunkten:
  - Display: ein/aus/toggle/status/helligkeit/screenshot
  - Browser: neuladen/neustart/URL ändern/vollbild/JavaScript
  - Eingabe: Taste/Maus/Text
  - System: Info/Neustart
  - Home Assistant: Dashboard wechseln/Kiosk-Modus
- Watchdog mit 10-Sekunden-Intervall
- Automatische Chromium-Absturz-Erkennung und -Reparatur
- Profil-Reparatur bei Crash
- s6-overlay v3 Prozess-Management
- Health Check Endpoint
- Ladebildschirm (Splash Screen)
