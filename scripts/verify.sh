#!/usr/bin/env bash
set -euo pipefail
swift --version
swift build
swift test
