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
| FDroidPrivilegedExtension | `org.fdroid.fdroid.privileged` | yes   | [f-droid.org](https://f-droid.org/packages/org.fdroid.fdroid.privileged/) |

GsfProxy is the SaeedDev94 fork because the original microG GsfProxy targets
SDK 23; the fork targets 36 and ships uncompressed dex.

### App stores

Aurora Store and F-Droid are bundled for out-of-the-box app installs.

- **Aurora Store** installs via the unprivileged `PackageInstaller` session API,
  so each install/update shows a confirmation. It never uses the privileged
  `INSTALL_PACKAGES` path, so shipping it as a privileged app buys nothing — it
  is a regular app.
- **F-Droid** pairs with the **F-Droid Privileged Extension**, a privileged app
  holding `INSTALL_PACKAGES` / `DELETE_PACKAGES` (allowlisted in
  `privapp-permissions-fdroid.xml`). With it present, F-Droid installs and
  updates apps **unattended** — no per-app tap. The extension is signed with the
  same key as the F-Droid client, which the client trusts by default, so no
  extra pairing step is needed.

### Requirements

A ROM with **microG signature spoofing** built into the framework. crDroid and
most Lineage-based trees have it: the framework returns Google's signature for
`com.google.android.gms` / `com.android.vending` (by package name + a
`fake-signature` metadata match), so no `FAKE_PACKAGE_SIGNATURE` permission or
Xposed module is needed. Stock AOSP without that patch will not spoof and
microG's self-check stays red.

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

Run `./update.sh` to pull the latest release APKs into `proprietary/` and print
each APK's package id, signer and requested permissions so you can refresh the
allowlists if microG's permission set changed.
