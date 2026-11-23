## vendor_microG

Prebuilt [microG](https://microg.org) integration for LineageOS-style device
trees: GmsCore, the Companion / Play Store proxy (Phonesky) and GsfProxy, plus
Aurora Store and F-Droid, wired as system apps with the permission allowlists
they need.

### Use

In your `device.mk` (or a common device makefile):

    $(call inherit-product, vendor/microG/common.mk)

Rebuild. After first boot, open **microG Settings → Self-Check** — on a ROM
with signature spoofing everything should be green.

### What ships

| Module | Package | Privileged | Upstream |
|---|---|---|---|
| GmsCore | `com.google.android.gms` | yes | [microg/GmsCore](https://github.com/microg/GmsCore/releases) |
| Phonesky (Companion) | `com.android.vending` | yes | same releases |
| GsfProxy | `com.google.android.gsf` | no | [SaeedDev94/GsfProxy](https://github.com/SaeedDev94/GsfProxy/releases) (fork targeting SDK 36) |
| Aurora Store | `com.aurora.store` | no | [AuroraOSS/AuroraStore](https://gitlab.com/AuroraOSS/AuroraStore/-/releases) |
| F-Droid | `org.fdroid.fdroid` | no | [f-droid.org](https://f-droid.org/F-Droid.apk) |

APKs are **presigned — do not resign them**: the microG signing key is what the
framework spoof matches. GmsCore's JNI libs are pre-extracted into
`proprietary/product/priv-app/GmsCore/lib/arm64/` (apps such as Google Maps
`dlopen()` `libcronet` from there); `update.sh` refreshes them.

### Signature-spoofing requirement

microG only works when the framework recognizes the microG signature as
Google's. crDroid ships that on every variant; LineageOS/AOSP gate it to
debuggable builds, so this repo carries
`patches/frameworks/base/0001-Allow-microG-signature-spoofing-on-user-builds.patch`
(drops the `isDebuggable()` gate) and `vendorsetup.sh` applies it automatically
when `build/envsetup.sh` is sourced — a no-op on userdebug/eng, skipped or
harmless on crDroid. `repo sync` discards it; re-source envsetup and check for
`FAILED to apply`.

### What the wiring provides

- `privapp-permissions-microg.xml` → `/product/etc/permissions/` — required on
  user builds for the signature|privileged perms GmsCore/Phonesky request.
- `default-permissions-microg.xml` → auto-grants microG's runtime permissions.
- `sysconfig/*.xml` → exempts microG and the stores from battery optimization
  (`allow-in-power-save`, shown as "Unrestricted").
- [`microg-permissions-helper`](https://github.com/Myghi63/android_packages_apps_microg-permissions-helper)
  → platform-signed headless app for what XML cannot express: AppOps modes
  (install-unknown for the stores, overlay for GmsCore) and "open by default"
  web-domain approvals. Config and rules live in its README.

### Updating the prebuilts

    ./update.sh                  # pinned tag (GMS_TAG at the top of the script)
    GMS_TAG=latest ./update.sh   # follow the newest stable microG release

Pulls fresh APKs into `proprietary/` and prints each package's signer and
requested permissions so the allowlists can be refreshed. Needs `curl`, `jq`
and `unzip` (optionally `aapt2` / `keytool`).
