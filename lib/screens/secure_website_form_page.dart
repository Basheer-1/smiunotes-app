import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/external_link_opener.dart';

/// Restricted in-app website handoff for forms that don't yet expose a
/// dedicated mobile submission endpoint. This is NOT a native form/API.
class SecureWebsiteFormPage extends StatefulWidget {
  const SecureWebsiteFormPage({
    super.key,
    required this.path,
    required this.title,
    this.opener = const ExternalLinkOpener(),
  });

  final String path;
  final String title;
  final ExternalLinkOpener opener;

  @override
  State<SecureWebsiteFormPage> createState() => _SecureWebsiteFormPageState();
}

class _SecureWebsiteFormPageState extends State<SecureWebsiteFormPage> {
  WebViewController? _controller;
  String? _error;
  bool _loading = true;

  static const _routes = {
    '/contact',
    '/support',
    '/profile',
    '/profile/settings',
    '/profile/verification',
  };

  @override
  void initState() {
    super.initState();
    if (!_routes.contains(widget.path)) {
      _error = 'Unsupported SMIUNotes page.';
      _loading = false;
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null || uri.scheme != 'https' ||
              uri.host != 'smiunotes.com' ||
              uri.userInfo.isNotEmpty) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() {
              _loading = false;
              _error = 'Unable to load the secure SMIUNotes page.';
            });
          }
        },
      ))
      ..loadRequest(Uri.https('smiunotes.com', widget.path));
    _controller = controller;
  }

  Future<void> _openBrowser() async {
    try {
      await widget.opener.openHttps('https://smiunotes.com${widget.path}');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unable to open the page. Try again.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          tooltip: 'Open in browser',
          onPressed: _openBrowser,
          icon: const Icon(Icons.open_in_browser),
        ),
      ],
    ),
    body: _controller == null
      ? Center(child: Text(_error ?? 'Unavailable'))
      : Stack(children: [
          WebViewWidget(controller: _controller!),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _openBrowser,
                      child: const Text('Continue in browser'),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
  );
}
