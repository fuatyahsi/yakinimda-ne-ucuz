from __future__ import annotations

import unittest

import fetch_sources


class FetchSourcesDecodeTest(unittest.TestCase):
    def test_decodes_windows_1254_html(self) -> None:
        html = '<meta charset="windows-1254"><title>BİM Afişler</title>'
        payload = html.encode("cp1254")

        decoded = fetch_sources.decode_html_bytes(payload)

        self.assertIn("BİM Afişler", decoded)


if __name__ == "__main__":
    unittest.main()
