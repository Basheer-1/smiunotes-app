import 'package:material_ui/material_ui.dart';
import '../services/external_link_opener.dart';

const _brand = Color(0xFF183C68);

class NativeInformationPage extends StatelessWidget {
  const NativeInformationPage({super.key, required this.kind,
    this.opener = const ExternalLinkOpener()});
  final String kind;
  final ExternalLinkOpener opener;
  bool get support => kind == 'support';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(support ? 'Support SMIUNotes' : 'Contact Us')),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                colors.primary, const Color(0xFF4775AB),
              ]),
              borderRadius: BorderRadius.circular(26),
            ),
            padding: const EdgeInsets.all(25),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(support ? Icons.favorite_rounded : Icons.mark_email_read_rounded,
                  color: Colors.white, size: 34),
                const SizedBox(height: 18),
                Text(support ? 'Keep learning free.' : 'We are here to help.',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
                const SizedBox(height: 12),
                Text(support
                  ? 'SMIUNotes is a student-maintained project. Your optional support helps keep notes and learning resources available.'
                  : 'Found an issue, need help with your account, or have a suggestion? Get in touch with the student team.',
                  style: const TextStyle(color: Colors.white, height: 1.55)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (support) ...[
            _InfoCard(
              icon: Icons.volunteer_activism_outlined,
              title: 'Always voluntary',
              content: 'No minimum contribution, no locked notes, and no academic privileges for supporters. SMIUNotes stays free.',
            ),
            _InfoCard(
              icon: Icons.verified_user_outlined,
              title: 'Secure payment confirmation',
              content: 'Bank transfer receipts are verified by the team. Use the official support form to submit the receipt securely.',
            ),
          ] else ...[
            _InfoCard(
              icon: Icons.support_agent_outlined,
              title: 'Questions & corrections',
              content: 'Report a notes issue, suggest improvements or ask about contributing.',
            ),
            _InfoCard(
              icon: Icons.privacy_tip_outlined,
              title: 'Account and privacy support',
              content: 'Students can request verification, recovery or data-related assistance through the secure contact form.',
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            key: Key(support ? 'native-support-action' : 'native-contact-action'),
            onPressed: () async {
              try {
                await opener.openHttps(support
                  ? 'https://smiunotes.com/support'
                  : 'https://smiunotes.com/contact');
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Unable to open the secure form. Try again.'),
                ));
              }
            },
            icon: Icon(support ? Icons.favorite_outline : Icons.send_outlined),
            label: Text(support ? 'Continue to secure support form'
                : 'Continue to secure contact form'),
            style: FilledButton.styleFrom(
              backgroundColor: _brand, foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Independent student-run resource, not an official SMIU service.',
            style: TextStyle(fontSize: 12, height: 1.5),
            textAlign: TextAlign.center),
        ]),
      )),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.content});
  final IconData icon;
  final String title, content;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    elevation: 0,
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(height: 1.5)),
        ])),
      ]),
    ),
  );
}
