#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

LAUNCHERS=("launcher" "launcher_rounded" "launcher_foreground" "launcher_background")
LEN=${#LAUNCHERS[@]}

mkdir -p "$SCRIPT_DIR/assets/launchers"

for ((I=0;I<$LEN;I++));
do
    L=${LAUNCHERS[$I]}

    echo "exporting assets/launchers/$L.png"

    inkscape \
        --export-filename="assets/launchers/$L.png" \
        --export-area-page \
        --export-width=1024 \
        "artwork/$L.svg"

done

# specific windows launcher
echo "exporting assets/launchers/launcher_windows.png"

inkscape \
    --export-filename="assets/launchers/launcher_windows.png" \
    --export-area-page \
    --export-width=128 \
    "artwork/launcher_windows.svg"