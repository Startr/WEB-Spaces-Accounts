import atexit
import os
import platform
import re
import shutil
import subprocess
import tarfile
import tempfile
import time
from pathlib import Path
from typing import List, Optional
from random import randint
from threading import Timer

import requests

BASE_URL = "https://github.com/cloudflare/cloudflared/releases/latest/download"

def _normalize_machine(machine: str) -> str:
    m = machine.lower()
    if m in {"x86_64", "amd64"}:
        return "amd64"
    if m in {"aarch64", "arm64"}:
        return "arm64"
    if m in {"i386", "i686", "x86"}:
        return "386"
    if m.startswith("arm"):
        return "arm"
    return machine


def _platform_spec():
    system = platform.system()
    arch = _normalize_machine(platform.machine())
    if system == "Darwin":
        return {
            "system": system,
            "arch": arch,
            "is_archive": True,
            "url": f"{BASE_URL}/cloudflared-darwin-{arch}.tgz",
            "binary_name": "cloudflared",
        }
    if system == "Linux":
        return {
            "system": system,
            "arch": arch,
            "is_archive": False,
            "url": f"{BASE_URL}/cloudflared-linux-{arch}",
            "binary_name": f"cloudflared-linux-{arch}",
        }
    if system == "Windows":
        win_arch = "amd64" if arch == "amd64" else "386"
        return {
            "system": system,
            "arch": win_arch,
            "is_archive": False,
            "url": f"{BASE_URL}/cloudflared-windows-{win_arch}.exe",
            "binary_name": f"cloudflared-windows-{win_arch}.exe",
        }
    raise Exception(f"Unsupported platform: {system} {arch}")


def _safe_extract_tar(tar: tarfile.TarFile, path: str) -> None:
    base = Path(path).resolve()
    for member in tar.getmembers():
        member_path = (base / member.name).resolve()
        if base not in member_path.parents and base != member_path:
            raise Exception("Blocked tar extraction with path traversal")
    tar.extractall(path)


def _download(url: str, dest: Path) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with requests.get(url, stream=True, timeout=60) as r:
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(chunk_size=1024 * 1024):
                if chunk:
                    f.write(chunk)
    return dest


def _ensure_cloudflared() -> str:
    existing = shutil.which("cloudflared")
    if existing:
        return existing

    spec = _platform_spec()
    cache_dir = Path(tempfile.gettempdir()) / "cloudflared-cache"
    if spec["is_archive"]:
        archive_name = Path(spec["url"]).name
        archive_path = cache_dir / archive_name
        bin_path = cache_dir / spec["binary_name"]
        if not bin_path.exists():
            if not archive_path.exists():
                print(f" * Downloading cloudflared ({spec['system']} {spec['arch']})...")
                _download(spec["url"], archive_path)
            with tarfile.open(archive_path, "r:gz") as tar:
                _safe_extract_tar(tar, str(cache_dir))
            if not bin_path.exists():
                # Some archives may include a folder; find the binary
                for member in cache_dir.rglob("cloudflared"):
                    if member.is_file():
                        shutil.move(str(member), str(bin_path))
                        break
        os.chmod(bin_path, 0o755)
        return str(bin_path)
    else:
        bin_path = cache_dir / spec["binary_name"]
        if not bin_path.exists():
            print(f" * Downloading cloudflared ({spec['system']} {spec['arch']})...")
            _download(spec["url"], bin_path)
        if os.name != "nt":
            os.chmod(bin_path, 0o755)
        return str(bin_path)


def _build_command(executable: str, port: int, metrics_port: int, tunnel_id: Optional[str], config_path: Optional[str]) -> List[str]:
    cmd = [executable, "tunnel", "--metrics", f"127.0.0.1:{metrics_port}"]
    if config_path:
        cmd += ["--config", config_path, "run"]
    elif tunnel_id:
        cmd += ["--url", f"http://127.0.0.1:{port}", "run", tunnel_id]
    else:
        cmd += ["--url", f"http://127.0.0.1:{port}"]
    return cmd


def _wait_for_tunnel_url(metrics_port: int, tunnel_id: Optional[str], config_path: Optional[str]) -> str:
    metrics_url = f"http://127.0.0.1:{metrics_port}/metrics"
    for _ in range(20):
        try:
            resp = requests.get(metrics_url, timeout=2)
            if resp.ok:
                metrics = resp.text
                if tunnel_id or config_path:
                    if re.search(r"cloudflared_tunnel_ha_connections\s\d", metrics):
                        return "preconfigured tunnel URL"
                else:
                    m = re.search(r"(?P<url>https?://[^\s]+\.trycloudflare\.com)", metrics)
                    if m:
                        return m.group("url")
        except Exception:
            pass
        time.sleep(1.5)
    raise Exception("Can't connect to Cloudflare Edge")


def _run_cloudflared(port: int, metrics_port: int, tunnel_id: Optional[str] = None, config_path: Optional[str] = None) -> str:
    executable = _ensure_cloudflared()
    cmd = _build_command(executable, port, metrics_port, tunnel_id, config_path)
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    atexit.register(proc.terminate)
    return _wait_for_tunnel_url(metrics_port, tunnel_id, config_path)


def start_cloudflared(port: int, metrics_port: int, tunnel_id: Optional[str] = None, config_path: Optional[str] = None) -> None:
    addr = _run_cloudflared(port, metrics_port, tunnel_id, config_path)
    print(f" * Running on {addr}")
    print(f" * Traffic stats available on http://127.0.0.1:{metrics_port}/metrics")


def run_with_cloudflared(app):
    old_run = app.run

    def new_run(*args, **kwargs):
        port = kwargs.pop("port", 8000)
        metrics_port = kwargs.pop("metrics_port", randint(8100, 9000))
        tunnel_id = kwargs.pop("tunnel_id", None)
        config_path = kwargs.pop("config_path", None)

        thread = Timer(2, start_cloudflared, args=(port, metrics_port, tunnel_id, config_path))
        thread.daemon = True
        thread.start()

        old_run(*args, **kwargs)

    app.run = new_run
