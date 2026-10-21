#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for phrase in "ONE INPUT · EVERY DESKTOP" "Screen Layout" "Control state" "Open Accessibility Settings"; do
  if grep -Fq "$phrase" "$ROOT/Sources/InputMeshDesktop/InputMeshApp.swift" "$ROOT/Sources/InputMeshDesktop/DashboardView.swift"; then
    echo "Unexpected retired pointer-control copy: $phrase" >&2
    exit 1
  fi
done
grep -Fq "Handoff Guide" "$ROOT/Sources/InputMeshDesktop/DashboardView.swift"
grep -Fq "No keyboard monitoring needed" "$ROOT/Sources/InputMeshDesktop/DashboardView.swift"
grep -Fq "Workspace Handoff" "$ROOT/README.md"
echo "Workspace product copy: PASS"
