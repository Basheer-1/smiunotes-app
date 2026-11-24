import 'package:material_ui/material_ui.dart';
import '../services/contributors_api.dart';

/// Compact reference-style support surface. Data comes from the existing
/// public contributors endpoint, never from hard-coded names or counts.
class SupportDashboardPage extends StatefulWidget {
  const SupportDashboardPage({
    super.key,
    required this.onOpenContributors,
    required this.onOpenSupport,
    this.api = const ContributorsApi(),
  });

  final VoidCallback onOpenContributors;
  final VoidCallback onOpenSupport;
  final ContributorsApi api;

  @override
  State<SupportDashboardPage> createState() => _SupportDashboardPageState();
}

class _SupportDashboardPageState extends State<SupportDashboardPage> {
  bool showContributors = true, loading = true;
  String? error;
  List<Map<String, dynamic>> boards = [];
  int generation = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    generation++;
    super.dispose();
  }

  Future<void> load() async {
    final request = ++generation;
    setState(() { loading = true; error = null; });
    try {
      final result = await widget.api.fetch();
      if (!mounted || request != generation) return;
      setState(() {
        boards = (result['leaderboards'] is List
            ? result['leaderboards'] as List : const [])
            .whereType<Map<String, dynamic>>().toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted || request != generation) return;
      setState(() { loading = false; error = 'Unable to load contributors.'; });
    }
  }

  Widget _panel({required Widget child}) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF172738),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF263B50)),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xFFE4EFFB);
    const secondary = Color(0xFF9BB2C7);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        key: const Key('support-dashboard'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF172738),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(children: [
              for (final entry in [(true, 'Contributors'), (false, 'Support')])
                Expanded(child: InkWell(
                  key: Key(entry.$1 ? 'support-contributors-tab' : 'support-donate-tab'),
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => setState(() => showContributors = entry.$1),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: showContributors == entry.$1
                          ? const Color(0xFF396B87) : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(entry.$2, style: const TextStyle(
                      color: foreground, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                )),
            ]),
          ),
          const SizedBox(height: 22),
          if (showContributors) ...[
            Row(children: [
              const Expanded(child: Text('Department Top 10', style:
                TextStyle(color: foreground, fontWeight: FontWeight.w800, fontSize: 14))),
              TextButton(onPressed: widget.onOpenContributors,
                child: const Text('View all')),
            ]),
            if (loading) const Center(child: CircularProgressIndicator())
            else if (error != null) ...[
              Text(error!, style: const TextStyle(color: secondary)),
              TextButton(onPressed: load, child: const Text('Retry')),
            ] else if (boards.isEmpty)
              _panel(child: const Text('No contributor rankings available yet.',
                style: TextStyle(color: secondary)))
            else
              for (final board in boards) ...[
                Padding(padding: const EdgeInsets.only(top: 10, bottom: 7),
                  child: Row(children: [
                    Expanded(child: Text(
                      board['name']?.toString() ?? 'Department',
                      style: const TextStyle(color: foreground,
                        fontWeight: FontWeight.w800))),
                    Text('${(board['leaders'] is List ? board['leaders'] as List : const []).length} contributors',
                      style: const TextStyle(color: secondary, fontSize: 11)),
                  ])),
                _panel(child: Column(children: [
                  for (final raw in (board['leaders'] is List
                        ? board['leaders'] as List : const []))
                    if (raw is Map<String, dynamic>)
                      Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(children: [
                          SizedBox(width: 28, child: Text(
                            '#${raw['rank'] ?? '–'}',
                            style: const TextStyle(color: secondary, fontSize: 12))),
                          CircleAvatar(radius: 15,
                            backgroundColor: const Color(0xFF315C77),
                            child: Text((raw['name']?.toString().isNotEmpty == true)
                              ? raw['name'].toString()[0].toUpperCase() : '?',
                              style: const TextStyle(color: foreground, fontSize: 12))),
                          const SizedBox(width: 8),
                          Expanded(child: Text(raw['name']?.toString() ?? 'Contributor',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: foreground,
                              fontSize: 12, fontWeight: FontWeight.w700))),
                          Text('${raw['notes'] ?? 0} notes',
                            style: const TextStyle(color: secondary, fontSize: 11)),
                        ])),
                ])),
              ],
            const SizedBox(height: 18),
            _panel(child: Row(children: [
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Share your course notes', style: TextStyle(
                    color: foreground, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Help classmates prepare for exams.',
                    style: TextStyle(color: secondary, fontSize: 12)),
                ],
              )),
              FilledButton(onPressed: widget.onOpenContributors,
                child: const Text('Explore')),
            ])),
          ] else ...[
            const Text('Support SMIUNotes', style: TextStyle(
              color: foreground, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _panel(child: const Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keep study resources free for everyone.',
                  style: TextStyle(color: foreground, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('Your support helps maintain the student platform.',
                  style: TextStyle(color: secondary)),
              ],
            )),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: widget.onOpenSupport,
              icon: const Icon(Icons.favorite_outline),
              label: const Text('Open support form'),
            ),
          ],
        ],
      ),
    );
  }
}
