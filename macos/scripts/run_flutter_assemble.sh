#!/bin/sh
# Wrapper to resolve FLUTTER_ROOT and run macos_assemble.sh (for CI where env may not be passed to xcodebuild).
set -e
CONFIG="${PROJECT_DIR}/Flutter/ephemeral/Flutter-Generated.xcconfig"
if [ -z "$FLUTTER_ROOT" ] && [ -f "$CONFIG" ]; then
  FLUTTER_ROOT=$(grep '^FLUTTER_ROOT=' "$CONFIG" | head -1 | cut -d= -f2- | tr -d '"' | tr -d ' ')
  export FLUTTER_ROOT
fi
if [ -z "$FLUTTER_ROOT" ]; then
  FLUTTER_ROOT=$(dirname "$(dirname "$(which flutter 2>/dev/null)")")
  export FLUTTER_ROOT
fi
if [ -z "$FLUTTER_ROOT" ] || [ ! -f "$FLUTTER_ROOT/packages/flutter_tools/bin/macos_assemble.sh" ]; then
  echo "error: FLUTTER_ROOT not set or macos_assemble.sh not found (PROJECT_DIR=$PROJECT_DIR)" 1>&2
  exit 1
fi
exec "$FLUTTER_ROOT/packages/flutter_tools/bin/macos_assemble.sh" "$@"
