import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Browser-based Cloudflare Turnstile proof. No secret key in the app.
/// Server still must verify the returned token's hostname, action, and expiry.
///
/// This is not wired to the default login until a device-accessible staging
/// hostname has been approved and end-to-end testing has passed.
Future<String?> requestMobileTurnstile(
  BuildContext context, {
  required String httpsOrigin,
  String purpose = 'mobile_login',
}) async {
  if (!(Platform.isAndroid || Platform.isIOS)) {
    throw UnsupportedError('Turnstile requires Android or iOS WebView.');
  }
  final base = Uri.tryParse(httpsOrigin);
  if (base == null ||
      base.scheme != 'https' ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment ||
      base.path != '' && base.path != '/') {
    throw const FormatException('Configure an approved HTTPS challenge host.');
  }
  if (purpose != 'mobile_login' && purpose != 'contact') {
    throw const FormatException('Invalid challenge purpose.');
  }
  final challenge = base.resolve('/api/mobile/v1/challenge').replace(
    queryParameters: purpose == 'contact' ? {'purpose': 'contact'} : null,
  );
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _MobileChallengeDialog(
      origin: base,
      challengeUrl: challenge,
    ),
  );
}

class _MobileChallengeDialog extends StatefulWidget {
  const _MobileChallengeDialog({
    required this.origin,
    required this.challengeUrl,
  });
  final Uri origin;
  final Uri challengeUrl;

  @override
  State<_MobileChallengeDialog> createState() => _MobileChallengeDialogState();
}

class _MobileChallengeDialogState extends State<_MobileChallengeDialog> {
  late final WebViewController _web;
  bool _complete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final url = Uri.tryParse(request.url);
          if (url == null) return NavigationDecision.prevent;
          // The widget page must come only from our configured host.
          // Cloudflare challenge resources may be hosted in its own iframe.
          if (url.scheme == 'https' &&
              (url.host == widget.origin.host ||
               url.host == 'challenges.cloudflare.com')) {
            return NavigationDecision.navigate;
          }
          return NavigationDecision.prevent;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame == true && mounted) {
            setState(() => _error = 'Unable to load security verification.');
          }
        },
      ))
      ..addJavaScriptChannel('TurnstileBridge',
        onMessageReceived: (message) {
          final proof = message.message;
          if (_complete ||
              proof.length < 10 || proof.length > 2048 ||
              !mounted) {
            return;
          }
          _complete = true;
          Navigator.of(context).pop(proof);
        },
      )
      ..loadRequest(widget.challengeUrl);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 480, maxHeight: 520,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Expanded(child: Text('Security verification',
                style: TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel verification',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
            if (_error != null) Text(_error!,
              style: const TextStyle(color: Colors.red)),
            Expanded(child: WebViewWidget(controller: _web)),
          ],
        ),
      ),
    ),
  );
}
