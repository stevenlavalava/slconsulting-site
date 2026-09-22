#!/bin/bash
# wabridge installer (Mac) — swaps a PAIA's WhatsApp bridge for the 2026-09-15 build
# (whatsmeow v0.0.0-20260914150520) after WhatsApp's 405 "Client outdated" cut-off.
# Run:  curl -fsSL https://stevenlava.com/upgrades/wabridge/install.sh | bash
# Safe to re-run. Keeps the pairing (store/ untouched). Backs up the old binary.
set -u
BASE="${WABRIDGE_BASE:-https://stevenlava.com/upgrades/wabridge}"
STAMP="20260922"
SHA_ARM64="40851ac966e139d09bee7ee394a8ac11132fdd60b53e1af8d05f67cf67e5a770"
SHA_AMD64="e9814a01ea5121a27776b54aeb084ebdd44a50c981b3c013d870257cb6368985"
say(){ printf '%s\n' "$*"; }
die(){ say "FAILED: $*"; exit 1; }

# 1. Architecture
ARCH=$(uname -m)
case "$ARCH" in
  arm64) BIN="whatsapp-bridge-darwin-arm64"; WANT="$SHA_ARM64" ;;
  x86_64) BIN="whatsapp-bridge-darwin-amd64"; WANT="$SHA_AMD64" ;;
  *) die "unknown architecture $ARCH" ;;
esac

# 2. Find the current bridge binary: running process → LaunchAgent plist → known folders
TARGET=""
PID=$(pgrep -f 'whatsapp-bridge' | head -1 || true)
if [ -n "$PID" ]; then
  TARGET=$(lsof -a -p "$PID" -d txt -Fn 2>/dev/null | sed -n 's/^n//p' | grep -i 'whatsapp-bridge' | head -1 || true)
fi
PLIST=""
for p in "$HOME"/Library/LaunchAgents/*.plist; do
  [ -f "$p" ] || continue
  if grep -qi 'whatsapp-bridge' "$p"; then PLIST="$p"; break; fi
done
if [ -z "$TARGET" ] && [ -n "$PLIST" ]; then
  TARGET=$(grep -o '[^ <>"]*whatsapp-bridge[^ <>"]*' "$PLIST" | grep -v '\.log$\|\.plist$\|\.py$' | head -1 || true)
fi
if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
  for c in "$HOME"/Library/*/whatsapp-bridge/whatsapp-bridge /Users/Shared/*/bin/whatsapp-bridge "$HOME"/.local/bin/whatsapp-bridge-daemon "$HOME"/Desktop/*/modules/whatsapp-bridge/whatsapp-bridge "$HOME"/*/modules/whatsapp-bridge/whatsapp-bridge; do
    if [ -f "$c" ]; then TARGET="$c"; break; fi
  done
fi
[ -n "$TARGET" ] && [ -f "$TARGET" ] || die "could not find the bridge binary. Tell your owner's assistant (Bilbo) where it lives."
file "$TARGET" | grep -q 'Mach-O' || die "$TARGET is not a Mach-O binary"
say "bridge binary: $TARGET"
LABEL=""
if [ -n "$PLIST" ]; then
  LABEL=$(basename "$PLIST" .plist)
  say "LaunchAgent: $LABEL"
else
  say "no LaunchAgent found — will restart the binary the way it was running (foreground); set up a LaunchAgent afterwards"
fi
LOG=""
[ -n "$PLIST" ] && LOG=$(grep -A1 StandardOutPath "$PLIST" | grep -o '<string>.*</string>' | sed 's/<\/*string>//g' | head -1)

# 3. Download the new binary
TMP=$(mktemp -d)
say "downloading $BIN ..."
curl -fsSL --retry 3 -o "$TMP/$BIN" "$BASE/$BIN" || die "download failed"
GOT=$(shasum -a 256 "$TMP/$BIN" | cut -d" " -f1)
[ "$GOT" = "$WANT" ] || die "SHA256 mismatch on the downloaded binary (got $GOT, expected $WANT) — nothing changed"
say "sha256 verified: $GOT"
chmod +x "$TMP/$BIN"
file "$TMP/$BIN" | grep -q 'Mach-O' || die "downloaded file is not a Mach-O binary"
[ "$ARCH" = arm64 ] && codesign -s - "$TMP/$BIN" 2>/dev/null
xattr -d com.apple.quarantine "$TMP/$BIN" 2>/dev/null || true

# 4. Stop everything, swap, start one
if [ -n "$LABEL" ]; then launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true; fi
pkill -9 -f 'whatsapp-bridge' 2>/dev/null || true
sleep 2
if pgrep -f 'whatsapp-bridge' >/dev/null; then die "a bridge process is still running; stop it and re-run"; fi
if [ -f "$TARGET.bak-$STAMP" ]; then say "backup already exists, keeping it"; else cp "$TARGET" "$TARGET.bak-$STAMP" || die "backup failed"; fi
cp "$TMP/$BIN" "$TARGET.new" && mv "$TARGET.new" "$TARGET" || die "swap failed"
chmod +x "$TARGET"
say "swapped (backup at $TARGET.bak-$STAMP)"
LOGSTART=0
[ -n "$LOG" ] && [ -f "$LOG" ] && LOGSTART=$(wc -c < "$LOG" | tr -d " ")
if [ -n "$PLIST" ]; then
  launchctl bootstrap "gui/$(id -u)" "$PLIST" || die "launchctl bootstrap failed"
  say "service started"
else
  say "start the bridge the way it normally runs, then check its log for 'Connected to WhatsApp'"; exit 0
fi

# 5. Verify
say "waiting for 'Connected to WhatsApp' ..."
for i in $(seq 1 45); do
  sleep 2
  NEW=""; [ -n "$LOG" ] && [ -f "$LOG" ] && NEW=$(tail -c +$((LOGSTART+1)) "$LOG")
  if printf '%s' "$NEW" | grep -q 'Connected to WhatsApp'; then
    if printf '%s' "$NEW" | tail -50 | grep -q 'Client outdated'; then continue; fi
    say "OK: connected (pid $(pgrep -f whatsapp-bridge | head -1)). Pairing kept. Messages missed while down will backfill on their own."
    say "wabridge $STAMP installed"; exit 0
  fi
  if printf '%s' "$NEW" | grep -q 'Device logged out'; then
    say "swapped, but WhatsApp has unlinked this device — the one case that needs a QR scan. Run the pairing step from your WhatsApp note."; exit 2
  fi
done
say "swapped and started, but no 'Connected to WhatsApp' seen yet (log: ${LOG:-unknown}). Check the log in a minute; if it shows 405 again, tell Bilbo."; exit 3
