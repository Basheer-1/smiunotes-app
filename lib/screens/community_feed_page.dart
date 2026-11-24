import 'community_thread_page.dart';
import 'package:material_ui/material_ui.dart';
import '../services/public_feed_api.dart';

/// Public discussions only. Posting requires a verified student session.
class CommunityFeedPage extends StatefulWidget {
  const CommunityFeedPage({super.key, this.api = const PublicFeedApi(), this.onReply, this.onAsk});
  final PublicFeedApi api;
  final Future<bool> Function(String threadId)? onReply;
  final Future<void> Function()? onAsk;
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
  String topic = '';
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
        'community', search: [query.text.trim(), if (topic.isNotEmpty) topic].where((value) => value.isNotEmpty).join(' '), page: page, category: category,
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
        error = 'Unable to load discussions. Check your connection and retry.';
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => loading = false);
      }
    }
  }

  void apply() { page = 1; load(); }

  String friendlyTime(Object? value) {
    final dt = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (dt == null) return '';
    return '${dt.day}/${dt.month} · ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
    key: const Key('community-feed'),
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 95),
    children: [
      Text('Study Room', style: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      )),
      const SizedBox(height: 8),
      TextField(
        key: const Key('community-search'),
        maxLength: 100,
        controller: query,
        onSubmitted: (_) => apply(),
        decoration: InputDecoration(
          hintText: 'Search study questions...',
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
          ('', 'Past Papers'), ('study', 'Study Tips'),
        ])
          ChoiceChip(
            label: Text(entry.$2),
            selected: category == entry.$1 && topic == (entry.$2 == 'Past Papers' ? 'past papers' : entry.$2 == 'Study Tips' ? 'tips' : ''),
            onSelected: (_) { category = entry.$1; topic = entry.$2 == 'Past Papers' ? 'past papers' : entry.$2 == 'Study Tips' ? 'tips' : ''; apply(); },
          ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('Study Room · ${threads.length} threads',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: widget.onAsk,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text('Ask'),
        ),
      ]),
      const SizedBox(height: 8),
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
              margin: const EdgeInsets.only(bottom: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
              color: Theme.of(context).colorScheme.surface,
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 12, backgroundColor: const Color(0xFF315D76),
                      child: Text((raw['author_name']?.toString().isNotEmpty == true)
                        ? raw['author_name'].toString()[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 11))),
                    const SizedBox(width: 7),
                    Expanded(child: Text(raw['author_name']?.toString() ?? 'Student',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                    Text(raw['category']?.toString() ?? '',
                      style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 8),
                  Text(raw['title']?.toString() ?? 'Discussion',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    Text(raw['preview']?.toString() ?? '', maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFFA7BBD0))),
                    const SizedBox(height: 8),
                    Text(
                      "${friendlyTime(raw['created_at'])} · ${raw['replies'] ?? 0} replies",
                      style: const TextStyle(fontSize: 10, color: Color(0xFF9DC8E1))),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => CommunityThreadPage(
                      threadId: raw['id']?.toString() ?? '',
                      api: widget.api,
                      onReply: widget.onReply,
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
  ),
  );
}
