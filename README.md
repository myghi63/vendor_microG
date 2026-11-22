## vendor_microG

Prebuilt [microG](https://microg.org) integration for Android device trees:
GmsCore, the Companion / Play Store proxy (Phonesky) and GsfProxy, wired as
system apps with the permission allowlists they need.

### What ships

| Module                    | Package                        | Priv? | Source |
|---------------------------|--------------------------------|-------|--------|
| GmsCore                   | `com.google.android.gms`       | yes   | [microg/GmsCore releases](https://github.com/microg/GmsCore/releases) |
| Phonesky                  | `com.android.vending`          | yes   | microg/GmsCore releases (Companion) |
| GsfProxy                  | `com.google.android.gsf`       | no    | [SaeedDev94/GsfProxy releases](https://github.com/SaeedDev94/GsfProxy/releases) |
| AuroraStore               | `com.aurora.store`             | no    | [AuroraOSS/AuroraStore releases](https://gitlab.com/AuroraOSS/AuroraStore/-/releases) |
| FDroid                    | `org.fdroid.fdroid`            | no    | [f-droid.org](https://f-droid.org/F-Droid.apk) |

GsfProxy is the SaeedDev94 fork because the original microG GsfProxy targets
SDK 23; the fork targets 36 and ships uncompressed dex.

### GmsCore native libraries

GmsCore.apk sets `android:extractNativeLibs="true"`, so the platform expects its
JNI libs unpacked into the app's `nativeLibraryDir`
(`/product/priv-app/GmsCore/lib/arm64`). The APK is imported `preprocessed`
(required: it is presigned v2/v3 and letting Soong zipalign/repack it would break
that signature), and Soong does not extract JNI libs from a preprocessed
prebuilt, so that dir would be empty. Any app that `dlopen()`s a GmsCore-provided
library then fails with `UnsatisfiedLinkError` — most visibly **Google Maps**,
which loads Cronet from Play Services (`libcronet.*.so` ships in GmsCore, not in
Maps) and crashes instantly on launch.

The libs are therefore pre-extracted into
`proprietary/product/priv-app/GmsCore/lib/arm64/` and copied into the lib dir at
build time by `common.mk` (wildcard, so a version bump only needs the `.so`
refreshed — `update.sh` re-extracts them automatically). arm64 only.

### App stores

Aurora Store and F-Droid are bundled for out-of-the-box app installs.

- **Aurora Store** is a regular app with two relevant install paths, neither of
  which needs it to be privileged. Its session installer uses the unprivileged
  `PackageInstaller` API: the first install of an app shows a confirmation, but
  Aurora requests `UPDATE_PACKAGES_WITHOUT_USER_ACTION` and
  `ENFORCE_UPDATE_OWNERSHIP`, so *updates* to apps it installed itself (where it
  holds update ownership) can go through without a prompt. Its optional microG
  installer hands the install to the **Companion** (Phonesky), a privileged app
  that holds `INSTALL_PACKAGES`. `sysconfig/aurora-store.xml` exempts it from battery
  optimization (`allow-in-power-save`, shown as "Unrestricted"). It does **not**
  try to make Aurora the default handler for `play.google.com` /
  `market.android.com` links: the `<app-link>` tag only approves an app's
  *autoVerify* web domains, and Aurora (targetSdk 36) declares none, so the tag
  would be a no-op. Setting Aurora as the link handler stays a one-time manual
  step (Settings > Aurora > Open by default).
- **F-Droid** also installs via the `PackageInstaller` session API, as a regular
  app. F-Droid 2.0 removed support for the **F-Droid Privileged Extension**, so
  the extension is no longer shipped: the client would ignore it. As with Aurora's
  session installer, the "install unknown apps" toggle is a one-time manual step, the first install
  of an app shows a confirmation, and F-Droid requests
  `UPDATE_PACKAGES_WITHOUT_USER_ACTION` and `ENFORCE_UPDATE_OWNERSHIP` for updates
  to apps it installed itself.

### Requirements

A ROM with **microG signature spoofing** built into the framework: the
framework returns Google's signature for `com.google.android.gms` /
`com.android.vending` (by package name + a `fake-signature` metadata match),
so no `FAKE_PACKAGE_SIGNATURE` permission or Xposed module is needed. Stock
AOSP without that patch will not spoof and microG's self-check stays red.

crDroid ships it on every build variant; Lineage/AOSP gate it to debuggable
builds. That means **only user / release-keys builds need a framework patch**,
and this repo carries it:

`patches/frameworks/base/0001-Allow-microG-signature-spoofing-on-user-builds.patch`
drops the `isDebuggable()` gate from `MicrogUtils.isMicrogSigned` so GmsCore
and the Companion signed with the real microG key are recognized on user
builds too. `vendorsetup.sh` applies it to `frameworks/base` whenever
`build/envsetup.sh` is sourced (envsetup scans `vendorsetup.sh` under
`device/`, `vendor/` and `product/`; this repo lives in `vendor/`, so no
manifest hook is needed). On userdebug/eng the patch changes nothing — spoofing
is already allowed there, so applying it is a no-op. `repo sync` discards the
applied commits on frameworks/base's detached HEAD: re-source envsetup
afterwards and check for `FAILED to apply`.

On ROMs that already spoof on all variants (crDroid and derivatives) the patch
is not needed: the reverse-check either skips it silently, or their different
code there produces a single harmless `FAILED to apply` line. `git am` is
atomic per patch, so the tree is never left partially modified and the build is
unaffected either way.

### Use

In your `device.mk` (or a common device makefile):

    $(call inherit-product, vendor/microG/common.mk)

That pulls in the three apps plus:

- `privapp-permissions-microg.xml` -> `/product/etc/permissions/` — the
  signature|privileged perms GmsCore/Phonesky request. **Required**: a
  privileged app requesting such a perm without an allowlist entry fails to
  boot on user builds (`ro.control_privapp_permissions=enforce`).
- `default-permissions-microg.xml` -> `/product/etc/default-permissions/` —
  auto-grants the runtime perms (location, phone, accounts, …) so the user
  skips microG's in-app permission wizard.

Rebuild. After first boot, open **microG Settings → Self-Check**: signature
spoofing, registration and the rest should be green.

### Notes on the prebuilts

- All APKs are `presigned` — do **not** resign. GmsCore/Phonesky must keep the
  microG signing key or the spoof metadata check and future F-Droid updates
  break.
- GmsCore/Phonesky ship compressed dex and are privileged; the build normally
  requires uncompressed dex for priv-apps, but their dex can't be uncompressed
  without invalidating the v2/v3 signature. `skip_preprocessed_apk_checks: true`
  in `Android.bp` defers dex extraction to dexopt at install time.
- The privapp allowlist lists only the perms the APKs actually request that are
  `signature|privileged` in the platform. Regenerate with `update.sh` after
  bumping the APKs (permission sets change between microG releases).

### Updating

Run `./update.sh` to pull the release APKs into `proprietary/` and print each
APK's package id, signer and requested permissions so you can refresh the
allowlists if microG's permission set changed. Needs `curl`, `jq` and `unzip`.

The microG release is **pinned** via `GMS_TAG` at the top of the script
(currently `v0.3.18.252432`). Pinning is required for pre-releases: GitHub's
`releases/latest` endpoint never returns them. To follow the newest *stable*
release instead:

    GMS_TAG=latest ./update.sh

Assets are matched by name, anchored as `com.google.android.gms-<code>.apk` /
`com.android.vending-<code>.apk`, which excludes the `-hw` (Huawei build — uses
the `hms` maps flavor and ships **no** `libmapbox-gl.so`) and `-user`
(unprivileged dev preview, different applicationId) variants. Do not relax those
patterns; picking the wrong flavor here installs `com.android.vending` into the
GmsCore slot and ships no microG Services at all.
