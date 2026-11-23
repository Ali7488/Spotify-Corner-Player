"""Offline tests for distro-independent Plasma 6 applet installer.

Tests use temporary homes and mocked command discovery. No Spotify,
Plasma shell, real user data, or network access is required.
"""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("spotify_corner_plasma_setup", ROOT / "install.py")
installer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def test_source_package_complete_and_owned(self):
        installer.verify_package(ROOT / "widget")
        metadata = json.loads((ROOT / "widget/metadata.json").read_text())
        self.assertEqual(metadata["KPlugin"]["Id"], installer.PLUGIN)

    def test_both_players_absent(self):
        with mock.patch.object(installer.shutil, "which", return_value=None):
            with mock.patch.object(installer, "desktop_directories", return_value=[]):
                self.assertEqual(installer.installed_players(), {})

    def test_desktop_entry_detects_native_application(self):
        with tempfile.TemporaryDirectory() as t:
            d = Path(t)
            (d / "spotify.desktop").write_text("[Desktop Entry]\nName=Spotify\n")
            with mock.patch.object(installer, "desktop_directories", return_value=[d]):
                with mock.patch.object(installer.shutil, "which", return_value=None):
                    result = installer.installed_players()
            self.assertIn("Spotify", result)
            self.assertNotIn("Spotifast", result)

    def test_flatpak_spotifast_detection(self):
        def command_check(cmd, **kwargs):
            return cmd == ["flatpak", "info", "--show-ref", "rocks.spotifast.Spotifast"]

        with mock.patch.object(installer, "desktop_directories", return_value=[]):
            with mock.patch.object(installer.shutil, "which", return_value=None):
                with mock.patch.object(installer, "available", side_effect=command_check):
                    result = installer.installed_players()
        self.assertEqual(set(result), {"Spotifast"})

    def test_plasma6_detection_and_plasma5_rejection(self):
        with mock.patch.object(installer.shutil, "which", return_value="/usr/bin/plasmashell"):
            with mock.patch.object(
                installer.subprocess, "run",
                return_value=subprocess.CompletedProcess([], 0, "plasmashell 6.6.2\n", ""),
            ):
                self.assertIn("6.6.2", installer.require_plasma6())
            with mock.patch.object(
                installer.subprocess, "run",
                return_value=subprocess.CompletedProcess([], 0, "plasmashell 5.27.9\n", ""),
            ):
                with self.assertRaises(RuntimeError):
                    installer.require_plasma6()

    def test_no_app_preflight_does_not_modify_files(self):
        with tempfile.TemporaryDirectory() as temp:
            destination = Path(temp) / "data"
            with mock.patch.dict(os.environ, {"XDG_DATA_HOME": str(destination)}):
                with mock.patch.object(installer, "require_plasma6", return_value="plasmashell 6.6.2"):
                    with mock.patch.object(installer, "installed_players", return_value={}):
                        with mock.patch.object(installer.os, "geteuid", return_value=1000):
                            with mock.patch.object(sys, "argv", ["install.py"]):
                                result = installer.main()
            self.assertEqual(result, 1)
            self.assertFalse(destination.exists())

    def test_install_update_preserves_unrelated_emerald_vinyl(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            data = home / "data"
            state = home / "state"
            original = data / "plasma/plasmoids/org.mohannad.emerald.vinyl"
            original.mkdir(parents=True)
            (original / "user.txt").write_text("keep this widget")
            with mock.patch.dict(os.environ, {
                "XDG_DATA_HOME": str(data),
                "XDG_STATE_HOME": str(state),
            }):
                self.assertIsNone(installer.install_widget())
                target = installer.installation_directory()
                self.assertTrue(target.is_dir())
                self.assertIsNone(installer.install_widget())
                self.assertEqual((original / "user.txt").read_text(), "keep this widget")
                installer.uninstall_widget()
                self.assertFalse(target.exists())
                self.assertTrue(original.is_dir())

    def test_update_replaces_owned_previous_version_with_backup(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            data = home / "data"
            state = home / "state"
            with mock.patch.dict(os.environ, {
                "XDG_DATA_HOME": str(data),
                "XDG_STATE_HOME": str(state),
            }):
                self.assertIsNone(installer.install_widget())
                target = installer.installation_directory()
                # Emulate a different *owned* version installed manually.
                manifest = json.loads((target / "metadata.json").read_text())
                manifest["KPlugin"]["Version"] = "1.3.0"
                (target / "metadata.json").write_text(json.dumps(manifest))
                previous = (target / "metadata.json").read_bytes()
                backup = installer.install_widget()
                self.assertIsNotNone(backup)
                self.assertTrue(backup.is_dir())
                self.assertEqual((backup / "metadata.json").read_bytes(), previous)
                self.assertEqual(json.loads((target / "metadata.json").read_text())["KPlugin"]["Version"], "1.4.2")
                self.assertIsNone(installer.install_widget())

    def test_refuses_symlinked_target(self):
        with tempfile.TemporaryDirectory() as temp:
            home = Path(temp)
            data = home / "data"
            target = data / "plasma/plasmoids" / installer.PLUGIN
            target.parent.mkdir(parents=True)
            fake = home / "unrelated"
            fake.mkdir()
            target.symlink_to(fake, target_is_directory=True)
            with mock.patch.dict(os.environ, {"XDG_DATA_HOME": str(data)}):
                with self.assertRaisesRegex(RuntimeError, "symlinked"):
                    installer.install_widget()
            self.assertTrue(fake.is_dir())


if __name__ == "__main__":
    unittest.main()
