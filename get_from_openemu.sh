#!/bin/bash

# Database connection details (replace with your actual values)
OPEN_EMU_LIBRARY="$HOME/Library/Application Support/OpenEmu/Game Library"
DB_FILE="$OPEN_EMU_LIBRARY/Library.storedata"  # Path to your SQLite database
IMAGES_SOURCE_DIR="$OPEN_EMU_LIBRARY/Artwork"
OUTPUT_DIR="$HOME/OpenEmu2Miyoo"

MAX_IMAGE_HEIGHT=360
MAX_IMAGE_WIDTH=250

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

find_console_folder() {
  local console="$1"
  local folder=""

  case "$console" in
    "Arcade") folder="ARCADE" ;;
    "Atari 2600") folder="ATARI" ;;
    "Atari 5200") folder="FIFTYTWOHUNDRED" ;;
    "Atari 7800") folder="SEVENTYEIGHTHUNDRED" ;;
    "Atari Lynx") folder="LYNX" ;;
    "ColecoVision") folder="COLECO" ;;
    "Famicom Disk System") folder="FDS" ;;
    "Game Boy Advance") folder="GBA" ;;
    "Game Boy") folder="GB" ;;
    "Game Gear") folder="GG" ;;
    "Intellivision") folder="INTELLIVISION" ;;
    "NeoGeo Pocket") folder="NGP" ;;
    "Nintendo (NES)") folder="FC" ;;
    "Nintendo DS") folder="NDS" ;;
    "SG-1000") folder="SEGASGONE" ;;
    "Sega 32X") folder="THIRTYTWOX" ;;
    "Sega Master System") folder="MS" ;;
    "Sega Mega Drive") folder="MD" ;;
    "Sony PlayStation") folder="PS" ;;
    "Super Nintendo (SNES)") folder="SFC" ;;
    "TurboGrafx-16") folder="PCE" ;;
    "Vectrex") folder="VECTREX" ;;
    "Virtual Boy") folder="VB" ;;
    "WonderSwan") folder="WS" ;;
    *) echo "Error: Folder not found for console '$console'" >&2
       echo "$1" | sed 's/[^a-zA-Z0-9._-]//g' # keep only letters, numbers, dots, underscores and hyphens
  esac

  if [ -n "$folder" ]; then
    echo "$folder"
  fi
}

# SQL query
SQL_QUERY="
SELECT ZIMAGE.ZRELATIVEPATH, ZGAME.ZNAME, ZSYSTEM.ZLASTLOCALIZEDNAME
FROM ZIMAGE
LEFT JOIN ZGAME ON ZGAME.Z_PK = ZIMAGE.ZBOX
LEFT JOIN ZSYSTEM ON ZGAME.ZSYSTEM = ZSYSTEM.Z_PK;
"

# Execute the SQL query and process the results
sqlite3 "$DB_FILE" "$SQL_QUERY" | while IFS=$'|' read -r RELATIVE_PATH GAME_NAME SYSTEM_NAME; do
  if [[ -n "$RELATIVE_PATH" && -n "$GAME_NAME" && -n "$SYSTEM_NAME" ]]; then
    SOURCE_FILE="$IMAGES_SOURCE_DIR/$RELATIVE_PATH"
    SYSTEM_NAME_MAPPED_FOR_MIYOO=$(find_console_folder "$SYSTEM_NAME")
    DESTINATION_FOLDER="$OUTPUT_DIR/${SYSTEM_NAME_MAPPED_FOR_MIYOO}/Img"
    DESTINATION_FILE="${DESTINATION_FOLDER}/${GAME_NAME}.png"

    if [[ -f "$SOURCE_FILE" ]]; then
      echo "[INFO] Copy $SOURCE_FILE to $DESTINATION_FILE"
      mkdir -p $DESTINATION_FOLDER
      cp "$SOURCE_FILE" "$DESTINATION_FILE"

      echo "[INFO] Resize the image $DESTINATION_FILE to a maximum of ${MAX_IMAGE_WIDTH}x${MAX_IMAGE_HEIGHT}"
      # sips -s format png -Z 250 "$DESTINATION_FILE" -o "$DESTINATION_FILE" > /dev/null
      height=`sips --getProperty pixelHeight "$DESTINATION_FILE" | sed -E "s/.*pixelHeight: ([0-9]+)/\1/g" | tail -1`
      if [[ $height -gt $MAX_IMAGE_HEIGHT ]]; then
          sips -s format png --resampleHeight $MAX_IMAGE_HEIGHT "$DESTINATION_FILE" -o "$DESTINATION_FILE" > /dev/null
      fi
      width=`sips --getProperty pixelWidth "$DESTINATION_FILE" | sed -E "s/.*pixelWidth: ([0-9]+)/\1/g" | tail -1`
      if [[ $width -gt $MAX_IMAGE_WIDTH ]]; then
          sips -s format png --resampleWidth $MAX_IMAGE_WIDTH "$DESTINATION_FILE" -o "$DESTINATION_FILE" > /dev/null
      fi
    else
      echo "[WARN] Source file not found: $SOURCE_FILE"
    fi

  else
    if [[ -z "$RELATIVE_PATH" && -z "$GAME_NAME" && -z "$SYSTEM_NAME" ]]; then
      echo "[WARN] Empty line from sqlite3 output. Skipping."
    else
      echo "[WARN] Missing data in line from sqlite3 output. Relative path: $RELATIVE_PATH, Game name: $GAME_NAME, System name: $SYSTEM_NAME"
    fi
  fi
done