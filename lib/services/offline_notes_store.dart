import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'authenticated_reader_api.dart';
import 'student_profile_api.dart';

/// App-private, AES-256-GCM encrypted WebP cache, scoped to a verified
/// Student Card identity. No files are placed in Downloads or shared storage.
///
/// An offline lease lasts 48 hours from successful live re-verification.
/// Revocation cannot be detected while a device has no internet: the short
/// lease bounds that window; on the next online save we re-check the server.
class OfflineNotesStore {
  OfflineNotesStore({required this.baseUrl});
  final String baseUrl;
  static const int maxPages = 60;
  static const int maxPageBytes = 5 * 1024 * 1024;
  static const Duration lease = Duration(hours: 48);
  static const FlutterSecureStorage _keys = FlutterSecureStorage();
  final AesGcm _aes = AesGcm.with256bits();

  static const String _activeLeaseKey = 'offline_active_verified_lease_v1';

  /// A device-local, short-lived lease lets the encrypted library open after
  /// a cold start without network. Re-login/online verification is required
  /// when the lease expires. Explicit sign-out clears this entitlement.
  static Future<String?> activeVerifiedOwner() async {
    final value = await _keys.read(key: _activeLeaseKey);
    if (value == null) return null;
    final parts = value.split('|');
    if (parts.length != 2 || !validId(parts[0])) return null;
    final epoch = int.tryParse(parts[1]);
    if (epoch == null || DateTime.now().millisecondsSinceEpoch >= epoch) {
      await _keys.delete(key: _activeLeaseKey);
      return null;
    }
    return parts[0];
  }

  static Future<void> clearActiveLease() =>
    _keys.delete(key: _activeLeaseKey);

  static bool validId(String value) =>
    RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
      .hasMatch(value);

  Future<Directory> _root(String owner) async {
    if (!validId(owner)) throw const FormatException('Invalid account.');
    final root = await getApplicationSupportDirectory();
    return Directory('${root.path}/offline_notes_v1/$owner');
  }

  Future<SecretKey> _key(String owner, {bool create = false}) async {
    if (!validId(owner)) throw const FormatException('Invalid account.');
    final keyName = 'offline_note_key_v1_$owner';
    var encoded = await _keys.read(key: keyName);
    if (encoded == null && create) {
      final random = Random.secure();
      encoded = base64Encode(
        Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256))));
      await _keys.write(key: keyName, value: encoded);
    }
    if (encoded == null) throw const StateError('Offline key unavailable.');
    final bytes = base64Decode(encoded);
    if (bytes.length != 32) throw const FormatException('Invalid local key.');
    return SecretKey(bytes);
  }

  Future<void> _write(File file, List<int> content, SecretKey key) async {
    final box = await _aes.encrypt(content, secretKey: key);
    final data = Uint8List.fromList(
      [...box.nonce, ...box.mac.bytes, ...box.cipherText]);
    await file.writeAsBytes(data, flush: true);
  }

  Future<Uint8List> _read(File file, SecretKey key) async {
    final value = await file.readAsBytes();
    if (value.length < 29) throw const FormatException('Damaged offline note.');
    final box = SecretBox(value.sublist(28),
      nonce: value.sublist(0, 12), mac: Mac(value.sublist(12, 28)));
    return Uint8List.fromList(await _aes.decrypt(box, secretKey: key));
  }

  Future<Map<String, dynamic>> _metadata(
    String owner, String noteId) async {
    if (!validId(noteId)) throw const FormatException('Invalid note.');
    final base = await _root(owner);
    final folder = Directory('${base.path}/$noteId');
    final data = await _read(File('${folder.path}/meta.bin'), await _key(owner));
    final result = jsonDecode(utf8.decode(data));
    if (result is! Map<String, dynamic> ||
        result['note_id'] != noteId ||
        result['owner'] != owner) {
      throw const FormatException('Invalid offline note metadata.');
    }
    final expires = DateTime.tryParse(result['expires_at']?.toString() ?? '');
    if (expires == null || !DateTime.now().isBefore(expires)) {
      throw const StateError('Offline access expired. Reconnect to verify.');
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> list(String owner) async {
    final root = await _root(owner);
    if (!await root.exists()) return [];
    final result = <Map<String, dynamic>>[];
    await for (final node in root.list(followLinks: false)) {
      if (node is! Directory || !validId(node.uri.pathSegments
          .where((s) => s.isNotEmpty).last)) continue;
      final id = node.uri.pathSegments.where((s) => s.isNotEmpty).last;
      try {
        result.add(await _metadata(owner, id));
      } catch (_) {
        // Expired/corrupt entries never become readable.
      }
    }
    result.sort((a, b) => (b['saved_at']?.toString() ?? '').compareTo(
      a['saved_at']?.toString() ?? ''));
    return result;
  }

  Future<Map<String, dynamic>> open(String owner, String noteId) =>
      _metadata(owner, noteId);

  Future<Uint8List> page(String owner, String noteId, int page) async {
    final metadata = await _metadata(owner, noteId);
    final entries = metadata['pages'];
    if (page < 1 || entries is! List ||
        !entries.any((e) => e is Map && e['number'] == page)) {
      throw const FormatException('Page is not cached.');
    }
    final root = await _root(owner);
    return _read(File('${root.path}/$noteId/page_$page.bin'),
      await _key(owner));
  }

  Future<void> remove(String owner, String noteId) async {
    if (!validId(noteId)) return;
    final base = await _root(owner);
    final folder = Directory('${base.path}/$noteId');
    if (await folder.exists()) await folder.delete(recursive: true);
  }

  Future<void> save({
    required String owner,
    required String noteId,
    required String accessToken,
    void Function(int, int)? onProgress,
  }) async {
    if (!validId(owner) || !validId(noteId)) {
      throw const FormatException('Invalid offline download.');
    }
    // Always refresh live Student Card status before generating an offline lease.
    final profile = await StudentProfileApi(baseUrl: baseUrl)
        .fetchOwnProfile(accessToken);
    if (profile.profileId != owner || profile.accountStatus != 'active' ||
        profile.verificationStatus != 'verified') {
      throw const StateError('Student Card verification required.');
    }
    final reader = AuthenticatedReaderApi(baseUrl: baseUrl);
    final manifest = await reader.request(
      accessToken: accessToken, noteId: noteId, manifest: true);
    final rawPages = manifest['pages'];
    if (rawPages is! List || rawPages.isEmpty || rawPages.length > maxPages) {
      throw const FormatException('Unsupported offline page count.');
    }
    final root = await _root(owner);
    await root.create(recursive: true);
    final folder = Directory('${root.path}/$noteId');
    final staging = Directory('${root.path}/.$noteId-pending');
    if (await staging.exists()) await staging.delete(recursive: true);
    await staging.create(recursive: true);
    final key = await _key(owner, create: true);
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final pages = <Map<String, dynamic>>[];
      for (var i = 0; i < rawPages.length; i++) {
        final raw = rawPages[i];
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid page metadata.');
        }
        final number = raw['page_number'];
        if (number is! int || number < 1 || number > maxPages ||
            pages.any((e) => e['number'] == number)) {
          throw const FormatException('Invalid page number.');
        }
        final signed = await reader.request(
          accessToken: accessToken, noteId: noteId,
          manifest: false, page: number);
        final url = Uri.tryParse(signed['url']?.toString() ?? '');
        if (url == null || url.scheme != 'https' || url.userInfo.isNotEmpty ||
            url.host.isEmpty) {
          throw const FormatException('Invalid signed image URL.');
        }
        final request = await client.getUrl(url);
        request.followRedirects = false;
        final response = await request.close().timeout(
          const Duration(seconds: 20));
        if (response.statusCode != 200 ||
            response.contentLength > maxPageBytes) {
          throw const HttpException('Protected page unavailable.');
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(
          const Duration(seconds: 30))) {
          bytes.add(chunk);
          if (bytes.length > maxPageBytes) {
            throw const FormatException('Offline page size limit exceeded.');
          }
        }
        if (bytes.length < 32) {
          throw const FormatException('Empty protected page.');
        }
        await _write(File('${staging.path}/page_$number.bin'),
          bytes.takeBytes(), key);
        pages.add({'number': number,
          'width': raw['width'] ?? 800,
          'height': raw['height'] ?? 1100});
        onProgress?.call(i + 1, rawPages.length);
      }
      final now = DateTime.now().toUtc();
      final metadata = <String, dynamic>{
        'owner': owner,
        'note_id': noteId,
        'title': manifest['title']?.toString() ?? 'Offline note',
        'saved_at': now.toIso8601String(),
        'expires_at': now.add(lease).toIso8601String(),
        'pages': pages,
      };
      await _write(File('${staging.path}/meta.bin'),
        utf8.encode(jsonEncode(metadata)), key);
      if (await folder.exists()) await folder.delete(recursive: true);
      await staging.rename(folder.path);
      await _keys.write(key: _activeLeaseKey,
        value: '$owner|${DateTime.now().add(lease).millisecondsSinceEpoch}');
    } finally {
      client.close(force: true);
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }
}
