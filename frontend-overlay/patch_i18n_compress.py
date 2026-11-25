#!/usr/bin/env python3
"""Ensure compress toolbar strings exist in frontend locale home.json files."""
import json
import sys
from pathlib import Path

DEFAULTS = {
    "zh-CN": ("压缩", "压缩包名称："),
    "zh-TW": ("壓縮", "壓縮檔名稱："),
    "en": ("Compress", "Archive name:"),
}


def main(lang_root: str) -> None:
    root = Path(lang_root)
    for loc, (compress, name) in DEFAULTS.items():
        p = root / loc / "home.json"
        if not p.exists():
            continue
        data = json.loads(p.read_text(encoding="utf-8-sig"))
        tb = data.setdefault("toolbar", {})
        tb.setdefault("compress", compress)
        tb.setdefault("compress-name", name)
        p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"patched {p}")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "src/lang")
