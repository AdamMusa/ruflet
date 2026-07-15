import 'package:flet/flet.dart';
import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

class RufletWebViewExtension extends FletExtension {
  @override
  Widget? createWidget(Key? key, Control control) {
    if (control.type != 'WebView') return null;
    return RufletWebViewControl(key: key, control: control);
  }
}

class RufletWebViewControl extends StatefulWidget {
  const RufletWebViewControl({super.key, required this.control});

  final Control control;

  @override
  State<RufletWebViewControl> createState() => _RufletWebViewControlState();
}

class _RufletWebViewControlState extends State<RufletWebViewControl> {
  late final WebViewController controller;
  bool _scrollHandlerRegistered = false;
  bool _consoleHandlerRegistered = false;
  bool _alertHandlerRegistered = false;

  LoadRequestMethod _loadRequestMethod(dynamic value) {
    return value.toString().toLowerCase() == 'post'
        ? LoadRequestMethod.post
        : LoadRequestMethod.get;
  }

  JavaScriptMode _javascriptMode(dynamic value) {
    return value.toString().toLowerCase() == 'disabled'
        ? JavaScriptMode.disabled
        : JavaScriptMode.unrestricted;
  }

  bool _shouldPreventNavigation(String url) {
    final links = widget.control.get<List>('prevent_links');
    if (links == null || links.isEmpty) return false;
    return links.any((link) => link is String && url.startsWith(link));
  }

  void _setOptionalEventHandlers() {
    if (!_scrollHandlerRegistered && widget.control.hasEventHandler('scroll')) {
      controller.setOnScrollPositionChange((position) {
        widget.control.triggerEvent('scroll', {
          'x': position.x,
          'y': position.y,
        });
      });
      _scrollHandlerRegistered = true;
    }

    if (!_consoleHandlerRegistered &&
        widget.control.hasEventHandler('console_message')) {
      controller.setOnConsoleMessage((message) {
        widget.control.triggerEvent('console_message', {
          'message': message.message,
          'severity_level': message.level.name,
        });
      });
      _consoleHandlerRegistered = true;
    }

    if (!_alertHandlerRegistered &&
        widget.control.hasEventHandler('javascript_alert_dialog')) {
      controller.setOnJavaScriptAlertDialog((request) async {
        widget.control.triggerEvent('javascript_alert_dialog', {
          'message': request.message,
          'url': request.url,
        });
      });
      _alertHandlerRegistered = true;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.control.addInvokeMethodListener(_invokeMethod);
    controller = WebViewController();
    controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (progress) {
          widget.control.triggerEvent('progress', progress);
        },
        onUrlChange: (change) {
          widget.control.triggerEvent('url_change', change.url);
        },
        onPageStarted: (url) {
          widget.control.triggerEvent('page_started', url);
        },
        onPageFinished: (url) {
          widget.control.triggerEvent('page_ended', url);
        },
        onWebResourceError: (error) {
          widget.control.triggerEvent('web_resource_error', error.description);
        },
        onNavigationRequest: (request) {
          return _shouldPreventNavigation(request.url)
              ? NavigationDecision.prevent
              : NavigationDecision.navigate;
        },
      ),
    );
    controller.setJavaScriptMode(
      widget.control.getBool('enable_javascript', true)!
          ? JavaScriptMode.unrestricted
          : JavaScriptMode.disabled,
    );
    controller.loadRequest(
      Uri.parse(widget.control.getString('url', 'https://ruflet.dev')!),
      method: _loadRequestMethod(widget.control.getString('method', 'get')),
    );
    _setOptionalEventHandlers();
  }

  Future<dynamic> _invokeMethod(String name, dynamic args) async {
    switch (name) {
      case 'reload':
        return controller.reload();
      case 'can_go_back':
        return controller.canGoBack();
      case 'can_go_forward':
        return controller.canGoForward();
      case 'go_back':
        if (await controller.canGoBack()) await controller.goBack();
        return null;
      case 'go_forward':
        if (await controller.canGoForward()) await controller.goForward();
        return null;
      case 'enable_zoom':
        return controller.enableZoom(true);
      case 'disable_zoom':
        return controller.enableZoom(false);
      case 'clear_cache':
        return controller.clearCache();
      case 'clear_local_storage':
        return controller.clearLocalStorage();
      case 'get_current_url':
        return controller.currentUrl();
      case 'get_title':
        return controller.getTitle();
      case 'get_user_agent':
        return controller.getUserAgent();
      case 'load_file':
        return controller.loadFile(args['path']);
      case 'load_html':
        return controller.loadHtmlString(
          args['value'],
          baseUrl: args['base_url'],
        );
      case 'load_request':
        final url = args['url'];
        if (url != null) {
          return controller.loadRequest(
            Uri.parse(url),
            method: _loadRequestMethod(args['method']),
          );
        }
        return null;
      case 'run_javascript':
        final script = args['value'];
        return script == null ? null : controller.runJavaScript(script);
      case 'scroll_to':
        return controller.scrollTo(args['x'].toInt(), args['y'].toInt());
      case 'scroll_by':
        return controller.scrollBy(args['x'].toInt(), args['y'].toInt());
      case 'set_javascript_mode':
        return controller.setJavaScriptMode(_javascriptMode(args['mode']));
      default:
        throw UnsupportedError('Unknown WebView method: $name');
    }
  }

  @override
  void dispose() {
    widget.control.removeInvokeMethodListener(_invokeMethod);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _setOptionalEventHandlers();
    final background = widget.control.getColor('bgcolor', context);
    if (background != null) controller.setBackgroundColor(background);
    return LayoutControl(
      control: widget.control,
      child: WebViewWidget(controller: controller),
    );
  }
}
