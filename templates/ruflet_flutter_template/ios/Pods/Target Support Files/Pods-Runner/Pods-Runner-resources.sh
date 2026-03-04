#!/bin/sh
set -e
set -u
set -o pipefail

function on_error {
  echo "$(realpath -mq "${0}"):$1: error: Unexpected failure"
}
trap 'on_error $LINENO' ERR

if [ -z ${UNLOCALIZED_RESOURCES_FOLDER_PATH+x} ]; then
  # If UNLOCALIZED_RESOURCES_FOLDER_PATH is not set, then there's nowhere for us to copy
  # resources to, so exit 0 (signalling the script phase was successful).
  exit 0
fi

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

RESOURCES_TO_COPY=${PODS_ROOT}/resources-to-copy-${TARGETNAME}.txt
> "$RESOURCES_TO_COPY"

XCASSET_FILES=()

# This protects against multiple targets copying the same framework dependency at the same time. The solution
# was originally proposed here: https://lists.samba.org/archive/rsync/2008-February/020158.html
RSYNC_PROTECT_TMP_FILES=(--filter "P .*.??????")

case "${TARGETED_DEVICE_FAMILY:-}" in
  1,2)
    TARGET_DEVICE_ARGS="--target-device ipad --target-device iphone"
    ;;
  1)
    TARGET_DEVICE_ARGS="--target-device iphone"
    ;;
  2)
    TARGET_DEVICE_ARGS="--target-device ipad"
    ;;
  3)
    TARGET_DEVICE_ARGS="--target-device tv"
    ;;
  4)
    TARGET_DEVICE_ARGS="--target-device watch"
    ;;
  *)
    TARGET_DEVICE_ARGS="--target-device mac"
    ;;
esac

install_resource()
{
  if [[ "$1" = /* ]] ; then
    RESOURCE_PATH="$1"
  else
    RESOURCE_PATH="${PODS_ROOT}/$1"
  fi
  if [[ ! -e "$RESOURCE_PATH" ]] ; then
    cat << EOM
error: Resource "$RESOURCE_PATH" not found. Run 'pod install' to update the copy resources script.
EOM
    exit 1
  fi
  case $RESOURCE_PATH in
    *.storyboard)
      echo "ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .storyboard`.storyboardc $RESOURCE_PATH --sdk ${SDKROOT} ${TARGET_DEVICE_ARGS}" || true
      ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .storyboard`.storyboardc" "$RESOURCE_PATH" --sdk "${SDKROOT}" ${TARGET_DEVICE_ARGS}
      ;;
    *.xib)
      echo "ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile ${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .xib`.nib $RESOURCE_PATH --sdk ${SDKROOT} ${TARGET_DEVICE_ARGS}" || true
      ibtool --reference-external-strings-file --errors --warnings --notices --minimum-deployment-target ${!DEPLOYMENT_TARGET_SETTING_NAME} --output-format human-readable-text --compile "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$RESOURCE_PATH\" .xib`.nib" "$RESOURCE_PATH" --sdk "${SDKROOT}" ${TARGET_DEVICE_ARGS}
      ;;
    *.framework)
      echo "mkdir -p ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}" || true
      mkdir -p "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" $RESOURCE_PATH ${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}" || true
      rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      ;;
    *.xcdatamodel)
      echo "xcrun momc \"$RESOURCE_PATH\" \"${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH"`.mom\"" || true
      xcrun momc "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcdatamodel`.mom"
      ;;
    *.xcdatamodeld)
      echo "xcrun momc \"$RESOURCE_PATH\" \"${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcdatamodeld`.momd\"" || true
      xcrun momc "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcdatamodeld`.momd"
      ;;
    *.xcmappingmodel)
      echo "xcrun mapc \"$RESOURCE_PATH\" \"${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcmappingmodel`.cdm\"" || true
      xcrun mapc "$RESOURCE_PATH" "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$RESOURCE_PATH" .xcmappingmodel`.cdm"
      ;;
    *.xcassets)
      ABSOLUTE_XCASSET_FILE="$RESOURCE_PATH"
      XCASSET_FILES+=("$ABSOLUTE_XCASSET_FILE")
      ;;
    *)
      echo "$RESOURCE_PATH" || true
      echo "$RESOURCE_PATH" >> "$RESOURCES_TO_COPY"
      ;;
  esac
}
if [[ "$CONFIGURATION" == "Debug" ]]; then
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/DKImagePickerController/DKImagePickerController.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/DKPhotoGallery/DKPhotoGallery.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/Google-Mobile-Ads-SDK/GoogleMobileAdsResources.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/GoogleUserMessagingPlatform/UserMessagingPlatformResources.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/SDWebImage/SDWebImage.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/SwiftyGif/SwiftyGif.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/battery_plus/battery_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/camera_avfoundation/camera_avfoundation_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/connectivity_plus/connectivity_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/device_info_plus/device_info_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/file_picker/file_picker_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/flutter_native_splash/flutter_native_splash_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/flutter_secure_storage_darwin/flutter_secure_storage.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/geolocator_apple/geolocator_apple_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/google_mobile_ads/google_mobile_ads.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/package_info_plus/package_info_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/permission_handler_apple/permission_handler_apple_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/record_ios/record_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/screen_brightness_ios/screen_brightness_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/sensors_plus/sensors_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/share_plus/share_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/shared_preferences_foundation/shared_preferences_foundation_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/url_launcher_ios/url_launcher_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/wakelock_plus/wakelock_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/webview_flutter_wkwebview/webview_flutter_wkwebview_privacy.bundle"
fi
if [[ "$CONFIGURATION" == "Release" ]]; then
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/DKImagePickerController/DKImagePickerController.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/DKPhotoGallery/DKPhotoGallery.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/Google-Mobile-Ads-SDK/GoogleMobileAdsResources.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/GoogleUserMessagingPlatform/UserMessagingPlatformResources.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/SDWebImage/SDWebImage.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/SwiftyGif/SwiftyGif.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/battery_plus/battery_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/camera_avfoundation/camera_avfoundation_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/connectivity_plus/connectivity_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/device_info_plus/device_info_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/file_picker/file_picker_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/flutter_native_splash/flutter_native_splash_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/flutter_secure_storage_darwin/flutter_secure_storage.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/geolocator_apple/geolocator_apple_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/google_mobile_ads/google_mobile_ads.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/package_info_plus/package_info_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/permission_handler_apple/permission_handler_apple_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/record_ios/record_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/screen_brightness_ios/screen_brightness_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/sensors_plus/sensors_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/share_plus/share_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/shared_preferences_foundation/shared_preferences_foundation_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/url_launcher_ios/url_launcher_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/wakelock_plus/wakelock_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/webview_flutter_wkwebview/webview_flutter_wkwebview_privacy.bundle"
fi
if [[ "$CONFIGURATION" == "Profile" ]]; then
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/DKImagePickerController/DKImagePickerController.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/DKPhotoGallery/DKPhotoGallery.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/Google-Mobile-Ads-SDK/GoogleMobileAdsResources.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/GoogleUserMessagingPlatform/UserMessagingPlatformResources.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/SDWebImage/SDWebImage.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/SwiftyGif/SwiftyGif.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/battery_plus/battery_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/camera_avfoundation/camera_avfoundation_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/connectivity_plus/connectivity_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/device_info_plus/device_info_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/file_picker/file_picker_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/flutter_native_splash/flutter_native_splash_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/flutter_secure_storage_darwin/flutter_secure_storage.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/geolocator_apple/geolocator_apple_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/google_mobile_ads/google_mobile_ads.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/package_info_plus/package_info_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/permission_handler_apple/permission_handler_apple_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/record_ios/record_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/screen_brightness_ios/screen_brightness_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/sensors_plus/sensors_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/share_plus/share_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/shared_preferences_foundation/shared_preferences_foundation_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/url_launcher_ios/url_launcher_ios_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/wakelock_plus/wakelock_plus_privacy.bundle"
  install_resource "${PODS_CONFIGURATION_BUILD_DIR}/webview_flutter_wkwebview/webview_flutter_wkwebview_privacy.bundle"
fi

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
rsync -avr --copy-links --no-relative --exclude '*/.svn/*' --files-from="$RESOURCES_TO_COPY" / "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
if [[ "${ACTION}" == "install" ]] && [[ "${SKIP_INSTALL}" == "NO" ]]; then
  mkdir -p "${INSTALL_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
  rsync -avr --copy-links --no-relative --exclude '*/.svn/*' --files-from="$RESOURCES_TO_COPY" / "${INSTALL_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
fi
rm -f "$RESOURCES_TO_COPY"

if [[ -n "${WRAPPER_EXTENSION}" ]] && [ "`xcrun --find actool`" ] && [ -n "${XCASSET_FILES:-}" ]
then
  # Find all other xcassets (this unfortunately includes those of path pods and other targets).
  OTHER_XCASSETS=$(find -L "$PWD" -iname "*.xcassets" -type d)
  while read line; do
    if [[ $line != "${PODS_ROOT}*" ]]; then
      XCASSET_FILES+=("$line")
    fi
  done <<<"$OTHER_XCASSETS"

  if [ -z ${ASSETCATALOG_COMPILER_APPICON_NAME+x} ]; then
    printf "%s\0" "${XCASSET_FILES[@]}" | xargs -0 xcrun actool --output-format human-readable-text --notices --warnings --platform "${PLATFORM_NAME}" --minimum-deployment-target "${!DEPLOYMENT_TARGET_SETTING_NAME}" ${TARGET_DEVICE_ARGS} --compress-pngs --compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
  else
    printf "%s\0" "${XCASSET_FILES[@]}" | xargs -0 xcrun actool --output-format human-readable-text --notices --warnings --platform "${PLATFORM_NAME}" --minimum-deployment-target "${!DEPLOYMENT_TARGET_SETTING_NAME}" ${TARGET_DEVICE_ARGS} --compress-pngs --compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}" --app-icon "${ASSETCATALOG_COMPILER_APPICON_NAME}" --output-partial-info-plist "${TARGET_TEMP_DIR}/assetcatalog_generated_info_cocoapods.plist"
  fi
fi
