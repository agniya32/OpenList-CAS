#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:?frontend root required}"
OVERLAY_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "[overlay] home Compress.tsx"
mkdir -p "$ROOT/src/pages/home/toolbar"
cp -f "$OVERLAY_DIR/src/pages/home/toolbar/Compress.tsx" "$ROOT/src/pages/home/toolbar/Compress.tsx"

echo "[overlay] manage tasks Compress.tsx"
mkdir -p "$ROOT/src/pages/manage/tasks"
cp -f "$OVERLAY_DIR/src/pages/manage/tasks/Compress.tsx" "$ROOT/src/pages/manage/tasks/Compress.tsx"

API="$ROOT/src/utils/api.ts"
if ! grep -q 'fsArchiveCompress' "$API"; then
  echo "[overlay] api.ts"
  cat >> "$API" <<'EOT'

export const fsArchiveCompress = (
  src_paths: string[],
  dst_dir: string,
  archive_name: string,
  overwrite = false,
  per_item = false,
): PEmptyResp => {
  return r.post("/fs/archive/compress", {
    src_paths,
    dst_dir,
    archive_name,
    overwrite,
    per_item,
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
if "  compress:" in t:
    print("[overlay] operations.ts already")
    raise SystemExit(0)
if "TbPackage" not in t:
    t = t.replace(
        "import { TbArchive, TbFileArrowRight } from \"solid-icons/tb\"",
        "import { TbArchive, TbFileArrowRight, TbPackage } from \"solid-icons/tb\"",
    )
    if "TbPackage" not in t:
        t = 'import { TbPackage } from "solid-icons/tb"\n' + t
t = t.replace(
    'decompress: { icon: TbArchive, color: "$neutral9" },',
    'decompress: { icon: TbArchive, color: "$neutral9" },\n  compress: { icon: TbPackage, color: "$primary9" },',
    1,
)
p.write_text(t)
print("[overlay] operations.ts")
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
tb["compress-per-item"] = "Zip each selected file/folder separately"
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
fi

SM="$ROOT/src/pages/manage/sidemenu_items.tsx"
if ! grep -q 'tasks/compress' "$SM"; then
  echo "[overlay] sidemenu_items.tsx"
  python3 - "$SM" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
marker = 'component: lazy(() => import("./tasks/Decompress")),'
idx = text.find(marker)
if idx < 0:
    raise SystemExit("Decompress sidemenu component not found")
# end of this object after marker
sub = text[idx:]
end = sub.find("},")
if end < 0:
    raise SystemExit("end of decompress entry not found")
insert_at = idx + end + 2
addition = '''
      {
        title: "manage.sidemenu.compress",
        icon: TbArchive,
        to: "/@manage/tasks/compress",
        role: UserRole.GENERAL,
        component: lazy(() => import("./tasks/Compress")),
      },'''
text = text[:insert_at] + addition + text[insert_at:]
# Ensure import even when TbPackage already appears as icon: TbPackage
import_old = 'import { TbArchive, TbHash, TbSeeding } from "solid-icons/tb"'
import_new = 'import { TbArchive, TbHash, TbPackage, TbSeeding } from "solid-icons/tb"'
if import_new not in text:
    if import_old in text:
        text = text.replace(import_old, import_new, 1)
    else:
        lines = text.splitlines(True)
        out = []
        done = False
        for ln in lines:
            if (
                not done
                and ln.strip().startswith("import")
                and 'from "solid-icons/tb"' in ln
                and "TbPackage" not in ln
            ):
                if "TbArchive" in ln:
                    ln = ln.replace("TbArchive,", "TbArchive, TbPackage,")
                    if "TbPackage" not in ln:
                        ln = ln.replace("{", "{ TbPackage,", 1)
                else:
                    ln = ln.replace("{", "{ TbPackage,", 1)
                done = True
            out.append(ln)
        text = "".join(out)
        if not done:
            text = 'import { TbPackage } from "solid-icons/tb"\n' + text
path.write_text(text)
print("sidemenu ok")
PY
fi

# manage.json keys (en always present; zh after i18n unpack)
for loc in en zh-CN zh-TW; do
  MJ="$ROOT/src/lang/$loc/manage.json"
  if [ -f "$MJ" ]; then
    python3 - "$MJ" "$loc" <<'PY'
from pathlib import Path
import json, sys
p = Path(sys.argv[1])
loc = sys.argv[2]
labels = {"en": "Compress", "zh-CN": "压缩", "zh-TW": "壓縮"}
d = json.loads(p.read_text(encoding="utf-8-sig"))
sm = d.setdefault("sidemenu", {})
sm.setdefault("compress", labels.get(loc, "Compress"))
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print("manage.json", loc)
PY
  fi
done

echo "[overlay] done"
