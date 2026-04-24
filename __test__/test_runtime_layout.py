"""Tests for the new sh/config runtime layout."""

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "py"))

from wsha.config import get_app_env, resolve_app_config_dir


def test_resolve_app_config_dir_prefers_sh_config(tmp_path: Path):
    app_home = tmp_path / "app"
    (app_home / "sh" / "config").mkdir(parents=True)
    (app_home / "config").mkdir()

    assert resolve_app_config_dir(str(app_home)) == app_home / "sh" / "config"


def test_get_app_env_defaults_to_sh_config(monkeypatch):
    monkeypatch.setenv("APP_HOME", "/tmp/app")
    monkeypatch.delenv("APP_CONFIG", raising=False)
    env = get_app_env()

    assert env["APP_SH"] == "/tmp/app/sh"
    assert env["APP_CONFIG"] == "/tmp/app/sh/config"
