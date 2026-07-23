"""Kiosk Display API - Utility Handlers.

Shared utilities for the Kiosk Display REST API.
"""

import json
import os
import subprocess
from pathlib import Path


class KioskEnvironment:
    """Manages kiosk runtime environment."""
    
    ENV_FILE = '/var/run/kiosk/env.sh'
    OPTIONS_FILE = '/data/options.json'
    
    @classmethod
    def load(cls):
        """Load environment variables from the env file."""
        env = {}
        if os.path.exists(cls.ENV_FILE):
            with open(cls.ENV_FILE) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('export '):
                        line = line[7:]
                    if '=' in line and not line.startswith('#'):
                        key, _, value = line.partition('=')
                        value = value.strip('"').strip("'")
                        env[key] = value
        return env
    
    @classmethod
    def update(cls, key, value):
        """Append or update an environment variable."""
        with open(cls.ENV_FILE, 'a') as f:
            f.write(f'\nexport {key}="{value}"\n')
    
    @classmethod
    def get_options(cls):
        """Load add-on options from options.json."""
        if os.path.exists(cls.OPTIONS_FILE):
            with open(cls.OPTIONS_FILE) as f:
                return json.load(f)
        return {}


def execute_command(cmd, timeout=10, env_extra=None):
    """Execute a shell command and return the result."""
    env = os.environ.copy()
    env['XDG_RUNTIME_DIR'] = '/run/user/0'
    if env_extra:
        env.update(env_extra)
    
    try:
        result = subprocess.run(
            cmd if isinstance(cmd, list) else cmd.split(),
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env
        )
        return {
            'returncode': result.returncode,
            'stdout': result.stdout.strip(),
            'stderr': result.stderr.strip(),
        }
    except subprocess.TimeoutExpired:
        return {'returncode': -1, 'error': 'Command timed out'}
    except FileNotFoundError:
        return {'returncode': -1, 'error': f'Command not found: {cmd[0] if isinstance(cmd, list) else cmd}'}
    except Exception as e:
        return {'returncode': -1, 'error': str(e)}


def get_chromium_pid():
    """Find the Chromium process ID."""
    for name in ('chromium', 'chromium-browser'):
        result = execute_command(['pgrep', '-x', name], timeout=3)
        if result['returncode'] == 0 and result['stdout']:
            return int(result['stdout'].split('\n')[0])
    return None


def is_display_server_running():
    """Check if the display server process is running."""
    env = KioskEnvironment.load()
    server = env.get('KIOSK_DISPLAY_SERVER', '')
    
    process_name = {
        'cage': 'cage',
        'weston': 'weston',
        'xorg': 'Xorg',
    }.get(server, server)
    
    result = execute_command(['pgrep', '-x', process_name], timeout=3)
    return result['returncode'] == 0
