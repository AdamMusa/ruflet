import 'dart:io';

Uri _toWsUri(Uri uri) {
  final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
  return uri.replace(
    scheme: scheme,
    path: '/ws',
    query: '',
    fragment: '',
  );
}

Future<bool> canConnectToPageUrl(
  String pageUrl, {
  Duration timeout = const Duration(milliseconds: 900),
}) async {
  final uri = Uri.tryParse(pageUrl);
  if (uri == null || uri.host.isEmpty) return false;

  final wsUri = _toWsUri(uri);
  WebSocket? socket;
  try {
    socket = await WebSocket.connect(wsUri.toString()).timeout(timeout);
    await socket.close();
    return true;
  } catch (_) {
    try {
      await socket?.close();
    } catch (_) {}
    return false;
  }
}
