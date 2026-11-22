import 'package:material_ui/material_ui.dart';
import 'dart:typed_data';
import '../models/student_profile.dart';
import '../services/native_avatar_api.dart';

import '../services/authenticated_reader_api.dart';
import '../services/community_write_api.dart';
import '../services/bookmark_api.dart';
import '../services/mobile_auth_api.dart';
import '../services/mobile_notification_api.dart';
import '../services/mobile_preferences_api.dart';
import '../services/native_student_forms_api.dart';
import 'native_student_forms.dart';
import 'native_notification_preferences_page.dart';
import '../services/push_registration_api.dart';
import '../services/student_push_enrollment.dart';
import 'notification_inbox_page.dart';
import '../services/mobile_turnstile.dart';
import '../services/student_auth_runtime.dart';
import 'authenticated_note_reader_page.dart';
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
        api: MobilePreferencesApi(baseUrl: widget.httpsBaseUrl),
        currentAccessToken: _currentVerifiedToken,
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
    onOpenVerifiedNote: openVerifiedNote,
    onCreateDiscussion: openCommunityComposer,
    onOpenNotifications: openNotifications,
    onOpenNotificationPreferences: openNotificationPreferences,
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
