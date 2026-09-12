#!/usr/bin/env bash
# ==============================================================================
# OCR Screen Snippet to Clipboard
# Select region with slurp -> capture with grim -> OCR with tesseract -> wl-copy
# ==============================================================================

# 1. Select screen region using slurp
GEOM=$(slurp -b "#00000066" -c "#89b4fa" -w 2 2>/dev/null)
[ -z "$GEOM" ] && exit 0

# 2. Capture and OCR directly via in-memory pipe
TEXT=$(grim -g "$GEOM" -t png - 2>/dev/null | tesseract stdin stdout -l eng+ind 2>/dev/null)

# 3. Clean leading/trailing blank lines
CLEANED_TEXT=$(echo "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

# 4. Copy to clipboard and notify
if [ -n "$CLEANED_TEXT" ]; then
    echo -n "$CLEANED_TEXT" | wl-copy
    PREVIEW="${CLEANED_TEXT:0:60}"
    [ ${#CLEANED_TEXT} -gt 60 ] && PREVIEW="${PREVIEW}..."
    notify-send -a "OCR" -i edit-find "Teks Disalin ke Clipboard" "$PREVIEW"
else
    notify-send -a "OCR" -u low -i dialog-warning "OCR Gagal" "Tidak ada teks yang terdeteksi."
fi
