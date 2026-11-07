"""Syntax checks for inline JavaScript in standalone prototype pages.

The syntax check is not a browser interaction or a security audit.
"""
from pathlib import Path
import re
import shutil
import subprocess
import pytest


@pytest.mark.parametrize("page", [
    "src/api/pass_demo.html",
    "src/api/pre_evaluation_demo.html",
])
def test_inline_javascript_parses(page):
    if shutil.which("node") is None:
        pytest.skip("Node.js unavailable")
    html = Path(page).read_text(encoding="utf-8")
    scripts = re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>", html, flags=re.DOTALL | re.IGNORECASE)
    assert scripts, "Expected a local inline script in demonstrator"
    for source in scripts:
        result = subprocess.run(["node", "--check", "--input-type=commonjs"],
                                input=source, text=True, capture_output=True, check=False)
        assert result.returncode == 0, result.stderr
