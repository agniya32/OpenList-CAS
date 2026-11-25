#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:?frontend root required}"
OVERLAY_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[overlay] Compress.tsx"
mkdir -p "$ROOT/src/pages/home/toolbar"
cp -f "$OVERLAY_DIR/src/pages/home/toolbar/Compress.tsx" "$ROOT/src/pages/home/toolbar/Compress.tsx"

API="$ROOT/src/utils/api.ts"
if ! grep -q 'fsArchiveCompress' "$API"; then
  echo "[overlay] api.ts"
  cat >> "$API" <<'EOT'

export const fsArchiveCompress = (
  src_paths: string[],
  dst_dir: string,
  archive_name: string,
  overwrite = false,
): PEmptyResp => {
  return r.post("/fs/archive/compress", {
    src_paths,
    dst_dir,
    archive_name,
    overwrite,
  })
}
EOT
fi

OPS="$ROOT/src/pages/home/toolbar/operations.ts"
python3 - "$OPS" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
t = p.read_text()
if "  compress:" not in t:
    if "TbPackage" not in t:
        t = t.replace(
            'from "solid-icons/tb"',
            'from "solid-icons/tb"',
            1,
        )
        # add import line after last solid-icons/tb import block
        lines = t.splitlines(True)
        out = []
        added_imp = False
        for i, line in enumerate(lines):
            out.append(line)
            if (not added_imp) and 'from "solid-icons/tb"' in line and "TbPackage" not in line:
                if "TbArchive" in line:
                    out[-1] = line.replace("TbArchive, TbFileArrowRight", "TbArchive, TbFileArrowRight, TbPackage")
                    if "TbPackage" not in out[-1]:
                        out[-1] = line.rstrip("\n") + ""
                        # fallback separate import
                        out.append('import { TbPackage } from "solid-icons/tb"\n')
                    added_imp = True
                else:
                    out.append('import { TbPackage } from "solid-icons/tb"\n')
                    added_imp = True
        t = "".join(out)
        if "TbPackage" not in t:
            t = 'import { TbPackage } from "solid-icons/tb"\n' + t
    t = t.replace(
        'decompress: { icon: TbArchive, color: "$neutral9" },',
        'decompress: { icon: TbArchive, color: "$neutral9" },\n  compress: { icon: TbPackage, color: "$primary9" },',
        1,
    )
    p.write_text(t)
    print("[overlay] operations.ts")
else:
    print("[overlay] operations.ts already")
PY

TB="$ROOT/src/pages/home/toolbar/Toolbar.tsx"
if ! grep -q 'Compress' "$TB"; then
  echo "[overlay] Toolbar.tsx"
  sed -i 's/import { Decompress } from ".\/Decompress"/import { Decompress } from ".\/Decompress"\nimport { Compress } from ".\/Compress"/' "$TB"
  sed -i 's/<Decompress \/>/<Decompress \/>\n      <Compress \/>/' "$TB"
fi

CTX="$ROOT/src/pages/home/folder/context-menu.tsx"
if ! grep -q 'name="compress"' "$CTX"; then
  echo "[overlay] context-menu.tsx"
  python3 - "$CTX" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
needle = '''      <Item
        hidden={() => {
          return (
            isShare() ||
            !userCan("decompress") ||
            !objStore.write ||
            selectedObjs().some((o) => o.is_dir) ||
            selectedObjs().some((o) => !isArchive(o.name))
          )
        }}
        onClick={() => {
          bus.emit("tool", "decompress")
        }}
      >
        <ItemContent name="decompress" />
      </Item>'''
insert = needle + '''
      <Item
        hidden={() => {
          return (
            isShare() ||
            !userCan("write_content") ||
            !objStore.write ||
            !haveSelected()
          )
        }}
        onClick={() => {
          bus.emit("tool", "compress")
        }}
      >
        <ItemContent name="compress" />
      </Item>'''
if needle not in text:
    raise SystemExit("decompress block not found in context-menu")
path.write_text(text.replace(needle, insert, 1))
print("context-menu ok")
PY
fi

CENTER="$ROOT/src/pages/home/toolbar/Center.tsx"
if [ -f "$CENTER" ] && ! grep -q '"compress"' "$CENTER"; then
  echo "[overlay] Center.tsx"
  sed -i 's/\["rename", "move", "copy", "delete", "decompress"\]/["rename", "move", "copy", "delete", "decompress", "compress"]/' "$CENTER"
fi

EN="$ROOT/src/lang/en/home.json"
if [ -f "$EN" ] && ! grep -q '"compress"' "$EN"; then
  echo "[overlay] en/home.json"
  python3 - "$EN" <<'PY'
from pathlib import Path
import json, sys
p = Path(sys.argv[1])
d = json.loads(p.read_text(encoding="utf-8-sig"))
tb = d.setdefault("toolbar", {})
tb["compress"] = "Compress"
tb["compress-name"] = "Archive name:"
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
fi

echo "[overlay] done"
