#!/usr/bin/env bash
# Replace ld's linker-signed signature with an ad-hoc codesign signature.
#
# `swift build -c release` on macOS leaves a linker-signed binary
# (codesign: Signature=adhoc, flags include linker-signed). On that signature
# the embedded __TEXT,__info_plist section stays unbound: codesign reports
# Identifier=<filename> and Info.plist=not bound, even when `otool -P` prints
# the usage strings. That was observed on macOS 26.5.1 arm64 and on the
# macos-15 GitHub runner before this step.
#
# `codesign --sign -` is the ad-hoc identity. It does not use a Developer ID
# or a paid team. --identifier sets the signing identifier explicitly.
#
# This script does not request Calendar or Reminders access and does not
# claim that TCC will show a prompt afterward.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <binary>" >&2
  exit 2
fi

binary=$1
identifier=${AGENDA_CODESIGN_IDENTIFIER:-cloud.rives.agenda}

if [[ ! -f "$binary" ]]; then
  echo "sign-adhoc: binary not found: $binary" >&2
  exit 1
fi

codesign --force --sign - --identifier "$identifier" "$binary"
