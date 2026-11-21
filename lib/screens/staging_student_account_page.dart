import 'package:material_ui/material_ui.dart';

import '../services/authenticated_reader_api.dart';
import '../services/community_write_api.dart';
import '../services/mobile_auth_api.dart';
import '../services/mobile_notification_api.dart';
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

  /// Returns false if sign-in is needed; callers can open the Profile tab.
  bool openNotifications() {
    final token = runtime.controller.accessToken;
    if (!runtime.coordinator.authenticated || token == null) return false;
    final api = MobileNotificationApi(baseUrl: widget.httpsBaseUrl);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NotificationInboxPage(
        loader: () => api.loadOwn(token),
        markRead: (id) => api.markRead(token, id),
        clearOwn: () => api.clearOwn(token),
      ),
    ));
    return true;
  }

  void openCommunityComposer() {
    final token = runtime.controller.accessToken;
    if (!runtime.coordinator.authenticated || token == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CommunityComposerPage(
        api: CommunityWriteApi(baseUrl: widget.httpsBaseUrl),
        accessToken: token,
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
  );
}
