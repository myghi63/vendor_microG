# microG integration: GmsCore, Companion/Phonesky, GsfProxy + permission
# allowlists. Inherit this from your device.mk (or common device makefile):
#
#     $(call inherit-product, vendor/microG/common.mk)
#
# Requires a ROM with microG signature-spoofing support (crDroid/Lineage-based
# trees have it: the framework fakes the Google signature for com.google.android.gms
# and com.android.vending). Stock AOSP without that patch will not spoof.

PRODUCT_SOONG_NAMESPACES += \
    vendor/microG

PRODUCT_PACKAGES += \
    GmsCore \
    Phonesky \
    GsfProxy

# App stores: Aurora Store and F-Droid (client + Privileged Extension). The
# extension is privileged and lets F-Droid update apps unattended.
PRODUCT_PACKAGES += \
    AuroraStore \
    FDroid \
    FDroidPrivilegedExtension

# privapp-permissions: signature|privileged perms for the privileged microG apps
# (boot fails on user builds without this). default-permissions: auto-grant the
# runtime perms so the user skips microG's in-app permission wizard.
# The fdroid allowlist grants INSTALL_PACKAGES/DELETE_PACKAGES to the F-Droid
# Privileged Extension (unattended installs/updates).
PRODUCT_COPY_FILES += \
    vendor/microG/permissions/privapp-permissions-microg.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/permissions/privapp-permissions-microg.xml \
    vendor/microG/permissions/privapp-permissions-fdroid.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/permissions/privapp-permissions-fdroid.xml \
    vendor/microG/permissions/default-permissions-microg.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/default-permissions/default-permissions-microg.xml

# sysconfig: make Aurora the default handler for Play Store web links
# (app-link) and exempt it from Doze / battery optimization (allow-in-power-save,
# shown as "Unrestricted" in Settings). Neither needs a privileged app.
PRODUCT_COPY_FILES += \
    vendor/microG/sysconfig/aurora-store.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/sysconfig/aurora-store.xml \
    vendor/microG/sysconfig/fdroid.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/sysconfig/fdroid.xml
