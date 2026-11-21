import '../services/authenticated_reader_api.dart';
import 'authenticated_note_reader_page.dart';
import '../services/community_write_api.dart';
import 'community_composer_page.dart';
import 'package:material_ui/material_ui.dart';

import '../services/mobile_auth_api.dart';
import '../services/mobile_turnstile.dart';
import '../services/student_auth_runtime.dart';
import 'student_account_gateway.dart';

/// Fully composed staging auth experience. Do not install this screen in the
/// default app until a device-accessible approved staging host is configured.
/// All sessions use secure OS storage, server refresh and live own-profile RPC.
class StagingStudentAccountPage extends StatefulWidget {
  const StagingStudentAccountPage({
    super.key,
    required this.httpsBaseUrl,
  });

  final String httpsBaseUrl;

  @override
  State<StagingStudentAccountPage> createState() =>
      _StagingStudentAccountPageState();
}

class _StagingStudentAccountPageState extends State<StagingStudentAccountPage> {
  late final StudentAuthRuntime runtime =
      StudentAuthRuntime.forStaging(httpsBaseUrl: widget.httpsBaseUrl);

  Future<void> openVerifiedNote() async {
    if (!runtime.coordinator.authenticated) return;
    final input = TextEditingController();
    final noteId = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Open note by ID (QA)'),
        content: TextField(
          controller: input,
          key: const Key('qa-note-id'),
          decoration: const InputDecoration(
            labelText: 'Note UUID',
            hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(input.text.trim()),
            child: const Text('Open'),
          ),
        ],
      ),
    );
    input.dispose();
    if (!mounted || noteId == null ||
        !RegExp(r'^[0-9a-fA-F-]{36}
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
    onCreateDiscussion: () {
      final token = runtime.controller.accessToken;
      if (!runtime.coordinator.authenticated || token == null) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CommunityComposerPage(
          api: CommunityWriteApi(baseUrl: widget.httpsBaseUrl),
          accessToken: token,
        ),
      ));
    },
  );
}
).hasMatch(noteId)) return;
    final token = runtime.controller.accessToken;
    if (!runtime.coordinator.authenticated || token == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AuthenticatedNoteReaderPage(
        noteId: noteId,
        accessToken: token,
        api: AuthenticatedReaderApi(baseUrl: widget.httpsBaseUrl),
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
    onCreateDiscussion: () {
      final token = runtime.controller.accessToken;
      if (!runtime.coordinator.authenticated || token == null) return;
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CommunityComposerPage(
          api: CommunityWriteApi(baseUrl: widget.httpsBaseUrl),
          accessToken: token,
        ),
      ));
    },
  );
}
