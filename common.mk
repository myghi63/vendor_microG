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

# privapp-permissions: signature|privileged perms for the privileged microG apps
# (boot fails on user builds without this). default-permissions: auto-grant the
# runtime perms so the user skips microG's in-app permission wizard.
PRODUCT_COPY_FILES += \
    vendor/microG/permissions/privapp-permissions-microg.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/permissions/privapp-permissions-microg.xml \
    vendor/microG/permissions/default-permissions-microg.xml:$(TARGET_COPY_OUT_PRODUCT)/etc/default-permissions/default-permissions-microg.xml
