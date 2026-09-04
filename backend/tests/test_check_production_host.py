"""Продакшен-хост House KG — ровно один. Скрипт должен принимать только его.

Доказывает по факту, а не по описанию: реальный процесс, реальный код
возврата — на случай, если кто-то однажды "упростит" скрипт и тихо снимет
проверку.
"""

import subprocess
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "check_production_host.sh"


def _run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["bash", str(SCRIPT), *args],
        capture_output=True,
        text=True,
        timeout=5,
    )


def test_canonical_house_production_host_is_accepted():
    result = _run("139.59.224.34")
    assert result.returncode == 0
    assert result.stdout.strip() == "139.59.224.34"


def test_unrelated_host_is_rejected():
    result = _run("147.182.243.58")
    assert result.returncode == 1
    assert result.stdout.strip() == ""
    assert "not the canonical House production host" in result.stderr


def test_ssh_alias_name_is_rejected():
    result = _run("mtl-server")
    assert result.returncode == 1
    assert "not the canonical House production host" in result.stderr


def test_missing_argument_is_rejected():
    result = _run()
    assert result.returncode == 2
