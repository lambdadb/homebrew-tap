#!/usr/bin/env python3
"""Keep the CI metadata token out of release downloads and redirects."""

import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.request

spec = importlib.util.spec_from_file_location(
    "verifier", Path(__file__).with_name("verify-migration-release.py"))
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class DownloadTests(unittest.TestCase):
    def request_for(self, url, token="test-token"):
        with tempfile.TemporaryDirectory() as temp, \
                patch.dict(os.environ, {"GH_TOKEN": token}), \
                patch.object(verifier.urllib.request, "urlopen", return_value=io.BytesIO(b"payload")) as opened:
            destination = Path(temp) / "download"
            verifier.download(url, destination)
            self.assertEqual(destination.read_bytes(), b"payload")
            return opened.call_args.args[0]

    def test_metadata_authentication(self):
        request = self.request_for("https://api.github.com/repos/lambdadb/lambdadb-migration/releases/tags/v0.1.6")
        self.assertEqual(request.get_header("Authorization"), "Bearer test-token")

    def test_unauthenticated_local_use(self):
        request = self.request_for("https://api.github.com/repos/lambdadb/lambdadb-migration/releases/tags/v0.1.6", "")
        self.assertFalse(request.has_header("Authorization"))

    def test_downloads_and_other_origins_are_unauthenticated(self):
        for url in (
            "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.6/checksums.txt",
            "https://github.com/lambdadb/lambdadb-migration/releases/download/v0.1.6/lambdadb-migration_0.1.6_darwin_arm64.tar.gz",
            "https://release-assets.githubusercontent.com/example",
            "https://api.github.com.example.invalid/metadata",
            "http://api.github.com/metadata",
        ):
            with self.subTest(url=url):
                self.assertFalse(self.request_for(url).has_header("Authorization"))

    def test_redirect_does_not_forward_token(self):
        request = self.request_for("https://api.github.com/repos/lambdadb/lambdadb-migration/releases/tags/v0.1.6")
        redirected = urllib.request.HTTPRedirectHandler().redirect_request(
            request, None, 302, "Found", {}, "https://example.invalid/redirect")
        self.assertFalse(redirected.has_header("Authorization"))


if __name__ == "__main__":
    unittest.main()
