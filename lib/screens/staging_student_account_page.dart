import 'package:material_ui/material_ui.dart';

import '../services/authenticated_reader_api.dart';
import '../services/community_write_api.dart';
import '../services/mobile_auth_api.dart';
import '../services/mobile_notification_api.dart';
import '../services/push_registration_api.dart';
import '../services/student_push_enrollment.dart';
import 'notification_inbox_page.dart';
import '../services/mobile_turnstile.dart';
import '../services/student_auth_runtime.dart';
import 'authenticated_note_reader_page.dart';
import 'community_composer_page.dart';
import 'student_account_gateway.dart';

/// Staging-only account flow; ordinary app builds keep auth switched off.
class StagingStudentAccountPage extends StatefulWidget {
  const StagingStudentAccountPage({
    super.key,
    required this.httpsBaseUrl,
  });

  final String httpsBaseUrl;

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

  Future<void> enablePush() async {
    await push.enable(currentAccessToken: _currentVerifiedToken());
  }

  Future<void> disablePush() async {
    await push.disable(currentAccessToken: runtime.controller.accessToken);
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

  /// Open a reply composer only for a currently verified student.
  /// Returns false for guests; the thread remains publicly readable.
  Future<bool> openCommunityReply(String threadId) async {
    if (!mounted || !runtime.coordinator.authenticated ||
        runtime.controller.accessToken == null) return false;
    if (!RegExp(r'^[0-9a-fA-F-]{36}

  @override
  Widget build(BuildContext context) => StudentAccountGateway(
    api: MobileAuthApi(baseUrl: widget.httpsBaseUrl),
    challengeProvider: () => requestMobileTurnstile(
      context,
      httpsOrigin: widget.httpsBaseUrl,
    ),
    acceptAndVerify: runtime.coordinator.acceptAndVerify,
    restoreAndVerify: runtime.coordinator.restoreAndVerify,
    loadValidatedProfile: () => runtime.coordinator.profile,
    signOut: runtime.coordinator.signOut,
    onOpenVerifiedNote: openVerifiedNote,
    onCreateDiscussion: openCommunityComposer,
    onOpenNotifications: openNotifications,
    pushAvailable: pushEnabled,
    onEnablePush: pushEnabled ? enablePush : null,
    onDisablePush: pushEnabled ? disablePush : null,
    onLoadPushEnabled: pushEnabled ? () => push.isOptedIn : null,
  );
}
).hasMatch(threadId)) return false;
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

  void openCommunityComposer() {
    if (!runtime.coordinator.authenticated ||
        runtime.controller.accessToken == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CommunityComposerPage(
        api: CommunityWriteApi(baseUrl: widget.httpsBaseUrl),
        tokenProvider: _currentVerifiedToken,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => StudentAccountGateway(
    api: MobileAuthApi(baseUrl: widget.httpsBaseUrl),
    challengeProvider: () => requestMobileTurnstile(
      context,
      httpsOrigin: widget.httpsBaseUrl,
    ),
    acceptAndVerify: runtime.coordinator.acceptAndVerify,
    restoreAndVerify: runtime.coordinator.restoreAndVerify,
    loadValidatedProfile: () => runtime.coordinator.profile,
    signOut: runtime.coordinator.signOut,
    onOpenVerifiedNote: openVerifiedNote,
    onCreateDiscussion: openCommunityComposer,
    onOpenNotifications: openNotifications,
    pushAvailable: pushEnabled,
    onEnablePush: pushEnabled ? enablePush : null,
    onDisablePush: pushEnabled ? disablePush : null,
    onLoadPushEnabled: pushEnabled ? () => push.isOptedIn : null,
  );
}
