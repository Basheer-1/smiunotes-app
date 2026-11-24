import 'package:material_ui/material_ui.dart';
import 'dart:typed_data';
import '../models/student_profile.dart';
import '../services/native_avatar_api.dart';

import '../services/authenticated_reader_api.dart';
import '../services/community_write_api.dart';
import '../services/bookmark_api.dart';
import '../services/mobile_auth_api.dart';
import '../services/mobile_notification_api.dart';
import '../services/student_notification_preferences_api.dart';
import '../services/native_student_forms_api.dart';
import '../services/native_profile_settings_api.dart';
import 'native_student_forms.dart';
import 'native_notification_preferences_page.dart';
import '../services/push_registration_api.dart';
import '../services/student_push_enrollment.dart';
import 'notification_inbox_page.dart';
import '../services/mobile_turnstile.dart';
import '../services/student_auth_runtime.dart';
import 'authenticated_note_reader_page.dart';
import 'note_reader_page.dart';
import 'offline_library_page.dart';
import '../services/offline_notes_store.dart';
import '../services/public_feed_api.dart';
import '../widgets/reader_toolbar_actions.dart';
import 'community_composer_page.dart';
import 'my_bookmarks_page.dart';
import 'student_account_gateway.dart';
import 'student_verification_status_page.dart';

/// Staging-only account flow; ordinary app builds keep auth switched off.
class StagingStudentAccountPage extends StatefulWidget {
  const StagingStudentAccountPage({
    super.key,
    required this.httpsBaseUrl,
    this.onProfileChanged,
    this.onThemeChanged,
    this.darkMode = false,
  });

  final String httpsBaseUrl;
  final ValueChanged<StudentProfile?>? onProfileChanged;
  final ValueChanged<bool>? onThemeChanged;
  final bool darkMode;

  @override
  StagingStudentAccountPageState createState() =>
      StagingStudentAccountPageState();
}

class StagingStudentAccountPageState
    extends State<StagingStudentAccountPage> {
  // Disabled until backend FCM delivery, rotation and device QA are approved.
  static const bool pushEnabled = bool.fromEnvironment(
    'SMIUNOTES_ENABLE_NATIVE_PUSH', defaultValue: false,
  );
  late final StudentPushEnrollment push = StudentPushEnrollment(
    api: PushRegistrationApi(
      baseUrl: widget.httpsBaseUrl,
      enabled: pushEnabled,
    ),
  );

  Future<Uint8List?> loadOwnAvatar() async {
    final profile = runtime.coordinator.profile;
    if (profile?.avatarVersion == null) return null;
    return NativeAvatarApi(baseUrl: widget.httpsBaseUrl)
        .loadOwn(_currentVerifiedToken());
  }

  Future<void> signOutAllDevices() async {
    if (pushEnabled) {
      try {
        await push.disable(currentAccessToken: runtime.controller.accessToken);
      } catch (_) {
        // Even if remote FCM revoke is unavailable, secure session wipe
        // must still continue.
      }
    }
    await runtime.controller.signOutAll(runtime.sessionApi.revokeAll);
  }

  Future<bool> loadUpdatePreference() async {
    final data = await StudentNotificationPreferencesApi(
      baseUrl: widget.httpsBaseUrl).read(_currentVerifiedToken());
    if (data['notify_updates'] is! bool || data['notify_notes'] != false) {
      throw const FormatException('Invalid notification preferences.');
    }
    return data['notify_updates'] as bool;
  }

  Future<void> saveUpdatePreference(bool enabled) async {
    await StudentNotificationPreferencesApi(
      baseUrl: widget.httpsBaseUrl).save(_currentVerifiedToken(), enabled);
  }

  Future<void> enablePush() async {
    await push.enable(currentAccessToken: _currentVerifiedToken());
  }

  Future<void> disablePush() async {
    await push.disable(currentAccessToken: runtime.controller.accessToken);
  }

  final GlobalKey<StudentAccountGatewayState> _gatewayKey =
      GlobalKey<StudentAccountGatewayState>();

  Future<bool> promptStudentSignIn() async {
    if (!mounted) { return false; }
    if (runtime.coordinator.authenticated) return true;
    return await _gatewayKey.currentState?.promptSignIn() ?? false;
  }

  void openVerificationStatus() {
    final profile = runtime.coordinator.profile;
    if (!mounted || !runtime.coordinator.authenticated ||
        profile == null) { return; }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => StudentVerificationStatusPage(
        profile: profile,
        onOpenNativeCardVerification: profile.verificationStatus == 'pending'
            ? openNativeCardVerification : null,
      ),
    ));
  }

  late final StudentAuthRuntime runtime =
      StudentAuthRuntime.forStaging(httpsBaseUrl: widget.httpsBaseUrl);

  Future<void> openVerifiedNote() async {
    if (!runtime.coordinator.authenticated) return;
    final controller = TextEditingController();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Open note by ID (QA)'),
        content: TextField(
          key: const Key('qa-note-id'),
          controller: controller,
          decoration: const InputDecoration(labelText: 'Note UUID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || selected == null ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(selected)) {
      return;
    }
    final token = runtime.controller.accessToken;
    if (!runtime.coordinator.authenticated || token == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AuthenticatedNoteReaderPage(
        noteId: selected,
        accessToken: token,
        api: AuthenticatedReaderApi(baseUrl: widget.httpsBaseUrl),
      ),
    ));
  }

  /// Retrieve the current token for every request. Never retain a bearer
  /// captured when a route opens: sign-out/rotation may invalidate it.
  String _currentVerifiedToken() {
    final token = runtime.controller.accessToken;
    if (!mounted || !runtime.coordinator.authenticated || token == null) {
      throw StateError('Student sign-in required.');
    }
    return token;
  }

  /// Returns false if sign-in is needed; callers can open the Profile tab.
  bool openNotifications() {
    if (!runtime.coordinator.authenticated ||
        runtime.controller.accessToken == null) {
      return false;
    }
    final api = MobileNotificationApi(baseUrl: widget.httpsBaseUrl);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NotificationInboxPage(
        loader: () => api.loadOwn(_currentVerifiedToken()),
        markRead: (id) => api.markRead(_currentVerifiedToken(), id),
        clearOwn: () => api.clearOwn(_currentVerifiedToken()),
      ),
    ));
    return true;
  }

  late final NativeProfileSettingsApi settingsApi = NativeProfileSettingsApi(
    baseUrl: widget.httpsBaseUrl,
    tokenProvider: _currentVerifiedToken,
  );

  NativeStudentFormsApi get _forms => NativeStudentFormsApi(
    baseUrl: widget.httpsBaseUrl,
    tokenProvider: _currentVerifiedToken,
  );

  void openNativeCardVerification() {
    if (!mounted || !runtime.coordinator.authenticated) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NativeStudentCardFormPage(api: _forms),
    ));
  }

  void openNativeSupport() {
    if (!mounted || !runtime.coordinator.authenticated) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NativeSupportFormPage(api: _forms),
    ));
  }

  void openNativeContact() {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NativeContactFormPage(
        api: _forms, baseUrl: widget.httpsBaseUrl, signedIn: true,
      ),
    ));
  }

  void openNotificationPreferences() {
    if (!mounted || !runtime.coordinator.authenticated ||
        runtime.controller.accessToken == null) { return; }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NativeNotificationPreferencesPage(
        load: loadUpdatePreference,
        save: saveUpdatePreference,
      ),
    ));
  }

  /// Opens the reply composer only if a verified session still exists.
  Future<bool> openCommunityReply(String threadId) async {
    if (!mounted || !runtime.coordinator.authenticated ||
        runtime.controller.accessToken == null) {
      return false;
    }
    if (threadId.length != 36 ||
        !RegExp(r'^[0-9a-fA-F-]+').hasMatch(threadId)) {
      return false;
    }
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CommunityComposerPage(
          api: CommunityWriteApi(baseUrl: widget.httpsBaseUrl),
          tokenProvider: _currentVerifiedToken,
          threadId: threadId,
        ),
      ),
    );
    return posted == true;
  }

  /// Unfinished bookmark owned by the current authenticated student.
  Future<Map<String, dynamic>?> latestStudyNote() async {
    if (!mounted || !runtime.coordinator.authenticated ||
        runtime.controller.accessToken == null) {
      return null;
    }
    try {
      final result = await BookmarkApi(baseUrl: widget.httpsBaseUrl)
          .list(_currentVerifiedToken());
      final entries = result['items'];
      if (entries is! List) return null;
      for (final item in entries) {
        if (item is Map<String, dynamic> &&
            item['note_id'] is String && item['completed'] != true) {
          return item;
        }
      }
    } catch (_) {
      // No continue preview when offline or signed out.
    }
    return null;
  }

  void resumeStudyNote(String noteId) {
    if (!mounted || !runtime.coordinator.authenticated ||
        runtime.controller.accessToken == null ||
        noteId.length != 36 ||
        !RegExp(r'[0-9a-fA-F-]{36}').hasMatch(noteId)) {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AuthenticatedNoteReaderPage(
        noteId: noteId,
        accessToken: _currentVerifiedToken(),
        api: AuthenticatedReaderApi(baseUrl: widget.httpsBaseUrl),
      ),
    ));
  }

  OfflineNotesStore get offlineNotes =>
    OfflineNotesStore(baseUrl: widget.httpsBaseUrl);

  bool get canDownloadOffline {
    final profile = runtime.coordinator.profile;
    return runtime.coordinator.authenticated &&
      runtime.controller.accessToken != null &&
      profile?.verificationStatus == 'verified' &&
      profile?.accountStatus == 'active' &&
      profile?.profileId != null;
  }

  void openOfflineLibrary() {
    if (!mounted || !canDownloadOffline) return;
    final owner = runtime.coordinator.profile!.profileId!;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => OfflineLibraryPage(
        store: offlineNotes, owner: owner),
    ));
  }

  ReaderToolbarActions _studyActions(String noteId) {
    final api = BookmarkApi(baseUrl: widget.httpsBaseUrl);
    return ReaderToolbarActions(
      key: Key('study-toolbar-$noteId'),
      loadState: () async {
        final token = _currentVerifiedToken();
        final results = await Future.wait([
          api.list(token), api.listCompleted(token),
        ]);
        bool present(Map<String, dynamic> result) {
          final rows = result['items'];
          return rows is List && rows.any((item) =>
            item is Map && item['note_id'] == noteId);
        }
        return {'bookmarked': present(results[0]),
          'completed': present(results[1])};
      },
      toggleBookmark: (current) async {
        final result = current
          ? await api.remove(_currentVerifiedToken(), noteId)
          : await api.save(_currentVerifiedToken(), noteId);
        return result['ok'] == true;
      },
      toggleCompleted: (current) async {
        final result = current
          ? await api.uncomplete(_currentVerifiedToken(), noteId)
          : await api.complete(_currentVerifiedToken(), noteId);
        return result['ok'] == true;
      },
      download: canDownloadOffline ? (progress) async {
        if (!canDownloadOffline) {
          throw StateError('Verified Student Card required.');
        }
        await offlineNotes.save(
          owner: runtime.coordinator.profile!.profileId!,
          noteId: noteId,
          accessToken: _currentVerifiedToken(),
          onProgress: progress,
        );
      } : null,
    );
  }

  void openPublicNote(String noteId, {bool restricted = false}) {
    if (!mounted || !OfflineNotesStore.validId(noteId)) return;
    final signedIn = runtime.coordinator.authenticated &&
      runtime.controller.accessToken != null;
    if (restricted && !canDownloadOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Verify your Student Card to open this note.')));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => restricted
        ? AuthenticatedNoteReaderPage(
            noteId: noteId,
            accessToken: _currentVerifiedToken(),
            api: AuthenticatedReaderApi(baseUrl: widget.httpsBaseUrl),
            toolbarActions: signedIn ? _studyActions(noteId) : null,
          )
        : NoteReaderPage(
            noteId: noteId,
            api: const PublicFeedApi(),
            toolbarActions: signedIn ? _studyActions(noteId) : null,
          ),
    ));
  }

  void openSavedNotes() {
    if (!mounted || !runtime.coordinator.authenticated ||
        runtime.controller.accessToken == null) {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MyBookmarksPage(
        api: BookmarkApi(baseUrl: widget.httpsBaseUrl),
        currentAccessToken: _currentVerifiedToken,
      ),
    ));
  }

  Future<bool> saveNote(String noteId) async {
    if (!mounted || !runtime.coordinator.authenticated ||
        runtime.controller.accessToken == null) {
      return false;
    }
    try {
      final response = await BookmarkApi(baseUrl: widget.httpsBaseUrl)
          .save(_currentVerifiedToken(), noteId);
      return response['ok'] == true && response['bookmarked'] == true;
    } catch (_) {
      return false;
    }
  }

  void openCommunityComposer() {
    if (!runtime.coordinator.authenticated ||
        runtime.controller.accessToken == null) {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CommunityComposerPage(
        api: CommunityWriteApi(baseUrl: widget.httpsBaseUrl),
        tokenProvider: _currentVerifiedToken,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => StudentAccountGateway(
    key: _gatewayKey,
    api: MobileAuthApi(baseUrl: widget.httpsBaseUrl),
    challengeProvider: () => requestMobileTurnstile(
      context,
      httpsOrigin: widget.httpsBaseUrl,
    ),
    acceptAndVerify: runtime.coordinator.acceptAndVerify,
    restoreAndVerify: runtime.coordinator.restoreAndVerify,
    loadValidatedProfile: () => runtime.coordinator.profile,
    signOut: runtime.coordinator.signOut,
    signOutAll: signOutAllDevices,
    onLoadAvatar: loadOwnAvatar,
    profileSettingsApi: settingsApi,
    onRefreshProfile: runtime.coordinator.refreshValidatedProfile,
    onOpenVerifiedNote: openVerifiedNote,
    onCreateDiscussion: openCommunityComposer,
    onOpenNotifications: openNotifications,
    onOpenNotificationPreferences: openNotificationPreferences,
    onLoadUpdatePreference: loadUpdatePreference,
    onSaveUpdatePreference: saveUpdatePreference,
    onOpenNativeCardVerification: openNativeCardVerification,
    onOpenNativeSupport: openNativeSupport,
    onOpenNativeContact: openNativeContact,
    onOpenBookmarks: openSavedNotes,
    pushAvailable: pushEnabled,
    onEnablePush: pushEnabled ? enablePush : null,
    onDisablePush: pushEnabled ? disablePush : null,
    onLoadPushEnabled: pushEnabled ? () => push.isOptedIn : null,
    onProfileChanged: widget.onProfileChanged,
    onThemeChanged: widget.onThemeChanged,
    darkMode: widget.darkMode,
  );
}
