import 'package:flet/flet.dart' show FletExtension, setupDesktop;
import 'package:flet_ads/flet_ads.dart' as flet_ads;
import 'package:flet_audio/flet_audio.dart' as flet_audio;
import 'package:flet_camera/flet_camera.dart' as flet_camera;
import 'package:flet_charts/flet_charts.dart' as flet_charts;
import 'package:flet_code_editor/flet_code_editor.dart' as flet_code_editor;
import 'package:flet_color_pickers/flet_color_pickers.dart'
    as flet_color_picker;
import 'package:flet_datatable2/flet_datatable2.dart' as flet_datatable2;
import 'package:flet_flashlight/flet_flashlight.dart' as flet_flashlight;
import 'package:flet_geolocator/flet_geolocator.dart' as flet_geolocator;
import 'package:flet_lottie/flet_lottie.dart' as flet_lottie;
import 'package:flet_map/flet_map.dart' as flet_map;
import 'package:flet_permission_handler/flet_permission_handler.dart'
    as flet_permission_handler;
import 'package:flet_secure_storage/flet_secure_storage.dart'
    as flet_secure_storage;
import 'package:flet_video/flet_video.dart' as flet_video;
import 'package:flet_webview/flet_webview.dart' as flet_webview;

export 'package:flet/flet.dart' show FletExtension;
export 'main.dart'
    show
        RufletBootstrapApp,
        getRufletRouteUrlStrategy,
        normalizePageUrlForPlatform,
        normalizeUserUrl,
        parseUrlFromQrOrDeepLinkPayload;

Future<void> setupRufletDesktop() => setupDesktop();

List<FletExtension> createDefaultRufletExtensions() {
  return <FletExtension>[
    flet_ads.Extension(),
    flet_audio.Extension(),
    flet_camera.Extension(),
    flet_charts.Extension(),
    flet_code_editor.Extension(),
    flet_color_picker.Extension(),
    flet_datatable2.Extension(),
    flet_flashlight.Extension(),
    flet_geolocator.Extension(),
    flet_lottie.Extension(),
    flet_map.Extension(),
    flet_permission_handler.Extension(),
    flet_secure_storage.Extension(),
    flet_video.Extension(),
    flet_webview.Extension(),
  ];
}

void ensureRufletExtensionsInitialized(List<FletExtension> extensions) {
  for (final extension in extensions) {
    extension.ensureInitialized();
  }
}
