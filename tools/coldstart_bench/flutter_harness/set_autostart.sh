#!/bin/sh
# Flips RufletRuntimeAutostart in the harness Info.plist. Autostart and a Dart
# start() are mutually exclusive: the VM boots once per process.
PLIST="$1"; VALUE="$2"
/usr/libexec/PlistBuddy -c "Delete :RufletRuntimeAutostart" "$PLIST" 2>/dev/null
/usr/libexec/PlistBuddy -c "Add :RufletRuntimeAutostart bool $VALUE" "$PLIST"
