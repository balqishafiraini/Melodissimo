#!/bin/bash
# Converts the chosen Kenney "Interface Sounds" (CC0, https://kenney.nl) from .ogg to 16-bit PCM .caf
# and drops them into the app's Data/Sound folder under the names SFX.swift expects.
# AVAudioPlayer can't read .ogg, and PCM has no encoder delay, so even the 10 ms clicks start on time.
#
# Usage: Scripts/convert_sfx.sh [path/to/kenney_interface-sounds/Audio]
# To swap a sound, change its source name below and run the script again (needs macOS: afconvert).
set -euo pipefail

SRC="${1:-kenney_interface-sounds/Audio}"
DEST="Melodissimo/Data/Sound"

# effect name       source file
declare -a MAP=(
  "sfx_perfect       glass_002"
  "sfx_miss          drop_002"
  "sfx_wrong         error_001"
  "sfx_coin          confirmation_003"
  "sfx_star          confirmation_002"
  "sfx_unlock        confirmation_004"
  "sfx_monster_hit   drop_003"
  "sfx_player_hurt   error_003"
  "sfx_tick          tick_004"
  "sfx_button        click_001"
)

for entry in "${MAP[@]}"; do
  read -r name source <<<"$entry"
  afconvert -f caff -d LEI16 "$SRC/$source.ogg" "$DEST/$name.caf"
  echo "$name.caf  <-  $source.ogg"
done
