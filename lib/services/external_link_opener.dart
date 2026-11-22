import 'package:flutter/services.dart';

/// Opens trusted third-party application/source URLs outside the app.
class ExternalLinkOpener {
  const ExternalLinkOpener();
  static const MethodChannel _channel = MethodChannel('smiunotes/external_links');

  static Uri? trustedHttps(Object? raw) {
    if (raw is! String || raw.length > 2048) return null;
    final value = Uri.tryParse(raw.trim());
    if (value == null || value.scheme != 'https' || value.host.isEmpty ||
        value.userInfo.isNotEmpty || value.hasFragment && value.fragment.length > 300) {
      return null;
    }
    return value;
  }

  Future<void> openHttps(Object? raw) async {
    final url = trustedHttps(raw);
    if (url == null) throw const FormatException('Invalid HTTPS link.');
    await _channel.invokeMethod<void>('openUrl', {'url': url.toString()});
  }
}
