#!/usr/bin/env python3
"""Ensure compress strings exist in frontend locale files."""
import json
import sys
from pathlib import Path

HOME = {
    "zh-CN": {
        "compress": "压缩",
        "compress-name": "压缩包名称：",
        "compress-per-item": "每个选中的文件/文件夹单独打成 zip",
    },
    "zh-TW": {
        "compress": "壓縮",
        "compress-name": "壓縮檔名稱：",
        "compress-per-item": "每個選取的檔案/資料夾單獨壓成 zip",
    },
    "en": {
        "compress": "Compress",
        "compress-name": "Archive name:",
        "compress-per-item": "Zip each selected file/folder separately",
    },
}
MANAGE = {
    "zh-CN": "压缩",
    "zh-TW": "壓縮",
    "en": "Compress",
}


def patch_json(path: Path, updater) -> None:
    if not path.exists():
        return
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    updater(data)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"patched {path}")


def main(lang_root: str) -> None:
    root = Path(lang_root)
    for loc, keys in HOME.items():
        def upd_home(d, k=keys):
            tb = d.setdefault("toolbar", {})
            for key, val in k.items():
                tb.setdefault(key, val)

        patch_json(root / loc / "home.json", upd_home)

    for loc, label in MANAGE.items():
        def upd_manage(d, lab=label):
            sm = d.setdefault("sidemenu", {})
            sm.setdefault("compress", lab)

        patch_json(root / loc / "manage.json", upd_manage)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "src/lang")
