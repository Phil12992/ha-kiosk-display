#!/usr/bin/env python3
"""Kiosk Display REST API Server.

Provides HTTP endpoints to control the kiosk display, browser,
and input devices.
"""

import asyncio
import json
import logging
import os
import subprocess
import sys
from pathlib import Path

try:
    from aiohttp import web
except ImportError:
    print("ERROR: aiohttp not installed. Install with: pip3 install aiohttp", file=sys.stderr)
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger('kiosk-api')

# Constants
SCREEN_CONTROL = '/usr/bin/screen-control.sh'
ENV_FILE = '/var/run/kiosk/env.sh'
OPTIONS_FILE = '/data/options.json'
SCREENSHOT_DIR = '/tmp'


def load_env():
    """Load kiosk environment variables from env.sh."""
    env = {}
    if os.path.exists(ENV_FILE):
        with open(ENV_FILE) as f:
            for line in f:
                line = line.strip()
                if line.startswith('export '):
                    line = line[7:]
                if '=' in line and not line.startswith('#'):
                    key, _, value = line.partition('=')
                    # Remove surrounding quotes
                    value = value.strip('"').strip("'")
                    env[key] = value
    return env


def run_screen_control(*args):
    """Execute screen-control.sh with given arguments."""
    try:
        result = subprocess.run(
            [SCREEN_CONTROL] + list(args),
            capture_output=True,
            text=True,
            timeout=10,
            env={**os.environ, 'XDG_RUNTIME_DIR': '/run/user/0'}
        )
        if result.returncode == 0 and result.stdout.strip():
            try:
                return json.loads(result.stdout.strip())
            except json.JSONDecodeError:
                return {'output': result.stdout.strip()}
        return {'status': 'ok', 'stderr': result.stderr.strip() if result.stderr else None}
    except subprocess.TimeoutExpired:
        return {'status': 'error', 'message': 'Command timed out'}
    except Exception as e:
        return {'status': 'error', 'message': str(e)}


# ============================================================================
# Display Endpoints
# ============================================================================

async def display_on(request):
    """Turn display on."""
    result = run_screen_control('on')
    logger.info('Display turned on')
    return web.json_response(result)


async def display_off(request):
    """Turn display off."""
    result = run_screen_control('off')
    logger.info('Display turned off')
    return web.json_response(result)


async def display_toggle(request):
    """Toggle display on/off."""
    result = run_screen_control('toggle')
    logger.info('Display toggled')
    return web.json_response(result)


async def display_status(request):
    """Get display status."""
    result = run_screen_control('status')
    return web.json_response(result)


async def display_brightness(request):
    """Set display brightness."""
    data = await request.json() if request.can_read_body else {}
    level = str(data.get('brightness', data.get('level', 100)))
    result = run_screen_control('brightness', level)
    logger.info(f'Brightness set to {level}')
    return web.json_response(result)


async def display_screenshot(request):
    """Take a screenshot and return it as PNG."""
    screenshot_path = os.path.join(SCREENSHOT_DIR, 'kiosk-screenshot.png')
    run_screen_control('screenshot', screenshot_path)
    
    if os.path.exists(screenshot_path):
        return web.FileResponse(
            screenshot_path,
            headers={'Content-Type': 'image/png'}
        )
    return web.json_response(
        {'status': 'error', 'message': 'Screenshot failed'},
        status=500
    )


# ============================================================================
# Browser Endpoints
# ============================================================================

async def browser_reload(request):
    """Reload browser page."""
    result = run_screen_control('reload')
    logger.info('Browser page reloaded')
    return web.json_response(result)


async def browser_restart(request):
    """Restart the kiosk browser process."""
    env = load_env()
    display_server = env.get('KIOSK_DISPLAY_SERVER', 'cage')
    
    try:
        if display_server == 'cage':
            # For cage, restart the display-server service (which includes browser)
            subprocess.run(
                ['s6-svc', '-r', '/run/service/display-server'],
                timeout=5
            )
        else:
            subprocess.run(
                ['s6-svc', '-r', '/run/service/kiosk-browser'],
                timeout=5
            )
        logger.info('Browser restart initiated')
        return web.json_response({'status': 'ok', 'action': 'restart'})
    except Exception as e:
        return web.json_response(
            {'status': 'error', 'message': str(e)},
            status=500
        )


async def browser_url(request):
    """Change the browser URL."""
    data = await request.json()
    url = data.get('url', '')
    
    if not url:
        return web.json_response(
            {'status': 'error', 'message': 'URL is required'},
            status=400
        )
    
    env = load_env()
    display_server = env.get('KIOSK_DISPLAY_SERVER', 'cage')
    
    try:
        if display_server in ('cage', 'weston'):
            # For Wayland, we need to use a workaround
            # Write new URL and restart browser
            env_update = f'\nexport KIOSK_URL="{url}"\n'
            with open(ENV_FILE, 'a') as f:
                f.write(env_update)
            # Restart browser
            return await browser_restart(request)
        else:
            # For Xorg, use xdotool to navigate
            subprocess.run(
                ['xdotool', 'key', 'ctrl+l'],
                env={**os.environ, 'DISPLAY': ':0'},
                timeout=5
            )
            await asyncio.sleep(0.3)
            subprocess.run(
                ['xdotool', 'type', '--clearmodifiers', url],
                env={**os.environ, 'DISPLAY': ':0'},
                timeout=5
            )
            subprocess.run(
                ['xdotool', 'key', 'Return'],
                env={**os.environ, 'DISPLAY': ':0'},
                timeout=5
            )
        
        logger.info(f'Browser URL changed to: {url}')
        return web.json_response({'status': 'ok', 'url': url})
    except Exception as e:
        return web.json_response(
            {'status': 'error', 'message': str(e)},
            status=500
        )


async def browser_fullscreen(request):
    """Toggle browser fullscreen mode."""
    result = run_screen_control('key', 'F11')
    return web.json_response({'status': 'ok', 'action': 'fullscreen_toggle'})


async def browser_js(request):
    """Execute JavaScript in the browser (limited support)."""
    data = await request.json()
    js_code = data.get('code', '')
    
    if not js_code:
        return web.json_response(
            {'status': 'error', 'message': 'JavaScript code is required'},
            status=400
        )
    
    # Note: Direct JS execution requires Chrome DevTools Protocol
    # This is a placeholder for future CDP integration
    return web.json_response({
        'status': 'error',
        'message': 'Direct JavaScript execution is not yet supported. '
                   'Consider using Chrome DevTools Protocol on port 9222.'
    }, status=501)


# ============================================================================
# Input Endpoints
# ============================================================================

async def input_key(request):
    """Send a keyboard key press."""
    data = await request.json()
    key = data.get('key', '')
    
    if not key:
        return web.json_response(
            {'status': 'error', 'message': 'Key is required'},
            status=400
        )
    
    result = run_screen_control('key', key)
    return web.json_response(result)


async def input_mouse(request):
    """Move mouse to coordinates."""
    data = await request.json()
    x = str(data.get('x', 0))
    y = str(data.get('y', 0))
    
    result = run_screen_control('mouse', x, y)
    return web.json_response(result)


async def input_text(request):
    """Type text."""
    data = await request.json()
    text = data.get('text', '')
    
    if not text:
        return web.json_response(
            {'status': 'error', 'message': 'Text is required'},
            status=400
        )
    
    result = run_screen_control('text', text)
    return web.json_response(result)


# ============================================================================
# System Endpoints
# ============================================================================

async def system_info(request):
    """Get system information."""
    env = load_env()
    
    # Load options
    options = {}
    if os.path.exists(OPTIONS_FILE):
        with open(OPTIONS_FILE) as f:
            options = json.load(f)
        # Redact sensitive fields
        for key in ('password', 'token'):
            if key in options and options[key]:
                options[key] = '***'
    
    # Get process info
    chromium_running = False
    display_running = False
    try:
        result = subprocess.run(['pgrep', '-x', 'chromium'], capture_output=True)
        chromium_running = result.returncode == 0
        if not chromium_running:
            result = subprocess.run(['pgrep', '-f', 'chromium-browser'], capture_output=True)
            chromium_running = result.returncode == 0
    except Exception:
        pass
    
    display_server = env.get('KIOSK_DISPLAY_SERVER', 'unknown')
    try:
        result = subprocess.run(
            ['pgrep', '-x', display_server if display_server != 'xorg' else 'Xorg'],
            capture_output=True
        )
        display_running = result.returncode == 0
    except Exception:
        pass
    
    info = {
        'version': '1.0.0',
        'display_server': display_server,
        'gpu_type': env.get('KIOSK_GPU_TYPE', 'unknown'),
        'gpu_driver': env.get('KIOSK_GPU_DRIVER', 'unknown'),
        'monitor_count': int(env.get('KIOSK_MONITOR_COUNT', 0)),
        'primary_output': env.get('KIOSK_PRIMARY_OUTPUT', 'unknown'),
        'url': env.get('KIOSK_URL', ''),
        'chromium_running': chromium_running,
        'display_running': display_running,
        'options': options,
    }
    
    return web.json_response(info)


async def system_restart(request):
    """Restart the entire add-on."""
    logger.warning('Add-on restart requested via API')
    
    # Use supervisor API to restart this add-on
    token = os.environ.get('SUPERVISOR_TOKEN', '')
    if token:
        try:
            import urllib.request
            req = urllib.request.Request(
                'http://supervisor/addons/self/restart',
                method='POST',
                headers={
                    'Authorization': f'Bearer {token}',
                    'Content-Type': 'application/json'
                }
            )
            urllib.request.urlopen(req, timeout=5)
            return web.json_response({'status': 'ok', 'action': 'restart'})
        except Exception as e:
            return web.json_response(
                {'status': 'error', 'message': str(e)},
                status=500
            )
    
    return web.json_response(
        {'status': 'error', 'message': 'SUPERVISOR_TOKEN not available'},
        status=500
    )


# ============================================================================
# Home Assistant Integration Endpoints
# ============================================================================

async def ha_dashboard(request):
    """Switch to a different dashboard."""
    data = await request.json()
    dashboard = data.get('dashboard', '')
    
    if not dashboard:
        return web.json_response(
            {'status': 'error', 'message': 'Dashboard path is required'},
            status=400
        )
    
    env = load_env()
    ha_url = env.get('KIOSK_HA_URL', 'http://supervisor/core')
    
    # Build new URL
    dashboard = dashboard.lstrip('/')
    new_url = f'{ha_url}/{dashboard}?kiosk'
    
    # Update env file with new URL
    with open(ENV_FILE, 'a') as f:
        f.write(f'\nexport KIOSK_URL="{new_url}"\n')
        f.write(f'\nexport KIOSK_DASHBOARD="{dashboard}"\n')
    
    logger.info(f'Dashboard changed to: {dashboard}')
    
    # Restart browser to load new URL
    env_data = load_env()
    display_server = env_data.get('KIOSK_DISPLAY_SERVER', 'cage')
    try:
        if display_server == 'cage':
            subprocess.run(['s6-svc', '-r', '/run/service/display-server'], timeout=5)
        else:
            subprocess.run(['s6-svc', '-r', '/run/service/kiosk-browser'], timeout=5)
    except Exception as e:
        logger.warning(f'Browser restart after dashboard change failed: {e}')
    
    return web.json_response({'status': 'ok', 'dashboard': dashboard, 'url': new_url})


async def ha_kiosk_mode(request):
    """Toggle kiosk mode (hide/show sidebar and header)."""
    data = await request.json() if request.can_read_body else {}
    enable = data.get('enable', True)
    
    env = load_env()
    current_url = env.get('KIOSK_URL', '')
    
    if enable:
        if '?kiosk' not in current_url and '&kiosk' not in current_url:
            if '?' in current_url:
                new_url = f'{current_url}&kiosk'
            else:
                new_url = f'{current_url}?kiosk'
        else:
            new_url = current_url
    else:
        new_url = current_url.replace('?kiosk', '').replace('&kiosk', '')
    
    with open(ENV_FILE, 'a') as f:
        f.write(f'\nexport KIOSK_URL="{new_url}"\n')
    
    # Restart browser to apply
    return await browser_restart(request)


# ============================================================================
# Health Check
# ============================================================================

async def health(request):
    """Health check endpoint."""
    return web.json_response({'status': 'healthy'})


# ============================================================================
# Application Setup
# ============================================================================

def create_app():
    """Create and configure the aiohttp application."""
    app = web.Application()
    
    # Health
    app.router.add_get('/api/health', health)
    
    # Display endpoints
    app.router.add_post('/api/display/on', display_on)
    app.router.add_post('/api/display/off', display_off)
    app.router.add_post('/api/display/toggle', display_toggle)
    app.router.add_get('/api/display/status', display_status)
    app.router.add_post('/api/display/brightness', display_brightness)
    app.router.add_get('/api/display/screenshot', display_screenshot)
    
    # Browser endpoints
    app.router.add_post('/api/browser/reload', browser_reload)
    app.router.add_post('/api/browser/restart', browser_restart)
    app.router.add_post('/api/browser/url', browser_url)
    app.router.add_post('/api/browser/fullscreen', browser_fullscreen)
    app.router.add_post('/api/browser/js', browser_js)
    
    # Input endpoints
    app.router.add_post('/api/input/key', input_key)
    app.router.add_post('/api/input/mouse', input_mouse)
    app.router.add_post('/api/input/text', input_text)
    
    # System endpoints
    app.router.add_get('/api/system/info', system_info)
    app.router.add_post('/api/system/restart', system_restart)
    
    # Home Assistant integration
    app.router.add_post('/api/ha/dashboard', ha_dashboard)
    app.router.add_post('/api/ha/kiosk-mode', ha_kiosk_mode)
    
    return app


def main():
    """Main entry point."""
    port = int(os.environ.get('KIOSK_API_PORT', '8099'))
    
    logger.info(f'Starting Kiosk Display REST API on port {port}')
    
    app = create_app()
    web.run_app(
        app,
        host='0.0.0.0',
        port=port,
        print=lambda msg: logger.info(msg)
    )


if __name__ == '__main__':
    main()
