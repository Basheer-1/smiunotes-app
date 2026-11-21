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
