#!/usr/bin/env python3
"""Regression tests for push diff-base recovery after stale event payloads."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
RESOLVER = REPO_ROOT / "scripts/resolve-diff-base"
CHANGED_FILES = REPO_ROOT / "scripts/changed-files"


class ResolveDiffBaseTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.repo = Path(self.tempdir.name)
        self.git("init", "-b", "main")
        self.git("config", "user.email", "ci@example.com")
        self.git("config", "user.name", "CI")
        self.commit("README.md", "root\n", "root")
        self.root = self.git("rev-parse", "HEAD").stdout.strip()

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def git(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["git", *args], cwd=self.repo, check=True, text=True, capture_output=True
        )

    def commit(self, relative_path: str, contents: str, message: str) -> str:
        path = self.repo / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")
        self.git("add", relative_path)
        self.git("commit", "-m", message)
        return self.git("rev-parse", "HEAD").stdout.strip()

    def resolve(self, candidate: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(RESOLVER), candidate, "HEAD"],
            cwd=self.repo,
            check=True,
            text=True,
            capture_output=True,
        )

    def test_keeps_valid_ancestor(self) -> None:
        self.commit("app/lib/example.dart", "void main() {}\n", "app")
        self.assertEqual(self.resolve(self.root).stdout.strip(), self.root)

    def test_zero_before_sha_falls_back_to_parent(self) -> None:
        self.commit("app/lib/example.dart", "void main() {}\n", "app")
        result = self.resolve("0" * 40)
        self.assertEqual(result.stdout.strip(), self.root)
        self.assertIn("using HEAD^", result.stderr)

    def test_missing_before_sha_falls_back_to_parent(self) -> None:
        self.commit("app/lib/example.dart", "void main() {}\n", "app")
        result = self.resolve("deadbeef" * 5)
        self.assertEqual(result.stdout.strip(), self.root)
        self.assertIn("is unavailable", result.stderr)

    def test_diverged_before_sha_limits_selection_to_the_pushed_commit(self) -> None:
        self.git("switch", "-c", "stale")
        stale = self.commit("desktop/macos/stale.swift", "// stale\n", "stale desktop")
        self.git("switch", "main")
        self.commit("app/lib/example.dart", "void main() {}\n", "app only")

        result = self.resolve(stale)
        self.assertEqual(result.stdout.strip(), self.root)
        self.assertIn("not an ancestor", result.stderr)

        changed = subprocess.run(
            [str(CHANGED_FILES), f"{result.stdout.strip()}...HEAD"],
            cwd=self.repo,
            check=True,
            text=True,
            capture_output=True,
        ).stdout.splitlines()
        self.assertEqual(changed, ["app/lib/example.dart"])


if __name__ == "__main__":
    unittest.main()
