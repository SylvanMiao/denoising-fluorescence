#!/bin/bash

function gdrive_download () {
  local gid="$1"
  local outfile="$2"

  if command -v gdown >/dev/null 2>&1; then
    gdown --id "$gid" -O "$outfile" --no-cookies >/dev/null 2>&1 || return 1
    return 0
  fi

  if command -v wget >/dev/null 2>&1; then
    CONFIRM=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate "https://docs.google.com/uc?export=download&id=$gid" -O- | sed -rn 's/.*confirm=([0-9A-Za-z_-]+).*/\1\n/p' | head -n1)
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$CONFIRM&id=$gid" -O "$outfile" --no-check-certificate
    rm -rf /tmp/cookies.txt
  elif command -v curl >/dev/null 2>&1; then
    curl -s -c /tmp/cookies.txt "https://docs.google.com/uc?export=download&id=$gid" -o /tmp/gd_page.html
    CONFIRM=$(sed -rn 's/.*confirm=([0-9A-Za-z_-]+).*/\1\n/p' /tmp/gd_page.html | head -n1)
    if [ -n "$CONFIRM" ]; then
      curl -L -b /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$CONFIRM&id=$gid" -o "$outfile"
    else
      # Fallback endpoint that works for many public Google Drive files.
      curl -L "https://drive.usercontent.google.com/download?id=$gid&export=download&confirm=t" -o "$outfile"
    fi
    rm -f /tmp/gd_page.html
    rm -rf /tmp/cookies.txt
  else
    echo "Error: neither wget nor curl is installed."
    return 1
  fi

  # Guardrail: if Google returns an HTML warning page, stop early.
  if [ ! -f "$outfile" ] || [ ! -s "$outfile" ]; then
    echo "Downloaded file is empty: $outfile"
    return 1
  fi
  if head -c 512 "$outfile" | tr '[:upper:]' '[:lower:]' | grep -qE '<!doctype html|<html'; then
    echo "Downloaded content is HTML instead of pretrained tar."
    echo "Tip: install gdown and rerun for reliable Google Drive download."
    return 1
  fi

  return 0
}

GDRIVE_ID=1kHJUqb-e7BARb63741DVdpg-WqCdG3z6
TAR_FILE=./experiments/pretrained.tar

mkdir -p ./experiments

echo "Downloading pretrained model..."
gdrive_download "$GDRIVE_ID" "$TAR_FILE" || { echo "Download failed for pretrained model"; exit 1; }
if [ ! -f "$TAR_FILE" ]; then
  echo "Download did not create file: ${TAR_FILE}"
  exit 1
fi

echo "Extracting files from ${TAR_FILE}..."
tar -xf "$TAR_FILE" -C ./experiments/ || { echo "Extract failed for ${TAR_FILE}"; exit 1; }
rm "$TAR_FILE"

echo "Done. Pretrained files are ready under ./experiments/."