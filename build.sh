#!/usr/bin/env bash
#
# Build helper for the Ultimate Realism Framework (Linux / macOS / WSL / CI).
# The game lives on Windows, but the project compiles anywhere the .NET SDK runs,
# which makes CI and code review possible without a GTA V install.
#
#   ./build.sh                     build Release
#   ./build.sh Debug               build Debug
#   ./build.sh Release --validate  also run the config/code consistency gate
#
set -euo pipefail

CONFIGURATION="${1:-Release}"
shift || true

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$ROOT/src/UltimateRealism/UltimateRealism.csproj"

echo "Ultimate Realism Framework - build"
echo "  root          : $ROOT"
echo "  configuration : $CONFIGURATION"
echo

if [[ "${*:-}" == *"--validate"* || "${VALIDATE:-0}" == "1" ]]; then
  echo "[1/3] Validating configuration against code..."
  if command -v python3 >/dev/null 2>&1; then
    python3 "$ROOT/tools/validate_config.py"
  else
    echo "      python3 not found; skipping validator."
  fi
else
  echo "[1/3] Validator skipped (pass --validate)."
fi

echo "[2/3] Building..."
dotnet build "$PROJECT" -c "$CONFIGURATION" --nologo

OUT="$ROOT/src/UltimateRealism/bin/$CONFIGURATION"
echo
echo "[3/3] Artefacts in $OUT:"
ls -la "$OUT" | sed 's/^/      /'

echo
echo "Copy UltimateRealism.dll (and, on a fresh install, UltimateRealism.ini)"
echo "into your GTA V 'scripts' folder."
