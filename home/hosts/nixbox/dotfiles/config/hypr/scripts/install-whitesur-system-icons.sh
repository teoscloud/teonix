#!/usr/bin/env bash
# WhiteSur folders/status/devices only. No apps/ — branded marks stay hicolor.
set -euo pipefail

src=""
for cand in \
  /run/current-system/sw/share/icons/WhiteSur \
  "$HOME/.local/share/icons/WhiteSur"
do
  if [[ -d "$cand/places" && -f "$cand/index.theme" ]]; then
    src=$cand
    break
  fi
done
if [[ -z "$src" ]]; then
  echo "install-whitesur-system-icons: WhiteSur not found" >&2
  exit 0
fi

dst="${XDG_DATA_HOME:-$HOME/.local/share}/icons/WhiteSur-system"
mkdir -p "$dst"

# Drop app restyles (apps/) and Application-context prefs
skip='^(apps|apps@2x|preferences|preferences@2x)$'
shopt -s nullglob
for entry in "$src"/*; do
  base=${entry##*/}
  [[ $base == index.theme || $base == icon-theme.cache || $base == AUTHORS || $base == COPYING ]] && continue
  if [[ $base =~ $skip ]]; then
    rm -rf "$dst/$base"
    continue
  fi
  ln -sfn "$entry" "$dst/$base"
done

python3 - "$src/index.theme" "$dst/index.theme" <<'PY'
import re, sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8", errors="replace").read()
text = text.replace("Name=WhiteSur", "Name=WhiteSur-system", 1)
text = re.sub(
    r"^Comment=.*$",
    "Comment=WhiteSur places/status/devices — apps stay hicolor",
    text,
    count=1,
    flags=re.M,
)
if "Inherits=" not in text:
    text = text.replace("[Icon Theme]\n", "[Icon Theme]\nInherits=hicolor\n", 1)
else:
    text = re.sub(r"^Inherits=.*$", "Inherits=hicolor", text, count=1, flags=re.M)

def strip_dirs(line: str) -> str:
    key, _, rest = line.partition("=")
    kept = [p for p in rest.split(",") if p and not p.startswith("apps") and not p.startswith("preferences")]
    return key + "=" + ",".join(kept)

out = []
skip = False
for line in text.splitlines(True):
    if line.startswith("Directories=") or line.startswith("ScaledDirectories="):
        out.append(strip_dirs(line.rstrip("\n")) + ("\n" if line.endswith("\n") else ""))
        continue
    m = re.match(r"^\[(apps|apps@2x|preferences|preferences@2x)(/|])", line)
    if m:
        skip = True
        continue
    if skip:
        if line.startswith("[") and not line.startswith("[apps") and not line.startswith("[preferences"):
            skip = False
        else:
            continue
    if not skip:
        out.append(line)
open(dst, "w", encoding="utf-8").writelines(out)
PY

if command -v gtk-update-icon-cache >/dev/null; then
  gtk-update-icon-cache -f -t "$dst" 2>/dev/null || true
fi
echo "WhiteSur-system installed at $dst"
