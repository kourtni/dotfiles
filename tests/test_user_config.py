"""Run with: python3 -m unittest discover -s tests -v"""
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
VALID = {
    "username": "test-user",
    "homeDirectory": "/home/test-user",
    "stateVersion": "24.11",
    "git": {"name": "Test User", "email": "test@example.com"},
}


class UserConfigTests(unittest.TestCase):
    def evaluate(self, config, require_system=False):
        # JSON is embedded as a Nix string, without passing through a shell.
        encoded = json.dumps(json.dumps(config)).replace("${", r"\${")
        expression = (
            f"(import {ROOT}/lib/validate-user-config.nix "
            f"{{ requireSystem = {str(require_system).lower()}; }}) "
            f"(builtins.fromJSON {encoded})"
        )
        return subprocess.run(
            ["nix-instantiate", "--eval", "--strict", "--json", "--expr", expression],
            capture_output=True, text=True,
        )

    def test_reports_all_missing_fields(self):
        result = self.evaluate({})
        self.assertNotEqual(result.returncode, 0)
        for field in ["username", "homeDirectory", "stateVersion", "git.name", "git.email"]:
            self.assertIn(field, result.stderr)
        self.assertIn("user-config.nix.template", result.stderr)

    def test_defaults_only_optional_fields(self):
        result = self.evaluate(VALID)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), dict(VALID, uid=None, windowsUsername=""))

    def test_system_required_only_for_nixos(self):
        result = self.evaluate(VALID, require_system=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("system", result.stderr)
        result = self.evaluate(dict(VALID, system="x86_64-linux"), require_system=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_preserves_explicit_values_and_extra_fields(self):
        config = dict(VALID, uid=501, windowsUsername="windows-user", system="aarch64-darwin", extra="kept")
        result = self.evaluate(config)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), config)

    def test_reports_invalid_fields_together(self):
        config = dict(VALID, username="", homeDirectory="relative", stateVersion=24,
                      git={"name": None, "email": []}, uid="501", windowsUsername=False,
                      system="unknown")
        result = self.evaluate(config)
        self.assertNotEqual(result.returncode, 0)
        for field in ["username", "homeDirectory", "stateVersion", "git.name", "git.email",
                      "uid", "windowsUsername", "system"]:
            self.assertIn(field, result.stderr)

    def test_non_attribute_sets_get_actionable_errors(self):
        for config in [None, [], "text", 42]:
            with self.subTest(config=config):
                result = self.evaluate(config)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("attribute set", result.stderr)

    def test_malformed_git_reports_nested_fields(self):
        result = self.evaluate(dict(VALID, git="invalid"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("git.name", result.stderr)
        self.assertIn("git.email", result.stderr)

    def test_missing_nixos_fields_are_reported_together(self):
        result = self.evaluate({}, require_system=True)
        self.assertNotEqual(result.returncode, 0)
        for field in ["username", "homeDirectory", "stateVersion", "git.name", "git.email", "system"]:
            self.assertIn(field, result.stderr)


if __name__ == "__main__":
    unittest.main()
