import 'screens/notification_inbox_page.dart';
import 'screens/native_catalogue_page.dart';
import 'screens/staging_student_account_page.dart';
import 'screens/student_profile_page.dart';
import 'screens/community_feed_page.dart';
import 'screens/public_feed_page.dart';
import 'screens/native_information_pages.dart';
import 'screens/native_public_content_page.dart';
import 'screens/native_student_forms.dart';
import 'services/native_student_forms_api.dart';
import 'screens/contributors_directory_page.dart';
import 'screens/support_dashboard_page.dart';
import 'models/student_profile.dart';
import 'widgets/profile_avatar.dart';
import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() => runApp(const SmiuNotesApp());

const Color archiveBlue = Color(0xFF183C68);
const Color ink = Color(0xFF102B4B);
const Color muted = Color(0xFF5C7188);

const TextTheme websiteTypography = TextTheme(
  displayLarge: TextStyle(fontFamily: 'SMIUSpaceGrotesk'),
  displayMedium: TextStyle(fontFamily: 'SMIUSpaceGrotesk'),
  displaySmall: TextStyle(fontFamily: 'SMIUSpaceGrotesk'),
  headlineLarge: TextStyle(fontFamily: 'SMIUSpaceGrotesk'),
  headlineMedium: TextStyle(fontFamily: 'SMIUSpaceGrotesk'),
  headlineSmall: TextStyle(fontFamily: 'SMIUSpaceGrotesk'),
  titleLarge: TextStyle(fontFamily: 'SMIUSpaceGrotesk'),
);


class SmiuNotesApp extends StatefulWidget {
  const SmiuNotesApp({super.key});
  @override
  State<SmiuNotesApp> createState() => _SmiuNotesAppState();
}

class _SmiuNotesAppState extends State<SmiuNotesApp> {
  static const _themeKey = 'smiunotes.theme.v1';
  static const _settings = FlutterSecureStorage();
  bool darkMode = true;

  @override
  void initState() {
    super.initState();
    _restoreTheme();
  }

  Future<void> _restoreTheme() async {
    try {
      final saved = await _settings.read(key: _themeKey);
      if (mounted && (saved == 'dark' || saved == 'light')) {
        setState(() => darkMode = saved == 'dark');
      }
    } catch (_) {
      // No unencrypted fallback; system theme remains usable.
    }
  }

  void _changeTheme(bool enabled) {
    setState(() => darkMode = enabled);
    _settings.write(key: _themeKey,
      value: enabled ? 'dark' : 'light').catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMIUNotes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: archiveBlue),
        scaffoldBackgroundColor: const Color(0xFFF0F5FA),
        fontFamily: 'SMIUInter',
        textTheme: websiteTypography,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF87B9F8),
          brightness: Brightness.dark,
          surface: const Color(0xFF101B2A),
        ).copyWith(
          primary: const Color(0xFF8EC5FF),
          onPrimary: const Color(0xFF09213C),
          primaryContainer: const Color(0xFF18395B),
          onPrimaryContainer: const Color(0xFFD9EAFD),
          secondary: const Color(0xFFACD7F7),
          surface: const Color(0xFF101E32),
          onSurface: const Color(0xFFEAF3FF),
          onSurfaceVariant: const Color(0xFFB7C9DE),
          outlineVariant: const Color(0xFF324862),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1420),
        fontFamily: 'SMIUInter',
        textTheme: websiteTypography,
      ),
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: AppShell(
        darkMode: darkMode,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.darkMode = false, this.onThemeChanged});
  final bool darkMode;
  final ValueChanged<bool>? onThemeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const bool stagingAuthEnabled = bool.fromEnvironment(
    'SMIUNOTES_ENABLE_STAGING_AUTH', defaultValue: false,
  );
  static const bool productionAuthEnabled = bool.fromEnvironment(
    'SMIUNOTES_ENABLE_PRODUCTION_AUTH', defaultValue: false,
  );
  static const bool accountAuthEnabled = stagingAuthEnabled || productionAuthEnabled;
  static const String stagingApiBase = String.fromEnvironment(
    'SMIUNOTES_API_BASE', defaultValue: '',
  );
  final GlobalKey<StagingStudentAccountPageState> _studentAccountKey =
      GlobalKey<StagingStudentAccountPageState>();
  int selectedIndex = 1;
  int _notesRefreshVersion = 0;
  int _updatesRefreshVersion = 0;

  void _selectTab(int index) {
    if (!mounted) return;
    setState(() {
      selectedIndex = index;
      if (index == 1) _notesRefreshVersion++;
      if (index == 2) _updatesRefreshVersion++;
    });
  }
  StudentProfile? _activeProfile;

  Future<void> _openInformation(BuildContext context, String kind) async {
    if ((kind == 'support' || kind == 'contact') &&
        stagingApiBase.isNotEmpty) {
      final account = _studentAccountKey.currentState;
      if (accountAuthEnabled &&
          account?.runtime.coordinator.authenticated == true) {
        if (kind == 'support') {
          account!.openNativeSupport();
        } else {
          account!.openNativeContact();
        }
        return;
      }
      final api = NativeStudentFormsApi(
        baseUrl: stagingApiBase, tokenProvider: null,
      );
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => kind == 'support'
          ? NativeSupportFormPage(api: api, signedIn: false)
          : NativeContactFormPage(api: api, baseUrl: stagingApiBase),
      ));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => kind == 'contributors'
        ? const ContributorsDirectoryPage()
        : kind == 'catalogue'
          ? const NativeCataloguePage()
          : const ['about', 'privacy', 'disclaimer'].contains(kind)
            ? NativePublicContentPage(kind: kind)
            : NativeInformationPage(kind: kind)));
  }
  static const labels = ['Notes', 'Updates', 'Study Room', 'Support'];
  static const icons = [
    Icons.menu_book_outlined,
    Icons.campaign_outlined,
    Icons.forum_outlined,
    Icons.volunteer_activism_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          const _Backdrop(),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Row(
                        children: [
                          Icon(Icons.auto_stories_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                          const SizedBox(width: 9),
                          InkWell(key: const Key('open-classic-home'), onTap: () => _selectTab(0), child: Text('SMIUNotes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface))),
                          if (_activeProfile != null) Padding(padding: const EdgeInsets.only(left: 7), child: Text('· ${_activeProfile!.department ?? 'Student'}', maxLines: 1, style: const TextStyle(fontSize: 10))),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Notifications',
                            onPressed: () {
                              if (accountAuthEnabled && stagingApiBase.isNotEmpty) {
                                if (_studentAccountKey.currentState?.openNotifications() == true) {
                                  return;
                                }
                                setState(() => selectedIndex = 5);
                                return;
                              }
                              Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => const NotificationInboxPage(),
                              ));
                            },
                            icon: Icon(Icons.notifications_none_rounded, color: Theme.of(context).colorScheme.primary),
                          ),
                          IconButton(
                            tooltip: 'Your profile',
                            key: const Key('header-profile'),
                            onPressed: () => _selectTab(5),
                            icon: ProfileAvatar(
                              name: _activeProfile?.studentName,
                              cacheKey: _activeProfile == null ? 'anonymous' : '${_activeProfile!.studentId}:${_activeProfile!.avatarVersion}',
                              size: 31,
                              imageLoader: _activeProfile?.avatarVersion == null ? null : () async => await _studentAccountKey.currentState?.loadOwnAvatar(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: selectedIndex,
                        children: [
                          _HomePage(
                            onOpenInformation: (kind) => _openInformation(context, kind),
                            onNavigate: _selectTab,
                            apiConfigured: stagingApiBase.isNotEmpty,
                            studentProfile: _activeProfile,
                            onOpenVerification: () => _studentAccountKey.currentState?.openVerificationStatus(),
                          ),
                          PublicFeedPage(
                            type: 'notes',
                            refreshVersion: _notesRefreshVersion,
                            canOpenRestricted: _activeProfile?.verificationStatus == 'verified',
                            onOpenNote: accountAuthEnabled && stagingApiBase.isNotEmpty
                              ? (id, restricted) => _studentAccountKey.currentState
                                  ?.openPublicNote(id, restricted: restricted)
                              : null,
                            onOpenOffline: _activeProfile?.verificationStatus == 'verified'
                              ? () => _studentAccountKey.currentState
                                  ?.openOfflineLibrary()
                              : null,
                            loadContinue: _activeProfile == null ? null : () async =>
                              await _studentAccountKey.currentState?.latestStudyNote(),
                            onResume: (noteId) =>
                              _studentAccountKey.currentState?.resumeStudyNote(noteId),
                            onSaveNote: (noteId) async {
                              if (!accountAuthEnabled || stagingApiBase.isEmpty) {
                                if (mounted) setState(() => selectedIndex = 5);
                                return false;
                              }
                              final account = _studentAccountKey.currentState;
                              if (account == null) {
                                if (mounted) setState(() => selectedIndex = 5);
                                return false;
                              }
                              final saved = await account.saveNote(noteId);
                              if (!saved && mounted &&
                                  !account.runtime.coordinator.authenticated) {
                                setState(() => selectedIndex = 5);
                              }
                              return saved;
                            },
                          ),
                          PublicFeedPage(type: 'updates',
                            refreshVersion: _updatesRefreshVersion),
                          CommunityFeedPage(
                            onAsk: () async {
                              if (!accountAuthEnabled || stagingApiBase.isEmpty) {
                                _selectTab(5);
                                return;
                              }
                              final state = _studentAccountKey.currentState;
                              if (state == null) { _selectTab(5); return; }
                              if (!await state.promptStudentSignIn() || !context.mounted) return;
                              if (state.runtime.coordinator.profile
                                  ?.verificationStatus != 'verified') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text(
                                    'Verify your Student Card before posting in Community.')));
                                return;
                              }
                              state.openCommunityComposer();
                            },
                            onReply: (threadId) async {
                              if (!accountAuthEnabled || stagingApiBase.isEmpty) {
                                return false;
                              }
                              final state = _studentAccountKey.currentState;
                              if (state == null) return false;
                              final authenticated = await state.promptStudentSignIn();
                              if (!authenticated || !context.mounted) return false;
                              if (state.runtime.coordinator.profile
                                  ?.verificationStatus != 'verified') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text(
                                    'Verify your Student Card before posting in Community.')),
                                );
                                return false;
                              }
                              return state.openCommunityReply(threadId);
                            },
                          ),
                          SupportDashboardPage(onOpenContributors: () => _openInformation(context, 'contributors'), onOpenSupport: () => _openInformation(context, 'support')),
                          if (accountAuthEnabled && stagingApiBase.isNotEmpty)
                            StagingStudentAccountPage(
                              key: _studentAccountKey,
                              httpsBaseUrl: stagingApiBase,
                              darkMode: widget.darkMode,
                              onThemeChanged: widget.onThemeChanged,
                              onProfileChanged: (profile) {
                                if (mounted) setState(() => _activeProfile = profile);
                              },
                            )
                          else
                            const StudentProfilePage(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(6, 0, 6, 4),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: _Glass(
              radius: 12,
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
              child: Row(
                children: List.generate(labels.length, (index) {
                  final tabIndex = index == 3 ? 4 : index + 1;
                  final active = selectedIndex == tabIndex;
                  return Expanded(
                    child: InkWell(
                      key: Key('tab-$tabIndex'),
                      borderRadius: BorderRadius.circular(9),
                      onTap: () => _selectTab(tabIndex),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icons[index], size: 18,
                                color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(labels[index], style: TextStyle(fontSize: 10, color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
              ? [const Color(0xFF07111F), const Color(0xFF102744), const Color(0xFF091728)]
              : [const Color(0xFFE8F3FF), const Color(0xFFF7F9FD), const Color(0xFFE6EFFB)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -135, right: -100, child: _Glow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A5A9D) : const Color(0xFF9CCCF8), size: 340)),
            Positioned(bottom: 40, left: -110, child: _Glow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF25457C) : const Color(0xFFB7C9F2), size: 310)),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
    child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.45))),
  );
}

class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.padding = const EdgeInsets.all(18), this.radius = 22});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(
            alpha: Theme.of(context).brightness == Brightness.dark ? 0.82 : 0.74),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 28, offset: const Offset(0, 10))],
        ),
        child: child,
      ),
    ),
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.onOpenInformation,
    required this.onNavigate,
    required this.apiConfigured,
    this.studentProfile,
    this.onOpenVerification,
  });
  final StudentProfile? studentProfile;
  final VoidCallback? onOpenVerification;
  final ValueChanged<int> onNavigate;
  final ValueChanged<String> onOpenInformation;
  final bool apiConfigured;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('home-page'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
      children: [
        Text('YOUR STUDENT COMPANION', style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(height: 10),
        Text('Everything SMIU,\nin one place.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.15, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 10),
        Text('Find notes, stay updated and connect with your university community.', style: TextStyle(fontSize: 14, height: 1.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Text(
          apiConfigured
              ? 'Explore public resources freely. Sign in for your personal library.'
              : 'M4 testing build • Preview mode: live content and student login are not configured.',
          key: const Key('testing-build-status'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
        ),
        if (studentProfile != null &&
            (studentProfile!.verificationStatus == 'pending' ||
             studentProfile!.verificationStatus == 'submitted')) ...[
          const SizedBox(height: 14),
          Card(
            key: const Key('home-verification-banner'),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.verified_user_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Student identity not verified',
                    style: TextStyle(fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimaryContainer))),
                ]),
                const SizedBox(height: 9),
                Text(studentProfile!.verificationStatus == 'submitted'
                  ? 'Your Student Card is awaiting review. Provisional access '
                    'lasts until the deadline set by SMIUNotes.'
                  : 'Your email is registered, but Student Card verification '
                    'is still pending. Complete it to retain access.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
                if (studentProfile!.verificationExpiresAt != null) ...[
                  const SizedBox(height: 8),
                  Text('Provisional access ends: '
                    '${studentProfile!.verificationExpiresAt!.day}/'
                    '${studentProfile!.verificationExpiresAt!.month}/'
                    '${studentProfile!.verificationExpiresAt!.year}',
                    key: const Key('home-verification-deadline'),
                    style: TextStyle(fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onPrimaryContainer)),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('home-open-verification'),
                  onPressed: onOpenVerification,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('View verification status'),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _Glass(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_stories_rounded, color: Theme.of(context).colorScheme.primary, size: 32),
              const SizedBox(height: 12),
              Text('Ready to learn?', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text('Explore study notes organised around your academic journey.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('explore-notes'),
                onPressed: () => onNavigate(1),
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary,
                     foregroundColor: Theme.of(context).colorScheme.onPrimary),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Explore notes'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        Text('Explore SMIUNotes', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 600;
            final items = [
              _QuickLink(icon: Icons.menu_book_outlined, title: 'Notes', caption: 'Study smarter', onTap: () => onNavigate(1)),
              _QuickLink(icon: Icons.view_list_outlined, title: 'Browse catalogue',
                caption: 'By department & semester',
                onTap: () => onOpenInformation('catalogue')),
              _QuickLink(icon: Icons.campaign_outlined, title: 'Updates', caption: 'Stay informed', onTap: () => onNavigate(2)),
              _QuickLink(icon: Icons.forum_outlined, title: 'Community', caption: 'Connect & discuss', onTap: () => onNavigate(3)),
              _QuickLink(icon: Icons.person_outline, title: 'Profile',
                caption: 'Your student space', onTap: () => onNavigate(5)),
              _QuickLink(icon: Icons.favorite_outline, title: 'Support',
                caption: 'Keep notes free',
                onTap: () => onOpenInformation('support')),
              _QuickLink(icon: Icons.mail_outline, title: 'Contact Us',
                caption: 'Talk to the team',
                onTap: () => onOpenInformation('contact')),
              _QuickLink(icon: Icons.diversity_3_outlined, title: 'Contributors',
                caption: 'Meet note creators',
                onTap: () => onOpenInformation('contributors')),
            ];
            return GridView.count(
              crossAxisCount: wide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: wide ? 1.25 : 1.25,
              children: items,
            );
          },
        ),
        const SizedBox(height: 20),

      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.title, required this.caption, required this.onTap});
  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(21),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: dark ? .58 : .64),
            scheme.surface.withValues(alpha: dark ? .93 : .86),
          ],
        ),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .85)),
        boxShadow: [
          BoxShadow(color: scheme.shadow.withValues(alpha: dark ? .14 : .07),
            blurRadius: 19, offset: const Offset(0, 7)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: scheme.primary, size: 23),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded, size: 16,
                    color: scheme.primary.withValues(alpha: .70)),
                ]),
                const SizedBox(height: 10),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5,
                    color: scheme.onSurface, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(caption, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, height: 1.15,
                    color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
