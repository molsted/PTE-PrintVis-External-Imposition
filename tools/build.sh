#!/usr/bin/env bash
# Local compile gate. Compiles the main app always and the test app when its
# symbols resolve. Test *execution* needs a BC server and does not happen here.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
ALC="${ALC:-$HOME/.vscode/extensions/ms-dynamics-smb.al-18.0.2732683/bin/alc.dll}"
APP="$ROOT/PTE PrintVis External Imposition"
TEST="$ROOT/PTE PrintVis External Imposition.Test"
OUT="${TMPDIR:-/tmp}/peqi-build"
mkdir -p "$OUT"

if [ ! -f "$ALC" ]; then
  echo "AL compiler not found at $ALC - set ALC to alc.dll" >&2
  exit 127
fi

fail=0

echo "== main app =="
dotnet "$ALC" /project:"$APP" /packagecachepath:"$APP/.alpackages" \
  /out:"$OUT/app.app" || fail=1

if [ -d "$TEST" ]; then
  echo "== test app =="
  mkdir -p "$TEST/.alpackages"
  cp -f "$OUT/app.app" "$TEST/.alpackages/" 2>/dev/null || true
  cp -f "$APP/.alpackages/"*.app "$TEST/.alpackages/" 2>/dev/null || true
  if ls "$TEST/.alpackages/"*"Library Assert"*.app >/dev/null 2>&1; then
    dotnet "$ALC" /project:"$TEST" /packagecachepath:"$TEST/.alpackages" \
      /out:"$OUT/test.app" || fail=1
  else
    echo "SKIPPED - Microsoft test symbols (Library Assert, Any) are not in"
    echo "$TEST/.alpackages. The test app is compiled by AL-Go CI instead."
  fi
fi

exit $fail
