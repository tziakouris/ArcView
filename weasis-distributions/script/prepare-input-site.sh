#!/bin/bash
#
# ArcView (OKYPY) deployment hook.
#
# Called by .github/workflows/build-installer.yml (and package-weasis.sh) before jpackage,
# with the payload folder (bin-dist/weasis) as first argument. It turns the stock Weasis
# payload into ArcView without touching the upstream sources, so upstream releases merge cleanly.
#
# Optional environment:
#   ARCVIEW_DICOM_NODES  content of a legacy dicomNodes.xml (the OKYPY PACS list). Kept in a
#                        GitHub secret so that internal addresses stay out of the public repo.

set -euo pipefail

PAYLOAD="${1:?payload folder (bin-dist/weasis) expected}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ArcView"
BUNDLE_ID="cy.okypy.arcview"

echo "ArcView: customizing payload in $PAYLOAD"

# 1. Product name in the UI, and a user folder (~/.arcview) separate from a stock Weasis install.
python3 - "$PAYLOAD/conf/base.json" "$APP_NAME" <<'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
changes = {
    "weasis.name": name,
    "org.osgi.framework.storage": "${felix.cache.rootdir}/.arcview/cache",
}
found = set()
for entry in doc.get("weasisPreferences", []):
    code = entry.get("code")
    if code in changes:
        entry["value"] = changes[code]
        found.add(code)
missing = set(changes) - found
if missing:
    sys.exit(f"ArcView: entries not found in {path}: {sorted(missing)}")
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"ArcView: set {sorted(found)} in {path}")
PY

# 2. OKYPY PACS list, preset for every user (they can still add their own nodes).
if [[ -n "${ARCVIEW_DICOM_NODES:-}" ]]; then
  NODES_FILE="$PAYLOAD/resources/dicomNodes.xml"
  printf '%s\n' "$ARCVIEW_DICOM_NODES" > "$NODES_FILE"
  python3 - "$NODES_FILE" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
if root.tag != "nodes":
    sys.exit("ArcView: ARCVIEW_DICOM_NODES must have <nodes> as root element")
nodes = root.findall("node")
if not nodes:
    sys.exit("ArcView: ARCVIEW_DICOM_NODES has no <node>")
for n in nodes:
    for attr in ("description", "type", "usageType", "aeTitle", "hostname", "port"):
        if not n.get(attr):
            sys.exit(f"ArcView: a node is missing the '{attr}' attribute")
print(f"ArcView: {len(nodes)} PACS preset: " + ", ".join(n.get("description") for n in nodes))
PY
else
  echo "::warning::ArcView: secret ARCVIEW_DICOM_NODES is not set, no PACS preset in this build."
fi

# 3. Installer resources: ArcView icon names and bundle id (so it never replaces a Weasis install).
RES="$SCRIPT_DIR/resources"
for pair in "macosx/Weasis.icns:macosx/$APP_NAME.icns" \
            "windows/Weasis.ico:windows/$APP_NAME.ico" \
            "windows/Weasis.properties:windows/$APP_NAME.properties"; do
  src="$RES/${pair%%:*}"
  dst="$RES/${pair##*:}"
  if [[ -f "$src" && ! -f "$dst" ]]; then
    cp "$src" "$dst"
  fi
done
PLIST="$RES/macosx/Info.plist"
if [[ -f "$PLIST" ]]; then
  sed -i.bak "s/<string>org\.weasis\.launcher<\/string>/<string>$BUNDLE_ID<\/string>/" "$PLIST"
  rm -f "$PLIST.bak"
  grep -q "$BUNDLE_ID" "$PLIST" || { echo "ArcView: bundle id not set in $PLIST"; exit 1; }
fi

echo "ArcView: payload ready"
