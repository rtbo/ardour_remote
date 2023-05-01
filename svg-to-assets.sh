#!/bin/bash

# https://gist.github.com/deepankarb/e69de4373ebd7067e0fc

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SVG_FILE=
BASE_SIZE=24
ASSET_PATH=

while getopts "i:b:a:" opt; do
    case "${opt}" in
        i)
            SVG_FILE="${OPTARG}"
            ;;
        b)
            BASE_SIZE=${OPTARG}
            ;;
        a)
            ASSET_PATH="${OPTARG}"
            ;;
    esac
done

if [[ -z "$SVG_FILE" ]];
then
	echo "No SVG file specified. Exiting."
	exit 1
fi

issvg=$(file "$SVG_FILE")
echo $issvg | grep -q SVG
if [[ $? -ne 0 ]];
then
	echo "Invalid SVG file. Exiting."
	exit 2
fi

if [[ -z "$ASSET_PATH" ]];
then
    filename=$(basename -- "$SVG_FILE")
    ASSET_PATH="${filename%.*}"
fi

ASSETS_DIR="$SCRIPT_DIR/assets"
ASSET_DIR=$(dirname -- "$ASSET_PATH")
ASSET_NAME=$(basename -- "$ASSET_PATH")
BASE_FILE="$ASSETS_DIR/$ASSET_DIR/$ASSET_NAME.png"
mkdir -p "$ASSETS_DIR/$ASSET_DIR"

echo "exporting $BASE_FILE (${BASE_SIZE}px)"

inkscape \
    --export-filename="$BASE_FILE" \
    --export-area-page \
    --export-width=$BASE_SIZE \
    $SVG_FILE

SIZES=("1.5" "2.0" "3.0" "4.0")
len_sz=${#SIZES[@]}

for ((ii=0;ii<$len_sz;ii++));
do
    SZ=${SIZES[$ii]}
    FILE="$ASSETS_DIR/$ASSET_DIR/${SZ}x/$ASSET_NAME.png"
    WIDTH=$( echo "$SZ * $BASE_SIZE / 1" | bc )
    mkdir -p "$ASSETS_DIR/$ASSET_DIR/${SZ}x"

    echo "exporting $FILE (${WIDTH}px)"

    inkscape \
        --export-filename="$FILE" \
        --export-area-page \
        --export-width=$WIDTH \
        $SVG_FILE
done
