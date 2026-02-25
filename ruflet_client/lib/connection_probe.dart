import 'connection_probe_stub.dart'
    if (dart.library.io) 'connection_probe_io.dart' as impl;

Future<bool> canConnectToPageUrl(
  String pageUrl, {
  Duration timeout = const Duration(milliseconds: 900),
}) {
  return impl.canConnectToPageUrl(pageUrl, timeout: timeout);
}
