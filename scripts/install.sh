#!/bin/bash
# Bundle, copy to /Applications, launch.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/bundle.sh
pkill -x Franco 2>/dev/null || true
rm -rf /Applications/Franco.app
cp -R build/Franco.app /Applications/Franco.app
open /Applications/Franco.app
echo "Franco installed at /Applications/Franco.app and launched. Grant Accessibility when prompted."
