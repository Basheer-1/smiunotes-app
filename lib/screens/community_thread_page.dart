import 'package:material_ui/material_ui.dart';
import '../services/public_feed_api.dart';

/// Public read-only discussion and replies; no student credentials required.
class CommunityThreadPage extends StatefulWidget {
  const CommunityThreadPage({
    super.key,
    required this.threadId,
    this.api = const PublicFeedApi(),
  });

  final String threadId;
  final PublicFeedApi api;

  @override
  State<CommunityThreadPage> createState() => _CommunityThreadPageState();
}

class _CommunityThreadPageState extends State<CommunityThreadPage> {
  late Future<Map<String, dynamic>> detail;
  int page = 1;

  @override
  void initState() {
    super.initState();
    detail = widget.api.fetchThread(widget.threadId);
  }

  @override
  void didUpdateWidget(covariant CommunityThreadPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.threadId != widget.threadId || oldWidget.api != widget.api) {
      page = 1;
      detail = widget.api.fetchThread(widget.threadId);
    }
  }

  void load() {
    setState(() => detail = widget.api.fetchThread(widget.threadId, page: page));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: detail,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Discussion unavailable. It may be removed or archived.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: load, icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ));
        }
        final data = snapshot.data!;
        final thread = data['thread'] is Map<String, dynamic>
            ? data['thread'] as Map<String, dynamic>
            : <String, dynamic>{};
        final replies = data['replies'] is List
            ? data['replies'] as List<dynamic>
            : <dynamic>[];
        final hasMore = data['has_more'] == true;
        return ListView(
          key: const Key('thread-detail'),
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 38),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(19),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(thread['category']?.toString() ?? '',
                      style: const TextStyle(color: Color(0xFF183C68))),
                    const SizedBox(height: 8),
                    Text(thread['title']?.toString() ?? 'Discussion',
                      style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(thread['author_name']?.toString() ?? 'Student'),
                    const Divider(height: 30),
                    SelectableText(thread['body']?.toString() ?? '',
                      style: const TextStyle(height: 1.5)),
                    if (thread['locked'] == true) ...[
                      const SizedBox(height: 10),
                      const Text('This discussion is locked.'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Replies', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (replies.isEmpty) const Text('No visible replies yet.'),
            for (final raw in replies)
              if (raw is Map<String, dynamic>)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(raw['author_name']?.toString() ?? 'Student',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SelectableText(raw['body']?.toString() ?? ''),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: page > 1 ? () { page--; load(); } : null,
                  child: const Text('Previous')),
                Text('Page $page'),
                OutlinedButton(
                  onPressed: hasMore ? () { page++; load(); } : null,
                  child: const Text('Next')),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Replying will be available after secure student sign-in.',
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    ),
  );
}
