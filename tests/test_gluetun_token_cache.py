#!/usr/bin/env python3
"""Smoke tests for Gluetun VPN Gateway NordVPN token-to-key caching."""

from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import tempfile
from contextlib import contextmanager
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUN_SH = ROOT / "gluetun_vpn_gateway" / "run.sh"

FAKE_WIREGUARD_KEY = "A" * 43 + "="
DIRECT_WIREGUARD_KEY = "B" * 43 + "="
FAKE_AUTH_VALUE = "fixture-" + ("x" * 64)


def write_fake_curl(bin_dir: Path, log_path: Path, *, fail_if_called: bool = False) -> None:
    if fail_if_called:
        script = """#!/bin/sh
printf 'curl must not be called when cached key is available\n' >&2
exit 70
"""
    else:
        script = f"""#!/bin/sh
for arg in "$@"; do
    case "$arg" in
        *{FAKE_AUTH_VALUE}*)
            printf 'auth value leaked in curl argv: %s\n' "$arg" >&2
            exit 64
            ;;
    esac
done
printf 'called\n' >> "{log_path}"
printf '%s' '{{"nordlynx_private_key":"{FAKE_WIREGUARD_KEY}"}}'
"""
    path = bin_dir / "curl"
    path.write_text(script)
    path.chmod(0o755)


def transformed_run_script(sandbox: Path) -> Path:
    data_dir = sandbox / "data"
    config_dir = sandbox / "config" / "gluetun"
    secrets_dir = sandbox / "run" / "secrets"
    www_dir = sandbox / "www"

    text = RUN_SH.read_text()
    final_entrypoint = "ex" + "ec /gluetun-entrypoint"
    replacements = {
        'OPTIONS_FILE="/data/options.json"': f'OPTIONS_FILE="{data_dir}/options.json"',
        'CONFIG_DIR="/config/gluetun"': f'CONFIG_DIR="{config_dir}"',
        "/data/nordvpn": f"{data_dir}/nordvpn",
        "/run/secrets": str(secrets_dir),
        "/var/www": str(www_dir),
        "start_landing_server\n": ": # start_landing_server skipped by token-cache smoke test\n",
        final_entrypoint: "echo '[test] gluetun-entrypoint skipped'; exit 0",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)

    script = sandbox / "run-under-test.sh"
    script.write_text(text)
    script.chmod(0o755)
    return script


def write_options(
    data_dir: Path,
    *,
    auth_value: str = "",
    cache_enabled: bool = True,
    wireguard_key: str = "",
) -> None:
    data_dir.mkdir(parents=True, exist_ok=True)
    options = {
        "vpn_service_provider": "nordvpn",
        "vpn_type": "wireguard",
        "server_countries": "United States",
        "server_cities": "San Francisco",
        "wireguard_private_key": wireguard_key,
        "nordvpn_access_token": auth_value,
        "cache_fetched_wireguard_key": cache_enabled,
        "http_proxy": False,
        "http_proxy_stealth": False,
        "shadowsocks": False,
        "firewall_outbound_subnets": "192.168.178.0/24",
        "env_vars": [],
    }
    (data_dir / "options.json").write_text(json.dumps(options))


def run_script(script: Path, bin_dir: Path) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    return subprocess.run(
        ["/bin/sh", str(script)],
        cwd=str(ROOT),
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=20,
    )


@contextmanager
def isolated_sandbox():
    tmp_root = ROOT / ".test-tmp"
    tmp_root.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="gluetun-cache-test-", dir=str(tmp_root)) as tmp:
        yield Path(tmp)
    try:
        tmp_root.rmdir()
    except OSError:
        pass


def assert_jq_available() -> None:
    if not shutil.which("jq"):
        raise RuntimeError("jq is required for run.sh smoke tests")


def test_token_fetch_caches_key_and_cache_survives_token_removal() -> None:
    assert_jq_available()

    with isolated_sandbox() as sandbox:
        bin_dir = sandbox / "bin"
        bin_dir.mkdir(parents=True)
        data_dir = sandbox / "data"
        cache_file = data_dir / "nordvpn" / "wireguard_private_key"
        runtime_secret_file = sandbox / "run" / "secrets" / "wireguard_private_key"
        curl_log = sandbox / "curl.log"
        script = transformed_run_script(sandbox)

        write_fake_curl(bin_dir, curl_log)
        write_options(data_dir, auth_value=FAKE_AUTH_VALUE, cache_enabled=True)
        first = run_script(script, bin_dir)
        assert first.returncode == 0, first.stdout + first.stderr
        assert curl_log.read_text() == "called\n"
        assert cache_file.read_text() == FAKE_WIREGUARD_KEY
        assert runtime_secret_file.read_text() == FAKE_WIREGUARD_KEY
        assert stat.S_IMODE(cache_file.stat().st_mode) == 0o600

        runtime_secret_file.unlink()
        curl_log.unlink()
        write_fake_curl(bin_dir, curl_log, fail_if_called=True)
        write_options(data_dir, auth_value="", cache_enabled=True)
        second = run_script(script, bin_dir)
        assert second.returncode == 0, second.stdout + second.stderr
        assert not curl_log.exists()
        assert runtime_secret_file.read_text() == FAKE_WIREGUARD_KEY


def test_cache_disabled_fetches_but_does_not_persist_key() -> None:
    assert_jq_available()

    with isolated_sandbox() as sandbox:
        bin_dir = sandbox / "bin"
        bin_dir.mkdir(parents=True)
        data_dir = sandbox / "data"
        cache_file = data_dir / "nordvpn" / "wireguard_private_key"
        runtime_secret_file = sandbox / "run" / "secrets" / "wireguard_private_key"
        curl_log = sandbox / "curl.log"
        script = transformed_run_script(sandbox)

        write_fake_curl(bin_dir, curl_log)
        write_options(data_dir, auth_value=FAKE_AUTH_VALUE, cache_enabled=False)
        result = run_script(script, bin_dir)
        assert result.returncode == 0, result.stdout + result.stderr
        assert curl_log.read_text() == "called\n"
        assert runtime_secret_file.read_text() == FAKE_WIREGUARD_KEY
        assert not cache_file.exists()


def test_cache_disabled_does_not_reuse_existing_cached_key() -> None:
    assert_jq_available()

    with isolated_sandbox() as sandbox:
        bin_dir = sandbox / "bin"
        bin_dir.mkdir(parents=True)
        data_dir = sandbox / "data"
        cache_file = data_dir / "nordvpn" / "wireguard_private_key"
        cache_file.parent.mkdir(parents=True)
        cache_file.write_text(FAKE_WIREGUARD_KEY)
        cache_file.chmod(0o600)
        curl_log = sandbox / "curl.log"
        script = transformed_run_script(sandbox)

        write_fake_curl(bin_dir, curl_log, fail_if_called=True)
        write_options(data_dir, auth_value="", cache_enabled=False)
        result = run_script(script, bin_dir)
        assert result.returncode != 0, result.stdout + result.stderr
        assert "cached key is required" in result.stderr
        assert not curl_log.exists()


def test_direct_wireguard_key_takes_priority_over_token_and_cache() -> None:
    assert_jq_available()

    with isolated_sandbox() as sandbox:
        bin_dir = sandbox / "bin"
        bin_dir.mkdir(parents=True)
        data_dir = sandbox / "data"
        cache_file = data_dir / "nordvpn" / "wireguard_private_key"
        runtime_secret_file = sandbox / "run" / "secrets" / "wireguard_private_key"
        curl_log = sandbox / "curl.log"
        script = transformed_run_script(sandbox)

        write_fake_curl(bin_dir, curl_log, fail_if_called=True)
        write_options(
            data_dir,
            auth_value=FAKE_AUTH_VALUE,
            cache_enabled=True,
            wireguard_key=DIRECT_WIREGUARD_KEY,
        )
        result = run_script(script, bin_dir)
        assert result.returncode == 0, result.stdout + result.stderr
        assert runtime_secret_file.read_text() == DIRECT_WIREGUARD_KEY
        assert not cache_file.exists()
        assert not curl_log.exists()


if __name__ == "__main__":
    test_token_fetch_caches_key_and_cache_survives_token_removal()
    test_cache_disabled_fetches_but_does_not_persist_key()
    test_cache_disabled_does_not_reuse_existing_cached_key()
    test_direct_wireguard_key_takes_priority_over_token_and_cache()
    print("TOKEN_CACHE_SMOKE_OK")
