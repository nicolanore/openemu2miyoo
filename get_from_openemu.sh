#!/bin/bash

# Script to convert OpenEmu game library artwork for Miyoo devices

# --- Configuration ---
OPEN_EMU_LIBRARY="$HOME/Library/Application Support/OpenEmu/Game Library"
DB_FILE="$OPEN_EMU_LIBRARY/Library.storedata"
IMAGES_SOURCE_DIR="$OPEN_EMU_LIBRARY/Artwork"
OUTPUT_DIR="$HOME/OpenEmu2Miyoo"

MAX_IMAGE_HEIGHT=360
MAX_IMAGE_WIDTH=250

# --- Helper Functions ---

# Check if a command exists
command_exists () {
  command -v "$1" >/dev/null 2>&1
}

# Function to map OpenEmu console names to Miyoo folder names
map_console_to_miyoo_folder() {
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
    *)
      echo "Warning: No specific Miyoo folder found for console '$console'. Using a sanitized version." >&2
      folder=$(echo "$console" | sed 's/[^a-zA-Z0-9._-]//g')
      ;;
  esac

  echo "$folder"
}

# Function to convert an image to PNG, and resize it while maintaining aspect ratio
convert_to_png_and_resize_image() {
  local image_path="$1"
  local max_width="$2"
  local max_height="$3"

  if command_exists "sips"; then
    local height=`sips --getProperty pixelHeight "$image_path" | sed -E "s/.*pixelHeight: ([0-9]+)/\1/g" | tail -1`
    local width=`sips --getProperty pixelWidth "$image_path" | sed -E "s/.*pixelWidth: ([0-9]+)/\1/g" | tail -1`
    # local width=$(sips --getProperty pixelWidth "$image_path" | awk '{print $2}')
    # local height=$(sips --getProperty pixelHeight "$image_path" | awk '{print $2}')

    if [[ -n "$width" && -n "$height" ]]; then
      local resize_needed=0

      if [[ "$width" -gt "$max_width" || "$height" -gt "$max_height" ]]; then
        resize_needed=1
      fi

      # TODO format to PNG dans tous les cas
      if [[ "$resize_needed" -eq 1 ]]; then
        echo "[INFO] Resizing image '$image_path' to a maximum of ${max_width}x${max_height}"
        local target_ratio=$(echo "$max_width / $max_height" | bc)
        local image_ratio=$(echo "$width / $height" | bc)
        if [[ $(echo "$image_ratio > $target_ratio" | bc) -eq 1 ]]; then
          sips -s format png --resampleWidth "$max_width" "$image_path" -o "$image_path" > /dev/null
        else
          sips -s format png --resampleHeight "$max_height" "$image_path" -o "$image_path" > /dev/null
        fi
      else
        # convert to PNG if not already
        sips -s format png "$image_path" -o "$image_path" > /dev/null
      fi
    else
      echo "[ERROR] Could not determine image dimensions for '$image_path'." >&2
    fi
  else
    echo "[ERROR] 'sips' command not found. Please install it to enable image resizing." >&2
  fi
}

# --- Main Script ---

# Check for required commands
if ! command_exists "sqlite3"; then
  echo "Error: 'sqlite3' command not found. Please install it." >&2
  exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# SQL query to fetch relevant data from OpenEmu
SQL_QUERY="
SELECT ZIMAGE.ZRELATIVEPATH, ZGAME.ZNAME, ZSYSTEM.ZLASTLOCALIZEDNAME
FROM ZIMAGE
LEFT JOIN ZGAME ON ZGAME.Z_PK = ZIMAGE.ZBOX
LEFT JOIN ZSYSTEM ON ZGAME.ZSYSTEM = ZSYSTEM.Z_PK;
"

# Execute the SQL query and process the results
sqlite3 "$DB_FILE" "$SQL_QUERY" | while IFS=$'|' read -r relative_path game_name system_name; do
  if [[ -n "$relative_path" && -n "$game_name" && -n "$system_name" ]]; then
    source_file="$IMAGES_SOURCE_DIR/$relative_path"
    miyoo_system_folder=$(map_console_to_miyoo_folder "$system_name")
    destination_folder="$OUTPUT_DIR/${miyoo_system_folder}/Img"
    destination_file="${destination_folder}/${game_name}.png"

    if [[ -f "$source_file" ]]; then
      echo "[INFO] Processing: '$game_name' for system '$system_name'"
      mkdir -p "$destination_folder"

      # Copy the image
      if cp "$source_file" "$destination_file"; then
        echo "[INFO] Copied '$source_file' to '$destination_file'"
        convert_to_png_and_resize_image "$destination_file" "$MAX_IMAGE_WIDTH" "$MAX_IMAGE_HEIGHT"
      else
        echo "[ERROR] Failed to copy '$source_file' to '$destination_file'" >&2
      fi
    else
      echo "[WARN] Source file not found: '$source_file'" >&2
    fi

  elif [[ -z "$relative_path" && -z "$game_name" && -z "$system_name" ]]; then
    echo "[DEBUG] Skipping empty line from sqlite3 output."
  else
    echo "[WARN] Missing data in line from sqlite3 output. Relative path: '$relative_path', Game name: '$game_name', System name: '$system_name'" >&2
  fi
done

echo "[INFO] Artwork conversion process completed."

exit 0