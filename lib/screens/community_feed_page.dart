import 'community_thread_page.dart';
import 'package:material_ui/material_ui.dart';
import '../services/public_feed_api.dart';

/// Public discussions only. Posting requires a verified student session.
class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key, this.api = const PublicFeedApi()});
  final PublicFeedApi api;
  @override
  State<CommunityFeedPage> createState() => _CommunityFeedPageState();
}

class _CommunityFeedPageState extends State<CommunityFeedPage> {
  final query = TextEditingController();
  List<dynamic> threads = [];
  int page = 1;
  bool loading = false, hasMore = false;
  int _requestGeneration = 0;
  String category = '', error = '';
  @override
  void initState() { super.initState(); load(); }
  @override
  void didUpdateWidget(covariant CommunityFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      page = 1;
      category = '';
      query.clear();
      load();
    }
  }
  @override
  void dispose() { query.dispose(); super.dispose(); }

  Future<void> load() async {
    final generation = ++_requestGeneration;
    setState(() { loading = true; error = ''; });
    try {
      final data = await widget.api.fetch(
        'community', search: query.text, page: page, category: category,
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        threads = (data['items'] as List<dynamic>?) ?? [];
        hasMore = data['has_more'] == true;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        threads = [];
        error = 'Community feed is unavailable. Retry after staging deployment.';
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => loading = false);
      }
    }
  }

  void apply() { page = 1; load(); }

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('community-feed'),
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
    children: [
      const Text('The study room', style: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF102B4B),
      )),
      const SizedBox(height: 10),
      const Text('Read student discussions. Sign-in and posting are coming later.'),
      const SizedBox(height: 18),
      TextField(
        controller: query,
        onSubmitted: (_) => apply(),
        decoration: InputDecoration(
          hintText: 'Search discussions',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            tooltip: 'Search discussions', onPressed: apply,
            icon: const Icon(Icons.arrow_forward)),
          border: const OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        for (final entry in const [
          ('', 'All'), ('questions', 'Questions'),
          ('study', 'Study'), ('announcements', 'Announcements'),
        ])
          ChoiceChip(
            label: Text(entry.$2),
            selected: category == entry.$1,
            onSelected: (_) { category = entry.$1; apply(); },
          ),
      ]),
      const SizedBox(height: 18),
      if (loading) const Center(child: CircularProgressIndicator())
      else if (error.isNotEmpty) ...[
        Text(error, key: const Key('community-error')),
        OutlinedButton.icon(
          onPressed: load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry')),
      ] else if (threads.isEmpty) const Text('No public discussions found.')
      else ...[
        for (final raw in threads)
          if (raw is Map<String, dynamic>)
            Card(
              color: Colors.white.withValues(alpha: 0.85),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Text(raw['title']?.toString() ?? 'Discussion',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(raw['preview']?.toString() ?? ''),
                    const SizedBox(height: 8),
                    Text(
                      "${raw['author_name'] ?? 'Student'} · ${raw['replies'] ?? 0} replies",
                      style: const TextStyle(fontSize: 12)),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => CommunityThreadPage(
                      threadId: raw['id']?.toString() ?? '',
                      api: widget.api,
                    ),
                  ));
                },
              ),
            ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          OutlinedButton(
            onPressed: page > 1 ? () { page--; load(); } : null,
            child: const Text('Previous')),
          Text('Page $page'),
          OutlinedButton(
            onPressed: hasMore ? () { page++; load(); } : null,
            child: const Text('Next')),
        ]),
      ],
    ],
  );
}
