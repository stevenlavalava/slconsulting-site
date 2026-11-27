#!/bin/bash
# Connect Google Drive (Sheets, Docs, Slides) to your PAIA — one Google sign-in per account.
# Uses Google's own sign-in (gcloud). Nothing is stored except Google's own login
# token on THIS computer. Remove anytime: myaccount.google.com/permissions
# Usage:  bash connect.command you@gmail.com     (or run it and type the address)
SDK="$HOME/.local/google-cloud-sdk"
export PATH="$SDK/bin:$HOME/.local/bin:$PATH"
if ! command -v gcloud >/dev/null 2>&1; then
  echo "Installing Google's sign-in tool (one time, a few minutes)..."
  ARCH=$(uname -m); [ "$ARCH" = "arm64" ] && PKG=darwin-arm || PKG=darwin-x86_64
  mkdir -p "$HOME/.local" && cd "$HOME/.local" || exit 1
  curl -fL -o gcloud.tar.gz "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-$PKG.tar.gz" \
    && tar -xzf gcloud.tar.gz && rm -f gcloud.tar.gz \
    && "$SDK/install.sh" --quiet --usage-reporting=false --path-update=false --command-completion=false
  command -v gcloud >/dev/null 2>&1 || { echo "STOP: could not install Google's sign-in tool (gcloud). Tell Steven."; exit 1; }
fi
a="$1"
[ -z "$a" ] && read -r -p "Google address to connect: " a
[ -z "$a" ] && { echo "No address given."; exit 1; }
echo; echo "=== Google Drive / Sheets / Docs connection: $a ==="
if gcloud auth list --format="value(account)" 2>/dev/null | grep -qx "$a"; then
  echo "Already connected."
else
  echo "A browser window opens. Pick  $a , tick every box, press Allow."
  gcloud auth login "$a" --enable-gdrive-access --brief || echo "(not connected — tell Steven what the browser said)"
fi
echo; echo "Connected accounts:"; gcloud auth list --format="value(account)"
echo; echo "=== Done. You can close this window."
