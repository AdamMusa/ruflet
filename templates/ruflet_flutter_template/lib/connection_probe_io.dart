import 'dart:io';

Future<bool> canConnectToPageUrl(
  String pageUrl, {
  Duration timeout = const Duration(milliseconds: 900),
}) async {
  final uri = Uri.tryParse(pageUrl);
  if (uri == null || uri.host.isEmpty) return false;

  final healthUri = Uri(
    scheme: uri.scheme,
    userInfo: uri.userInfo,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: '/health',
  );
  final client = HttpClient();
  try {
    final request = await client.getUrl(healthUri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    await response.drain<void>();
    return response.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}
