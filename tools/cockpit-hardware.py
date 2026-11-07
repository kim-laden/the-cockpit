#!/usr/bin/env python3
"""The CockPit hardware overview: local, read-only, no network calls.

Prints CPU/RAM, graphics and network controllers with their drivers, the current
OpenGL renderer (Linux) and Wi-Fi interface modes. It deliberately omits MAC/IP
addresses, serial numbers, UUIDs and PCI bus addresses, and changes nothing.

(c) 2026 Laden AS, released under the MIT License.
"""
import json
import os
import platform
import re
import shutil
import subprocess
import sys

TOOLS = ['lspci', 'lsusb', 'iw', 'glxinfo', 'vulkaninfo', 'wezterm', 'fish', 'python3', 'ssh']


def run(argv):
    if not shutil.which(argv[0]):
        return ''
    try:
        p = subprocess.run(argv, capture_output=True, text=True, timeout=8,
                           env={**os.environ, 'LC_ALL': 'C'})
        return p.stdout if p.returncode == 0 else ''
    except (OSError, subprocess.TimeoutExpired):
        return ''


def renderer_summary(text):
    allowed = ('direct rendering:', 'OpenGL vendor string:',
               'OpenGL renderer string:', 'OpenGL core profile version string:')
    return [s.strip() for s in text.splitlines() if s.strip().startswith(allowed)]


def pci_summary(text):
    result = []
    for block in re.split(r'\n\s*\n', text):
        lines = block.splitlines()
        if not lines or not re.search(r'VGA compatible controller|3D controller|Display controller|Network controller|Ethernet controller', lines[0]):
            continue
        # Omit PCI addresses, subsystem IDs and other details on purpose.
        result.append(re.sub(r'^\S+\s+', '', lines[0]))
        result.extend(s.strip() for s in lines[1:] if s.strip().startswith('Kernel driver in use:'))
    return result


def wifi_summary(text):
    modes, active = set(), False
    for line in text.splitlines():
        if 'Supported interface modes:' in line:
            active = True
            continue
        if active:
            m = re.match(r'\s+\*\s+(.+?)\s*$', line)
            if m:
                modes.add(m.group(1))
            elif line.strip():
                active = False
    return sorted(modes)


def mac_display_summary(text):
    keep = ('Chipset Model:', 'Vendor:', 'Metal Support:', 'Metal Family:', 'Total Number of Cores:')
    return [s.strip() for s in text.splitlines() if s.strip().startswith(keep)]


def windows_gpu_summary(text):
    out = []
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith(('Name', '----')):
            out.append(re.sub(r'\s{2,}', ' | ', line))
    return out


def ram_gib():
    try:
        return round(os.sysconf('SC_PHYS_PAGES') * os.sysconf('SC_PAGE_SIZE') / 2**30, 1)
    except (AttributeError, OSError, ValueError):
        pass
    if sys.platform == 'darwin':
        out = run(['sysctl', '-n', 'hw.memsize']).strip()
        return round(int(out) / 2**30, 1) if out.isdigit() else None
    if os.name == 'nt':
        try:
            import ctypes

            class MEMORYSTATUSEX(ctypes.Structure):
                _fields_ = [('dwLength', ctypes.c_ulong), ('dwMemoryLoad', ctypes.c_ulong),
                            ('ullTotalPhys', ctypes.c_ulonglong), ('ullAvailPhys', ctypes.c_ulonglong),
                            ('ullTotalPageFile', ctypes.c_ulonglong), ('ullAvailPageFile', ctypes.c_ulonglong),
                            ('ullTotalVirtual', ctypes.c_ulonglong), ('ullAvailVirtual', ctypes.c_ulonglong),
                            ('sullAvailExtendedVirtual', ctypes.c_ulonglong)]
            stat = MEMORYSTATUSEX()
            stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
            ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat))
            return round(stat.ullTotalPhys / 2**30, 1)
        except Exception:  # noqa: BLE001 - best effort only
            return None
    return None


def collect():
    data = {'system': f'{platform.system()} {platform.release()}',
            'architecture': platform.machine(),
            'logical_cpus': os.cpu_count(),
            'ram_gib': ram_gib()}
    if sys.platform.startswith('linux'):
        renderer = renderer_summary(run(['glxinfo', '-B'])) if (os.environ.get('DISPLAY') or os.environ.get('WAYLAND_DISPLAY')) else []
        data['gpu_and_network_drivers'] = pci_summary(run(['lspci', '-k']))
        data['opengl_current_session'] = renderer or ['Unavailable: no display, driver or glxinfo.']
        data['wifi_supported_modes'] = wifi_summary(run(['iw', 'list']))
    elif sys.platform == 'darwin':
        data['graphics'] = mac_display_summary(run(['system_profiler', 'SPDisplaysDataType'])) or ['Unavailable.']
    elif os.name == 'nt':
        ps = shutil.which('powershell') or shutil.which('pwsh')
        text = run([ps, '-NoProfile', '-Command',
                    'Get-CimInstance Win32_VideoController | Format-Table -HideTableHeaders Name,DriverVersion']) if ps else ''
        data['graphics'] = windows_gpu_summary(text) or ['Unavailable.']
    data['tools'] = {n: bool(shutil.which(n)) for n in TOOLS}
    return data


def advice(d):
    notes = ['Read-only: no CPU governor, clocks, screen layout, GPU selection or driver setting was changed.']
    if d.get('ram_gib') is not None and d['ram_gib'] < 8:
        notes.append('Limited RAM: keep fewer panes and browser tabs open.')
    if any('llvmpipe' in s.lower() or 'softpipe' in s.lower() for s in d.get('opengl_current_session', [])):
        notes.append('Software OpenGL renderer detected: GPU acceleration may be unavailable; review your graphics driver.')
    if d.get('wifi_supported_modes'):
        notes.append('Wi-Fi modes listed by the driver do not prove capture/injection support.')
    return notes


def main(argv):
    if argv and argv != ['--json']:
        print('Usage: cockpit-hardware [--json]', file=sys.stderr)
        return 2
    data = collect()
    data['advisory_only'] = advice(data)
    if argv == ['--json']:
        print(json.dumps(data, indent=2))
        return 0
    print('THE COCKPIT — local hardware overview (no identifiers, no upload, no tuning)')
    for key, value in data.items():
        print('\n' + key.replace('_', ' ').title() + ':')
        if isinstance(value, list):
            for line in value:
                print('  ' + str(line))
        elif isinstance(value, dict):
            for k, v in value.items():
                print('  ' + k + ': ' + ('available' if v else 'missing'))
        else:
            print('  ' + str(value))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
