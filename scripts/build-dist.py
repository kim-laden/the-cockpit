#!/usr/bin/env python3
"""Build The CockPit release packages into dist/.

Needs the official WezTerm release assets in vendor/wezterm/ (see VENDOR below; the
script verifies their published SHA-256 first), plus, for the AppImage,
appimagetool + its type2 runtime in vendor/appimage/. dpkg-deb builds the .deb.

(c) 2026 Laden AS, released under the MIT License.
"""
import hashlib
import os
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / 'VERSION').read_text().strip()
DIST = ROOT / 'dist'
VENDOR = Path(os.environ.get('COCKPIT_VENDOR', ROOT / 'vendor'))
WEZ_TAG = '20240203-110809-5046fc22'
WEZ = {
    'linux': (f'WezTerm-{WEZ_TAG}-Ubuntu20.04.AppImage', '34010a07076d2272c4d4f94b5e0dae608a679599e8d729446323f88f956c60f0'),
    'windows': (f'WezTerm-windows-{WEZ_TAG}.zip', '57e5d03b585303d81e8b8e96d1230362852eb39aca92b3b29c7a42cfb82f9ac4'),
    'macos': (f'WezTerm-macos-{WEZ_TAG}.zip', 'e77388cad55f2e9da95a220a89206a6c58f865874a629b7c3ea3c162f5692224'),
}
APP_ITEMS = ['bin', 'config', 'docs', 'tools', 'licenses', 'LICENSE', 'README.md', 'CHANGELOG.md',
             'THIRD_PARTY_NOTICES.md', 'VERSION']
EPOCH = 1794009600  # 2026-11-07 00:00 UTC, for stable archive timestamps


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def vendor(kind):
    name, digest = WEZ[kind]
    path = VENDOR / 'wezterm' / name
    if not path.exists():
        sys.exit(f'missing {path}: download it from https://github.com/wez/wezterm/releases/tag/{WEZ_TAG}')
    if sha256(path) != digest:
        sys.exit(f'checksum mismatch for {path}')
    return path


def copy_app(dest, icons_only=True):
    dest.mkdir(parents=True, exist_ok=True)
    for item in APP_ITEMS:
        src = ROOT / item
        if src.is_dir():
            shutil.copytree(src, dest / item, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        else:
            shutil.copy2(src, dest / item)
    (dest / 'assets').mkdir(exist_ok=True)
    shutil.copytree(ROOT / 'assets' / 'icons', dest / 'assets' / 'icons')
    os.chmod(dest / 'bin' / 'cockpit', 0o755)
    os.chmod(dest / 'tools' / 'cockpit-hardware.py', 0o755)


def zip_dir(src_parent, names, out):
    """Zip with Unix permissions preserved (executables stay executable on macOS/Linux)."""
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in names:
            base = src_parent / name
            paths = [base] + sorted(base.rglob('*')) if base.is_dir() else [base]
            for p in paths:
                rel = p.relative_to(src_parent).as_posix()
                st = p.lstat()
                info = zipfile.ZipInfo(rel + ('/' if p.is_dir() else ''), date_time=(2026, 11, 7, 0, 0, 0))
                info.create_system = 3
                info.external_attr = (st.st_mode & 0xFFFF) << 16
                if p.is_dir():
                    info.external_attr |= 0x10
                    z.writestr(info, b'')
                else:
                    info.compress_type = zipfile.ZIP_DEFLATED
                    with open(p, 'rb') as f:
                        z.writestr(info, f.read())


def tar_dir(src_parent, name, out):
    def norm(ti):
        ti.uid = ti.gid = 0
        ti.uname = ti.gname = 'root'
        ti.mtime = EPOCH
        return ti
    with tarfile.open(out, 'w:gz', compresslevel=9) as t:
        t.add(src_parent / name, arcname=name, filter=norm)


def build_linux_tarball(work):
    name = f'the-cockpit-{VERSION}-linux-x86_64'
    d = work / name
    copy_app(d)
    for f in ('install.sh', 'uninstall.sh'):
        shutil.copy2(ROOT / 'packaging' / 'linux' / f, d / f)
    (d / 'packaging' / 'linux').mkdir(parents=True)
    shutil.copy2(ROOT / 'packaging' / 'linux' / 'the-cockpit.desktop', d / 'packaging' / 'linux')
    (d / 'wezterm').mkdir()
    appimage = vendor('linux')
    shutil.copy2(appimage, d / 'wezterm' / appimage.name)
    os.chmod(d / 'wezterm' / appimage.name, 0o755)
    out = DIST / f'{name}.tar.gz'
    tar_dir(work, name, out)
    return out


def build_appimage(work):
    tool = VENDOR / 'appimage' / 'appimagetool' / 'AppRun'
    runtime = VENDOR / 'appimage' / 'runtime-x86_64'
    if not tool.exists() or not runtime.exists():
        print('skip AppImage: appimagetool/runtime not in vendor/appimage', file=sys.stderr)
        return None
    appdir = work / 'TheCockPit.AppDir'
    with tempfile.TemporaryDirectory() as t:
        img = Path(t) / 'w.AppImage'
        shutil.copy2(vendor('linux'), img)
        os.chmod(img, 0o755)
        subprocess.run([str(img), '--appimage-extract'], cwd=t, check=True, stdout=subprocess.DEVNULL)
        shutil.move(str(Path(t) / 'squashfs-root'), appdir)
    for leftover in ('AppRun', 'wezterm.desktop', 'org.wezfurlong.wezterm.png', '.DirIcon'):
        p = appdir / leftover
        if p.exists() or p.is_symlink():
            p.unlink()
    copy_app(appdir / 'usr' / 'share' / 'the-cockpit')
    (appdir / 'AppRun').write_text(
        '#!/bin/sh\n'
        '# The CockPit AppImage entry point. (c) 2026 Laden AS, MIT License.\n'
        'HERE="$(dirname "$(readlink -f "$0")")"\n'
        'export COCKPIT_WEZTERM="$HERE/usr/bin/wezterm"\n'
        'exec "$HERE/usr/share/the-cockpit/bin/cockpit" "$@"\n')
    os.chmod(appdir / 'AppRun', 0o755)
    desktop = (ROOT / 'packaging' / 'linux' / 'the-cockpit.desktop').read_text().replace('@EXEC@', 'cockpit')
    (appdir / 'the-cockpit.desktop').write_text(desktop)
    shutil.copy2(ROOT / 'assets' / 'icons' / 'the-cockpit-256.png', appdir / 'the-cockpit.png')
    os.symlink('the-cockpit.png', appdir / '.DirIcon')
    for size in (48, 128, 256, 512):
        p = appdir / 'usr' / 'share' / 'icons' / 'hicolor' / f'{size}x{size}' / 'apps'
        p.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / 'assets' / 'icons' / f'the-cockpit-{size}.png', p / 'the-cockpit.png')
    out = DIST / f'TheCockPit-{VERSION}-x86_64.AppImage'
    validate = tool.parent / 'usr' / 'bin' / 'desktop-file-validate'
    if validate.exists():
        subprocess.run([str(validate), str(appdir / 'the-cockpit.desktop')], check=True)
    if shutil.which('file'):
        env = {**os.environ, 'ARCH': 'x86_64', 'VERSION': VERSION}
        subprocess.run([str(tool), '--no-appstream', '--runtime-file', str(runtime), str(appdir), str(out)],
                       check=True, env=env, stdout=subprocess.DEVNULL)
    else:
        # Same result as appimagetool: the type2 runtime followed by a zstd SquashFS of the AppDir.
        squash = work / 'appdir.squashfs'
        subprocess.run([str(tool.parent / 'usr' / 'bin' / 'mksquashfs'), str(appdir), str(squash),
                        '-root-owned', '-noappend', '-no-xattrs', '-comp', 'zstd', '-Xcompression-level', '19',
                        '-b', '1M', '-mkfs-time', '0', '-all-time', '0', '-quiet'],
                       check=True, stdout=subprocess.DEVNULL)
        with open(out, 'wb') as dst:
            for part in (runtime, squash):
                with open(part, 'rb') as src:
                    shutil.copyfileobj(src, dst)
    os.chmod(out, 0o755)
    return out


def build_deb(work):
    if not shutil.which('dpkg-deb'):
        print('skip .deb: dpkg-deb not found', file=sys.stderr)
        return None
    pkg = work / 'deb'
    app = pkg / 'usr' / 'share' / 'the-cockpit'
    copy_app(app)
    (pkg / 'usr' / 'bin').mkdir(parents=True)
    os.symlink('../share/the-cockpit/bin/cockpit', pkg / 'usr' / 'bin' / 'cockpit')
    apps = pkg / 'usr' / 'share' / 'applications'
    apps.mkdir(parents=True)
    (apps / 'the-cockpit.desktop').write_text(
        (ROOT / 'packaging' / 'linux' / 'the-cockpit.desktop').read_text().replace('@EXEC@', 'cockpit'))
    for size in (48, 128, 256, 512):
        p = pkg / 'usr' / 'share' / 'icons' / 'hicolor' / f'{size}x{size}' / 'apps'
        p.mkdir(parents=True)
        shutil.copy2(ROOT / 'assets' / 'icons' / f'the-cockpit-{size}.png', p / 'the-cockpit.png')
    doc = pkg / 'usr' / 'share' / 'doc' / 'the-cockpit'
    doc.mkdir(parents=True)
    (doc / 'copyright').write_text(
        'Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/\n'
        'Upstream-Name: the-cockpit\nSource: https://laden.no/\n\n'
        'Files: *\nCopyright: 2026 Laden AS\nLicense: MIT\n ' +
        '\n '.join(l if l else '.' for l in (ROOT / 'LICENSE').read_text().splitlines()[2:]) + '\n')
    installed_kb = sum(f.stat().st_size for f in pkg.rglob('*') if f.is_file()) // 1024 + 1
    (pkg / 'DEBIAN').mkdir()
    (pkg / 'DEBIAN' / 'control').write_text(
        (ROOT / 'packaging' / 'debian' / 'control').read_text()
        .replace('@VERSION@', VERSION).replace('@SIZE@', str(installed_kb)))
    for p in pkg.rglob('*'):
        if p.is_symlink():
            continue
        os.chmod(p, 0o755 if p.is_dir() or os.access(p, os.X_OK) else 0o644)
    out = DIST / f'the-cockpit_{VERSION}_all.deb'
    subprocess.run(['dpkg-deb', '--root-owner-group', '-Zxz', '--build', str(pkg), str(out)],
                   check=True, stdout=subprocess.DEVNULL)
    return out


def build_windows(work):
    name = 'TheCockPit'
    d = work / 'win' / name
    copy_app(d)
    for f in ('install.ps1', 'uninstall.ps1', 'Start-TheCockPit.cmd'):
        shutil.copy2(ROOT / 'packaging' / 'windows' / f, d / f)
    shutil.copy2(ROOT / 'bin' / 'cockpit.ps1', d / 'bin' / 'cockpit.ps1')
    (d / 'bin' / 'cockpit').unlink()  # the bash launcher is for Linux/macOS
    wezdir = d / 'wezterm'
    wezdir.mkdir()
    with zipfile.ZipFile(vendor('windows')) as z:
        for info in z.infolist():
            if info.is_dir() or info.filename.endswith('.pdb'):
                continue
            rel = Path(info.filename).relative_to(Path(info.filename).parts[0])
            target = wezdir / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            with z.open(info) as src, open(target, 'wb') as dst:
                shutil.copyfileobj(src, dst)
    (d / 'README-WINDOWS.txt').write_text(
        'The CockPit for Windows 10/11 (x64)\r\n'
        '===================================\r\n\r\n'
        'Install (Start menu shortcut, no admin):\r\n'
        '  Right-click install.ps1 > Run with PowerShell\r\n'
        '  or: powershell -ExecutionPolicy Bypass -File .\\install.ps1 -Desktop\r\n\r\n'
        'Portable (no install): double-click Start-TheCockPit.cmd\r\n\r\n'
        'Right-click or F12 opens the CockPit menu. The default shell is PowerShell;\r\n'
        'WSL (wsl --install) gives you a Linux shell with fish inside The CockPit.\r\n'
        'Windows SmartScreen may warn because the files are not code-signed by Laden AS.\r\n\r\n'
        'Bundles WezTerm ' + WEZ_TAG + ' (MIT, Wez Furlong), unmodified.\r\n'
        '(c) 2026 Laden AS, released under the MIT License.\r\n')
    out = DIST / f'TheCockPit-{VERSION}-windows-x64.zip'
    zip_dir(work / 'win', [name], out)
    return out


def build_macos(work):
    base = work / 'mac'
    app = base / 'The CockPit.app'
    contents = app / 'Contents'
    (contents / 'MacOS').mkdir(parents=True)
    res = contents / 'Resources'
    res.mkdir()
    shutil.copy2(ROOT / 'packaging' / 'macos' / 'Info.plist', contents / 'Info.plist')
    shutil.copy2(ROOT / 'packaging' / 'macos' / 'cockpit-launcher', contents / 'MacOS' / 'cockpit-launcher')
    os.chmod(contents / 'MacOS' / 'cockpit-launcher', 0o755)
    shutil.copy2(ROOT / 'assets' / 'icons' / 'the-cockpit.icns', res / 'the-cockpit.icns')
    (contents / 'PkgInfo').write_text('APPL????')
    copy_app(res / 'cockpit')
    with zipfile.ZipFile(vendor('macos')) as z:
        for info in z.infolist():
            parts = Path(info.filename).parts
            if len(parts) < 2 or parts[1] != 'WezTerm.app':
                continue
            target = res.joinpath(*parts[1:])
            if info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with z.open(info) as src, open(target, 'wb') as dst:
                shutil.copyfileobj(src, dst)
            mode = (info.external_attr >> 16) & 0o777
            os.chmod(target, mode or 0o644)
    (base / 'README-macOS.txt').write_text(
        'The CockPit for macOS (Apple Silicon and Intel)\n'
        '===============================================\n\n'
        '1. Drag "The CockPit.app" to Applications.\n'
        '2. The app is not notarized by Apple. The first time, right-click it and choose Open,\n'
        '   or run:  xattr -dr com.apple.quarantine "/Applications/The CockPit.app"\n'
        '3. Right-click or F12 (fn+F12 on laptops, or Ctrl+Option+Space) opens the CockPit menu.\n\n'
        'Command line: ln -s "/Applications/The CockPit.app/Contents/Resources/cockpit/bin/cockpit" /usr/local/bin/cockpit\n'
        'Install fish (brew install fish) for the default CockPit shell; otherwise your login shell is used.\n'
        'The Dock shows the WezTerm engine icon while it runs; the app icon in Finder/Launchpad is The CockPit.\n\n'
        'Bundles WezTerm ' + WEZ_TAG + ' (MIT, Wez Furlong), unmodified and still signed by its author.\n'
        '(c) 2026 Laden AS, released under the MIT License.\n')
    shutil.copy2(ROOT / 'LICENSE', base / 'LICENSE.txt')
    out = DIST / f'TheCockPit-{VERSION}-macOS-universal.zip'
    zip_dir(base, ['The CockPit.app', 'README-macOS.txt', 'LICENSE.txt'], out)
    return out


def main():
    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir()
    built = []
    with tempfile.TemporaryDirectory() as t:
        work = Path(t)
        for fn in (build_linux_tarball, build_appimage, build_deb, build_windows, build_macos):
            out = fn(work)
            if out:
                built.append(out)
                print(f'built {out.name}  {out.stat().st_size / 2**20:.1f} MiB')
    sums = ''.join(f'{sha256(p)}  {p.name}\n' for p in sorted(built))
    (DIST / 'SHA256SUMS').write_text(sums)
    print(sums, end='')


if __name__ == '__main__':
    main()
