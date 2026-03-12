#!/usr/bin/env bash
# build.sh - Build and optionally deploy FS25_WorkplaceTriggers
# Usage:
#   bash build.sh            - build zip only
#   bash build.sh --deploy   - build zip and copy to mods folder

set -e

MOD_NAME="FS25_WorkplaceTriggers"
DEPLOY_DIR="C:/Users/tison/Documents/My Games/FarmingSimulator2025/mods"
OUT_ZIP="${MOD_NAME}.zip"

# Files/dirs to include in the zip
INCLUDE=(
    main.lua
    modDesc.xml
    icon_wt.dds
    icon_wt.png
    src/
    gui/
    placeables/
    translations/
)

echo "==> Building ${OUT_ZIP}..."
rm -f "${OUT_ZIP}"
zip -r "${OUT_ZIP}" "${INCLUDE[@]}"
echo "==> Built: ${OUT_ZIP} ($(du -sh "${OUT_ZIP}" | cut -f1))"

if [[ "$1" == "--deploy" ]]; then
    echo "==> Deploying to ${DEPLOY_DIR}..."
    cp "${OUT_ZIP}" "${DEPLOY_DIR}/${OUT_ZIP}"
    echo "==> Deployed."
fi
