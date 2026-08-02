#!/usr/bin/env bash
# Pull the latest microG release APKs into proprietary/ and print their package
# id, signer and requested permissions so the allowlists can be refreshed.
#
# Requires: curl, jq, unzip, and (optional) aapt2 + keytool for the inspection
# step. Point AAPT2 at your build's host aapt2 if it is not on PATH.
set -euo pipefail

cd "$(dirname "$0")"
AAPT2="${AAPT2:-aapt2}"

# Pinned microG release. GmsCore pre-releases are never returned by GitHub's
# "latest" endpoint, so reaching one requires naming its tag. Set GMS_TAG=latest
# to track the newest *stable* release instead.
GMS_TAG="${GMS_TAG:-v0.3.16.252432}"

fetch() { # url dest
    echo ">> $2"
    curl -fsSL -o "$2" "$1"
}

release_json() { # repo [tag] -> release object on stdout
    local repo=$1 tag=${2:-latest}
    if [ "$tag" = latest ]; then
        curl -fsSL "https://api.github.com/repos/$repo/releases/latest"
    else
        curl -fsSL "https://api.github.com/repos/$repo/releases/tags/$tag"
    fi
}

# Match on the asset *name*, never on browser_download_url: that URL always
# contains the repo name (".../microg/GmsCore/releases/..."), so a loose pattern
# like 'GmsCore.*\.apk$' matches every asset and picks whichever the API happens
# to list first. Anchoring to the name with a trailing [0-9]+\.apk$ also excludes
# the -hw (Huawei, hms maps flavor - no libmapbox-gl.so) and -user (unprivileged
# dev preview, different applicationId) builds by construction.
asset_url() { # release-json regex -> browser_download_url
    printf '%s' "$1" | jq -r --arg re "$2" \
        '.assets[] | select(.name | test($re)) | .browser_download_url'
}

require_url() { # url label
    [ -n "$1" ] || { echo "error: no release asset matched $2" >&2; exit 1; }
}

GMS_RELEASE=$(release_json microg/GmsCore "$GMS_TAG")
GMS_URL=$(asset_url "$GMS_RELEASE" '^com\.google\.android\.gms-[0-9]+\.apk$')
VND_URL=$(asset_url "$GMS_RELEASE" '^com\.android\.vending-[0-9]+\.apk$')
GSF_URL=$(asset_url "$(release_json SaeedDev94/GsfProxy)" '^GsfProxy.*\.apk$')

require_url "$GMS_URL" "GmsCore in microg/GmsCore@$GMS_TAG"
require_url "$VND_URL" "Companion in microg/GmsCore@$GMS_TAG"
require_url "$GSF_URL" "GsfProxy"

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
# GmsCore ships extractNativeLibs=true but is imported preprocessed, so Soong
# never unpacks its JNI libs. Re-extract them into the app's lib dir so
# nativeLibraryDir is populated at build time (common.mk copies them in). Without
# this, apps that load a GmsCore library - e.g. Google Maps loading Cronet -
# crash with UnsatisfiedLinkError. arm64 only (the target is arm64-v8a).
#
# Extract to a temp dir and only swap it in once the libs are actually there:
# common.mk picks these up with $(wildcard), so an empty dir silently ships a
# build with no JNI libs and no error. Replace the dir wholesale rather than
# unzipping over it, so a lib renamed upstream leaves no stale copy behind.
GMS_LIBDIR=proprietary/product/priv-app/GmsCore/lib/arm64
GMS_LIBTMP=$(mktemp -d)
trap 'rm -rf "$GMS_LIBTMP"' EXIT
unzip -o -j proprietary/product/priv-app/GmsCore/GmsCore.apk 'lib/arm64-v8a/*.so' -d "$GMS_LIBTMP"
libs=$(find "$GMS_LIBTMP" -name '*.so' | wc -l)
[ "$libs" -ge 6 ] || { echo "error: only $libs arm64-v8a libs in GmsCore.apk (expected >= 6)" >&2; exit 1; }
rm -rf "$GMS_LIBDIR" && mkdir -p "$GMS_LIBDIR" && mv "$GMS_LIBTMP"/*.so "$GMS_LIBDIR/"

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
