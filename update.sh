#!/usr/bin/env bash
# Pull the latest microG release APKs into proprietary/ and print their package
# id, signer and requested permissions so the allowlists can be refreshed.
#
# Requires: curl, and (optional) aapt2 + keytool for the inspection step. Point
# AAPT2 at your build's host aapt2 if it is not on PATH.
set -euo pipefail

cd "$(dirname "$0")"
AAPT2="${AAPT2:-aapt2}"

fetch() { # url dest
    echo ">> $2"
    curl -fsSL -o "$2" "$1"
}

latest_asset() { # repo regex -> browser_download_url
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep -oE '"browser_download_url": *"[^"]+"' \
        | cut -d'"' -f4 | grep -iE "$2" | head -1
}

GMS_URL=$(latest_asset microg/GmsCore 'GmsCore.*\.apk$')
VND_URL=$(latest_asset microg/GmsCore 'Companion.*\.apk$|vending.*\.apk$')
GSF_URL=$(latest_asset SaeedDev94/GsfProxy 'GsfProxy.*\.apk$')

# Aurora Store: latest non-preload/-hw release from the AuroraOSS GitLab project.
AURORA_URL=$(curl -fsSL "https://gitlab.com/api/v4/projects/AuroraOSS%2FAuroraStore/releases" \
    | grep -oE '"url":"[^"]+\.apk"' | cut -d'"' -f4 \
    | grep -viE 'preload|-hw-' | head -1)

# F-Droid client is served as a stable path; the Privileged Extension has to be
# resolved to its current versionCode via the F-Droid API.
FDROID_URL="https://f-droid.org/F-Droid.apk"
FDROID_PRIV_VC=$(curl -fsSL "https://f-droid.org/api/v1/packages/org.fdroid.fdroid.privileged" \
    | grep -oE '"versionCode":[0-9]+' | cut -d: -f2 | sort -nr | head -1)
FDROID_PRIV_URL="https://f-droid.org/repo/org.fdroid.fdroid.privileged_${FDROID_PRIV_VC}.apk"

fetch "$GMS_URL" proprietary/product/priv-app/GmsCore/GmsCore.apk
fetch "$VND_URL" proprietary/product/priv-app/Phonesky/Phonesky.apk
fetch "$GSF_URL" proprietary/product/app/GsfProxy/GsfProxy.apk
fetch "$AURORA_URL"     proprietary/product/app/AuroraStore/AuroraStore.apk
fetch "$FDROID_URL"     proprietary/product/app/FDroid/FDroid.apk
fetch "$FDROID_PRIV_URL" proprietary/product/priv-app/FDroidPrivilegedExtension/FDroidPrivilegedExtension.apk

echo
for f in \
    proprietary/product/priv-app/GmsCore/GmsCore.apk \
    proprietary/product/priv-app/Phonesky/Phonesky.apk \
    proprietary/product/app/GsfProxy/GsfProxy.apk \
    proprietary/product/app/AuroraStore/AuroraStore.apk \
    proprietary/product/app/FDroid/FDroid.apk \
    proprietary/product/priv-app/FDroidPrivilegedExtension/FDroidPrivilegedExtension.apk; do
    echo "===== $f ====="
    "$AAPT2" dump badging "$f" 2>/dev/null | grep -E '^package:|targetSdk' || true
    keytool -printcert -jarfile "$f" 2>/dev/null | grep -iE 'Owner|SHA256:' | head -2 || true
    echo "-- requested permissions --"
    "$AAPT2" dump permissions "$f" 2>/dev/null | grep 'uses-permission:' \
        | sed "s/uses-permission: name='//;s/'.*//" || true
    echo
done

echo "Done. If the permission sets changed, update permissions/*.xml accordingly."
