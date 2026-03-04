#!/bin/sh
set -e
set -u
set -o pipefail

function on_error {
  echo "$(realpath -mq "${0}"):$1: error: Unexpected failure"
}
trap 'on_error $LINENO' ERR


# This protects against multiple targets copying the same framework dependency at the same time. The solution
# was originally proposed here: https://lists.samba.org/archive/rsync/2008-February/020158.html
RSYNC_PROTECT_TMP_FILES=(--filter "P .*.??????")


variant_for_slice()
{
  case "$1" in
  "Ass.xcframework/ios-arm64")
    echo ""
    ;;
  "Ass.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Avcodec.xcframework/ios-arm64")
    echo ""
    ;;
  "Avcodec.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Avfilter.xcframework/ios-arm64")
    echo ""
    ;;
  "Avfilter.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Avformat.xcframework/ios-arm64")
    echo ""
    ;;
  "Avformat.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Avutil.xcframework/ios-arm64")
    echo ""
    ;;
  "Avutil.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Dav1d.xcframework/ios-arm64")
    echo ""
    ;;
  "Dav1d.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Freetype.xcframework/ios-arm64")
    echo ""
    ;;
  "Freetype.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Fribidi.xcframework/ios-arm64")
    echo ""
    ;;
  "Fribidi.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Harfbuzz.xcframework/ios-arm64")
    echo ""
    ;;
  "Harfbuzz.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Mbedcrypto.xcframework/ios-arm64")
    echo ""
    ;;
  "Mbedcrypto.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Mbedtls.xcframework/ios-arm64")
    echo ""
    ;;
  "Mbedtls.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Mbedx509.xcframework/ios-arm64")
    echo ""
    ;;
  "Mbedx509.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Mpv.xcframework/ios-arm64")
    echo ""
    ;;
  "Mpv.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Png16.xcframework/ios-arm64")
    echo ""
    ;;
  "Png16.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Swresample.xcframework/ios-arm64")
    echo ""
    ;;
  "Swresample.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Swscale.xcframework/ios-arm64")
    echo ""
    ;;
  "Swscale.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Uchardet.xcframework/ios-arm64")
    echo ""
    ;;
  "Uchardet.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  "Xml2.xcframework/ios-arm64")
    echo ""
    ;;
  "Xml2.xcframework/ios-arm64_x86_64-simulator")
    echo "simulator"
    ;;
  esac
}

archs_for_slice()
{
  case "$1" in
  "Ass.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Ass.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Avcodec.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Avcodec.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Avfilter.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Avfilter.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Avformat.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Avformat.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Avutil.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Avutil.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Dav1d.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Dav1d.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Freetype.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Freetype.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Fribidi.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Fribidi.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Harfbuzz.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Harfbuzz.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Mbedcrypto.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Mbedcrypto.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Mbedtls.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Mbedtls.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Mbedx509.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Mbedx509.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Mpv.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Mpv.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Png16.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Png16.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Swresample.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Swresample.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Swscale.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Swscale.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Uchardet.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Uchardet.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  "Xml2.xcframework/ios-arm64")
    echo "arm64"
    ;;
  "Xml2.xcframework/ios-arm64_x86_64-simulator")
    echo "arm64 x86_64"
    ;;
  esac
}

copy_dir()
{
  local source="$1"
  local destination="$2"

  # Use filter instead of exclude so missing patterns don't throw errors.
  echo "rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter \"- CVS/\" --filter \"- .svn/\" --filter \"- .git/\" --filter \"- .hg/\" \"${source}*\" \"${destination}\""
  rsync --delete -av "${RSYNC_PROTECT_TMP_FILES[@]}" --links --filter "- CVS/" --filter "- .svn/" --filter "- .git/" --filter "- .hg/" "${source}"/* "${destination}"
}

SELECT_SLICE_RETVAL=""

select_slice() {
  local xcframework_name="$1"
  xcframework_name="${xcframework_name##*/}"
  local paths=("${@:2}")
  # Locate the correct slice of the .xcframework for the current architectures
  local target_path=""

  # Split archs on space so we can find a slice that has all the needed archs
  local target_archs=$(echo $ARCHS | tr " " "\n")

  local target_variant=""
  if [[ "$PLATFORM_NAME" == *"simulator" ]]; then
    target_variant="simulator"
  fi
  if [[ ! -z ${EFFECTIVE_PLATFORM_NAME+x} && "$EFFECTIVE_PLATFORM_NAME" == *"maccatalyst" ]]; then
    target_variant="maccatalyst"
  fi
  for i in ${!paths[@]}; do
    local matched_all_archs="1"
    local slice_archs="$(archs_for_slice "${xcframework_name}/${paths[$i]}")"
    local slice_variant="$(variant_for_slice "${xcframework_name}/${paths[$i]}")"
    for target_arch in $target_archs; do
      if ! [[ "${slice_variant}" == "$target_variant" ]]; then
        matched_all_archs="0"
        break
      fi

      if ! echo "${slice_archs}" | tr " " "\n" | grep -F -q -x "$target_arch"; then
        matched_all_archs="0"
        break
      fi
    done

    if [[ "$matched_all_archs" == "1" ]]; then
      # Found a matching slice
      echo "Selected xcframework slice ${paths[$i]}"
      SELECT_SLICE_RETVAL=${paths[$i]}
      break
    fi
  done
}

install_xcframework() {
  local basepath="$1"
  local name="$2"
  local package_type="$3"
  local paths=("${@:4}")

  # Locate the correct slice of the .xcframework for the current architectures
  select_slice "${basepath}" "${paths[@]}"
  local target_path="$SELECT_SLICE_RETVAL"
  if [[ -z "$target_path" ]]; then
    echo "warning: [CP] $(basename ${basepath}): Unable to find matching slice in '${paths[@]}' for the current build architectures ($ARCHS) and platform (${EFFECTIVE_PLATFORM_NAME-${PLATFORM_NAME}})."
    return
  fi
  local source="$basepath/$target_path"

  local destination="${PODS_XCFRAMEWORKS_BUILD_DIR}/${name}"

  if [ ! -d "$destination" ]; then
    mkdir -p "$destination"
  fi

  copy_dir "$source/" "$destination"
  echo "Copied $source to $destination"
}

install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Ass.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Avcodec.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Avfilter.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Avformat.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Avutil.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Dav1d.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Freetype.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Fribidi.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Harfbuzz.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Mbedcrypto.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Mbedtls.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Mbedx509.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Mpv.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Png16.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Swresample.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Swscale.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Uchardet.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"
install_xcframework "${PODS_ROOT}/../.symlinks/plugins/media_kit_libs_ios_video/ios/Frameworks/Xml2.xcframework" "media_kit_libs_ios_video" "framework" "ios-arm64" "ios-arm64_x86_64-simulator"

