import 'package:material_ui/material_ui.dart';
import 'native_information_pages.dart';

/// Native, selectable public information: no WebView, browser or login required.
/// Copy is based on the published SMIUNotes public information pages.
class NativePublicContentPage extends StatelessWidget {
  const NativePublicContentPage({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final info = _content[kind] ?? _content['about']!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(info.title)),
      body: SafeArea(
        child: ListView(
          key: Key('native-public-content-$kind'),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 38),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(colors: [
                  colors.primary, const Color(0xFF4775AB),
                ]),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(info.icon, size: 32, color: Colors.white),
                const SizedBox(height: 16),
                Text(info.title, style: const TextStyle(
                  color: Colors.white, fontSize: 27,
                  height: 1.2, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text(info.intro, style: const TextStyle(
                  color: Colors.white, height: 1.55, fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 17),
            for (final section in info.sections)
              Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(19),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(section.title, style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
                      const SizedBox(height: 9),
                      SelectableText(section.body, style: TextStyle(
                        color: colors.onSurfaceVariant, height: 1.6, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            if (kind != 'about')
              OutlinedButton.icon(
                key: Key('public-$kind-contact'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) =>
                    const NativeInformationPage(kind: 'contact'))),
                icon: const Icon(Icons.mail_outline),
                label: const Text('Contact the team'),
              ),
            const SizedBox(height: 10),
            Text(
              'SMIUNotes is an independent student project, not an official SMIU service.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Section {
  const _Section(this.title, this.body);
  final String title;
  final String body;
}

class _PageContent {
  const _PageContent(this.title, this.intro, this.icon, this.sections);
  final String title, intro;
  final IconData icon;
  final List<_Section> sections;
}

// Keep these consumer-facing disclosures aligned with the website's
// /about, /privacy and /disclaimer when updating those website pages.
const Map<String, _PageContent> _content = {
  'about': _PageContent(
    'About SMIUNotes',
    'Free educational notes, organized for students at Sindh Madressatul Islam University (SMIU).',
    Icons.auto_stories_outlined,
    [
      _Section('Made for learning',
        'SMIUNotes helps students find self-written course notes by department, semester and subject. Our aim is to make revision easier and useful knowledge easier to share.'),
      _Section('Student contributions, reviewed',
        'Approved contributors upload their own notes. Drafts stay private while page images are prepared, and administrators review notes before publishing. Anyone can browse and read published notes. Sign in with Student ID and Email OTP to save notes, track progress or apply to contribute. Community participation and contributor access require Student Card verification.'),
      _Section('Independent and unofficial',
        'SMIUNotes is an independent student project. It is not an official SMIU website and is not affiliated with or endorsed by the university. Course references help students organize their study materials.'),
      _Section('Help improve the collection',
        'Want to contribute self-written notes or suggest a correction? Contact the team. Please share only material you have permission to provide.'),
    ],
  ),
  'disclaimer': _PageContent(
    'Disclaimer',
    'SMIUNotes is an independent, unofficial educational project for students. It is not affiliated with or endorsed by SMIU.',
    Icons.gavel_outlined,
    [
      _Section('Use notes as study support',
        'Notes may contain mistakes or become outdated. Check important information against your lecturer’s guidance, official course materials and current syllabus. We cannot guarantee completeness, exam coverage, grades or results.'),
      _Section('Respect authors and copyright',
        'Contributors should submit self-written notes and material they have permission to share. Reading access does not transfer copyright or grant permission to republish or sell the material. The online viewer discourages casual copying, but cannot prevent screenshots or all forms of capture.'),
      _Section('Corrections and takedown requests',
        'Use Contact Us to report a problem. For copyright requests, select “Copyright or takedown request” and include the note link, a description of the affected work, and enough information for review. Do not include sensitive documents in the form.'),
    ],
  ),
  'privacy': _PageContent(
    'Privacy notice',
    'Published notes and community discussions are publicly readable. Accounts are used for bookmarks, progress, contributions and participation in discussions.',
    Icons.privacy_tip_outlined,
    [
      _Section('Student verification and profile',
        'We keep an approved directory of Student IDs and names. Registration verifies control of your email, not ownership of a Student ID. Someone who knows an unclaimed approved ID may claim it using an email they control. Use only your own ID; disputes require independent administrator review through Account Recovery. Your verified email and Student ID are shown only in your signed-in profile and authorized administrative workflows. Your verified name can appear beside published contributions, community posts and opt-in supporter entries.'),
      _Section('Student Card evidence retention',
        'Students may submit an image of their Student Card. The face photograph may be covered if identifying details stay readable. Card images stay private while awaiting review; after approval or rejection the application deletes the image from Storage while preserving the review decision and history. Failed cleanup can be retried by authorized administrators. Provider backups may follow separate retention rules.'),
      _Section('Optional website support',
        'Support payments are voluntary bank transfers made through your own financial provider; SMIUNotes does not debit accounts. A payment claim stores selected method, amount, transfer reference, time, review status, optional message and a verified account identity or guest contact details. Authorized administrators verify bank records before confirming a claim. Unconfirmed claims are not counted as received. Public supporter name, department, amount and ranking appear only with the relevant consent. Financial audit records may be retained, and no automatic deletion deadline is configured. Support does not affect access to notes.'),
      _Section('Contact messages',
        'The contact form collects name, email, selected topic and message for the team to review and respond. Messages are stored privately and are accessible to authorized administrators, not visitors or ordinary contributors. Sending a message does not subscribe you to marketing.'),
      _Section('Student verification',
        'Approved student directory data, OTP-verified self-registered emails and session grants are protected. Email OTP confirms mailbox control, not ownership of a Student ID. First successful registration may claim an unclaimed ID. Disputes require administrator review. Signing out all devices revokes reader grants. Email and hosting providers process necessary technical and delivery data.'),
      _Section('Member notifications',
        'Signed-in students and administrators receive private in-app account and verification notifications. Contents, read state and timestamps are restricted to authorized accounts. Guests cannot view private inboxes. There is currently no automatic notification expiry date.'),
      _Section('Staff accounts and notes',
        'Administrators and contributors authenticate with Student ID and Email OTP. Staff roles protect access and note ownership. Original PDFs and drafts remain private. Published metadata is public; published note pages use short-lived reading access.'),
      _Section('Essential storage and service requests',
        'Web student verification and staff login use HttpOnly session cookies. Theme preferences may be stored locally. The website does not add advertising trackers. Infrastructure providers can process technical request logs.'),
      _Section('Spam prevention',
        'Contact forms use Cloudflare Turnstile, validation, a hidden bot field, timing checks and sending limits. Counters include hashes of normalized sender email and a site-wide count; a hash does not guarantee anonymity. These counters do not store visitor IP addresses. Cloudflare processes browser and technical signals for verification.'),
      _Section('Retention and deletion',
        'Messages are retained while handled and can be permanently deleted by administrators. No automatic message-expiry schedule currently exists. Rate-limit counters are cleaned during subsequent submissions. To request access, correction or deletion, use Contact Us and select “Privacy or deletion request”. The team may verify identity before acting; provider logs and backups follow their own retention rules.'),
    ],
  ),
};
