import 'package:flutter_test/flutter_test.dart';
import 'package:ruflet_client/main.dart';

void main() {
  test('schemeless public domains normalize to HTTPS', () {
    expect(normalizeUserUrl('ruflet.dev'), 'https://ruflet.dev');
  });

  test('schemeless local development hosts normalize to HTTP', () {
    expect(normalizeUserUrl('localhost:8550'), startsWith('http://'));
    expect(normalizeUserUrl('10.0.2.2:8550'), 'http://10.0.2.2:8550');
  });

  test('production mobile does not force a default URL', () {
    final url = resolveInitialRufletUrl(
      baseUrl: 'file:///',
      args: null,
      isWeb: false,
      isDebugMode: false,
      isMobilePlatform: true,
      productionDefaultUrl: '',
    );

    expect(url, isEmpty);
  });

  test('debug mobile starts with developer input instead of localhost', () {
    final url = resolveInitialRufletUrl(
      baseUrl: 'file:///',
      args: null,
      isWeb: false,
      isDebugMode: true,
      isMobilePlatform: true,
      productionDefaultUrl: '',
    );

    expect(url, isEmpty);
  });

  test('debug desktop keeps the local development default', () {
    final url = resolveInitialRufletUrl(
      baseUrl: 'file:///',
      args: null,
      isWeb: false,
      isDebugMode: true,
      isMobilePlatform: false,
      productionDefaultUrl: '',
    );

    expect(url, 'http://localhost:8550');
  });

  test('configured URL works in production builds', () {
    final url = resolveInitialRufletUrl(
      baseUrl: 'file:///',
      args: null,
      isWeb: false,
      isDebugMode: false,
      isMobilePlatform: true,
      configuredUrl: 'https://example.com',
      productionDefaultUrl: 'https://ruflet.dev',
    );

    expect(url, 'https://example.com');
  });

  test('web query URL wins over the production default', () {
    final url = resolveInitialRufletUrl(
      baseUrl: 'https://explorer.example/?url=https%3A%2F%2Fapp.example',
      args: null,
      isWeb: true,
      isDebugMode: false,
      isMobilePlatform: false,
      productionDefaultUrl: 'https://ruflet.dev',
    );

    expect(url, 'https://app.example');
  });
}
