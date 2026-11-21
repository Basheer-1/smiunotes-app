import 'screens/community_feed_page.dart';
import 'screens/public_feed_page.dart';
import 'dart:ui';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const SmiuNotesApp());

const Color archiveBlue = Color(0xFF183C68);
const Color ink = Color(0xFF102B4B);
const Color muted = Color(0xFF5C7188);

class SmiuNotesApp extends StatelessWidget {
  const SmiuNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMIUNotes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: archiveBlue),
        scaffoldBackgroundColor: const Color(0xFFF0F5FA),
        fontFamily: 'Roboto',
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selectedIndex = 0;
  static const labels = ['Home', 'Notes', 'Updates', 'Community', 'Profile'];
  static const icons = [
    Icons.home_outlined,
    Icons.menu_book_outlined,
    Icons.campaign_outlined,
    Icons.forum_outlined,
    Icons.person_outline,
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
                constraints: const BoxConstraints(maxWidth: 940),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_stories_rounded, color: archiveBlue, size: 28),
                          const SizedBox(width: 9),
                          const Text('SMIUNotes', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: ink)),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Notifications (coming soon)',
                            onPressed: () => _comingSoon(context, 'Notifications'),
                            icon: const Icon(Icons.notifications_none_rounded, color: archiveBlue),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: selectedIndex,
                        children: [
                          _HomePage(onNavigate: (index) => setState(() => selectedIndex = index)),
                          const PublicFeedPage(type: 'notes'),
                          const PublicFeedPage(type: 'updates'),
                          const CommunityFeedPage(),
                          const _FeaturePage(
                            icon: Icons.person_outline,
                            title: 'Your profile',
                            subtitle: 'A personalised space for your SMIUNotes experience.',
                            feature: 'Secure student sign-in is coming in M2.',
                          ),
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
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: _Glass(
              radius: 26,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: List.generate(labels.length, (index) {
                  final active = selectedIndex == index;
                  return Expanded(
                    child: InkWell(
                      key: Key('tab-$index'),
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => selectedIndex = index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icons[index], size: 23, color: active ? archiveBlue : muted),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(labels[index], style: TextStyle(fontSize: 11, color: active ? archiveBlue : muted, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
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

void _comingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$feature will be available in a future milestone.')),
  );
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F3FF), Color(0xFFF7F9FD), Color(0xFFE6EFFB)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -135, right: -100, child: _Glow(color: const Color(0xFF9CCCF8), size: 340)),
            Positioned(bottom: 40, left: -110, child: _Glow(color: const Color(0xFFB7C9F2), size: 310)),
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
    child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.65))),
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
          color: Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.87), width: 1.2),
          boxShadow: [BoxShadow(color: archiveBlue.withValues(alpha: 0.07), blurRadius: 28, offset: const Offset(0, 10))],
        ),
        child: child,
      ),
    ),
  );
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('home-page'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
      children: [
        const Text('YOUR STUDENT COMPANION', style: TextStyle(fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800, color: archiveBlue)),
        const SizedBox(height: 10),
        const Text('Everything SMIU,\nin one place.', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.15, color: ink)),
        const SizedBox(height: 10),
        const Text('Find notes, stay updated and connect with your university community.', style: TextStyle(fontSize: 14, height: 1.5, color: muted)),
        const SizedBox(height: 24),
        _Glass(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_stories_rounded, color: archiveBlue, size: 32),
              const SizedBox(height: 12),
              const Text('Ready to learn?', style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              const Text('Explore study notes organised around your academic journey.', style: TextStyle(color: muted, height: 1.5)),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('explore-notes'),
                onPressed: () => onNavigate(1),
                style: FilledButton.styleFrom(backgroundColor: archiveBlue, foregroundColor: Colors.white),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Explore notes'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        const Text('Explore SMIUNotes', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 600;
            final items = [
              _QuickLink(icon: Icons.menu_book_outlined, title: 'Notes', caption: 'Study smarter', onTap: () => onNavigate(1)),
              _QuickLink(icon: Icons.campaign_outlined, title: 'Updates', caption: 'Stay informed', onTap: () => onNavigate(2)),
              _QuickLink(icon: Icons.forum_outlined, title: 'Community', caption: 'Connect & discuss', onTap: () => onNavigate(3)),
              _QuickLink(icon: Icons.person_outline, title: 'Profile', caption: 'Your student space', onTap: () => onNavigate(4)),
            ];
            return GridView.count(
              crossAxisCount: wide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: wide ? 1.25 : 1.45,
              children: items,
            );
          },
        ),
        const SizedBox(height: 20),
        const Text('M1 • UI preview only — no live student data', style: TextStyle(color: muted, fontSize: 11)),
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
  Widget build(BuildContext context) => _Glass(
    padding: const EdgeInsets.all(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: archiveBlue, size: 27),
          const SizedBox(height: 9),
          Text(title, style: const TextStyle(fontSize: 14, color: ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(caption, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 11, color: muted)),
        ],
      ),
    ),
  );
}

class _FeaturePage extends StatelessWidget {
  const _FeaturePage({required this.icon, required this.title, required this.subtitle, required this.feature});
  final IconData icon;
  final String title;
  final String subtitle;
  final String feature;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 112),
    children: [
      const Text('SMIUNOTES', style: TextStyle(letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w800, color: archiveBlue)),
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w900, color: ink)),
      const SizedBox(height: 9),
      Text(subtitle, style: const TextStyle(color: muted, height: 1.5)),
      const SizedBox(height: 26),
      _Glass(
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 42),
        child: Column(
          children: [
            Icon(icon, size: 54, color: archiveBlue),
            const SizedBox(height: 17),
            const Text('Coming soon', style: TextStyle(fontSize: 21, color: ink, fontWeight: FontWeight.w800)),
            const SizedBox(height: 9),
            Text(feature, textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.5)),
          ],
        ),
      ),
    ],
  );
}
