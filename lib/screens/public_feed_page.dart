import 'package:material_ui/material_ui.dart';
import '../services/public_feed_api.dart';

class PublicFeedPage extends StatefulWidget {
  const PublicFeedPage({super.key, required this.type, this.api = const PublicFeedApi()});
  final String type;
  final PublicFeedApi api;
  @override
  State<PublicFeedPage> createState() => _PublicFeedPageState();
}

class _PublicFeedPageState extends State<PublicFeedPage> {
  final search = TextEditingController();
  List<dynamic> items = [];
  String? error;
  bool loading = false;
  int total = 0, page = 1;
  String stream = '', semester = '', department = '';
  List<Map<String, dynamic>> departments = [];
  List<int> semesters = [];
  bool get isNotes => widget.type == 'notes';

  @override
  void initState() {
    super.initState();
    if (isNotes) { loadFilters(); }
    load();
  }

  Future<void> loadFilters() async {
    try {
      final data = await widget.api.fetch('filters');
      if (!mounted) return;
      setState(() {
        departments = (data['departments'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>().toList();
        semesters = (data['semesters'] as List<dynamic>? ?? [])
            .whereType<num>().map((value) => value.toInt()).toList();
      });
    } catch (_) {
      // Keep catalogue search usable when filter options are unavailable.
    }
  }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await widget.api.fetch(widget.type, page: page,
        search: search.text, stream: stream, semester: semester,
        department: department);
      if (mounted) { setState(() {
        items = (data['items'] as List<dynamic>?) ?? [];
        total = (data['total'] as num?)?.toInt() ?? 0;
      }); }
    } catch (_) {
      if (mounted) {
        setState(() {
          items = []; total = 0;
          error = 'Feed unavailable. Check internet or staging API deployment.';
        });
      }
    } finally {
      if (mounted) { setState(() => loading = false); }
    }
  }
  void filter() { page = 1; load(); }

  @override
  Widget build(BuildContext context) => ListView(
    key: Key('feed-${widget.type}'),
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
    children: [
      Text(isNotes ? 'Browse notes' : 'University updates',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
          color: Color(0xFF102B4B))),
      const SizedBox(height: 10),
      Text(isNotes ? 'Published study material by subject and semester.'
        : 'Latest campus announcements and student opportunities.'),
      const SizedBox(height: 20),
      TextField(
        key: Key('search-${widget.type}'),
        controller: search,
        onSubmitted: (_) => filter(),
        decoration: InputDecoration(
          hintText: 'Search', prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(onPressed: filter, icon: const Icon(Icons.arrow_forward)),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
      ),
      const SizedBox(height: 12),
      if (isNotes && departments.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            key: const Key('department-filter'),
            initialValue: department,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All departments')),
              for (final item in departments)
                DropdownMenuItem(
                  value: item['id']?.toString() ?? '',
                  child: Text(item['name']?.toString() ?? 'Department',
                    overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) {
              department = value ?? '';
              filter();
            },
          ),
        ),
      if (isNotes)
        DropdownButtonFormField<String>(
          initialValue: semester,
          decoration: const InputDecoration(labelText: 'Semester'),
          items: [
            const DropdownMenuItem(value: '', child: Text('All semesters')),
            for (final i in semesters)
              DropdownMenuItem(value: i.toString(), child: Text('Semester $i')),
          ],
          onChanged: (value) { semester = value ?? ''; filter(); },
        )
      else Wrap(spacing: 8, children: [
        for (final value in const ['', 'campus', 'opportunities'])
          ChoiceChip(
            label: Text(value.isEmpty ? 'All' : value == 'campus' ? 'Campus' : 'Opportunities'),
            selected: stream == value,
            onSelected: (_) { stream = value; filter(); },
          ),
      ]),
      const SizedBox(height: 18),
      if (loading) const Center(child: CircularProgressIndicator())
      else if (error != null) ...[
        Text(error!, key: const Key('feed-error')),
        OutlinedButton.icon(onPressed: load, icon: const Icon(Icons.refresh),
          label: const Text('Retry')),
      ] else if (items.isEmpty) const Padding(
        padding: EdgeInsets.all(22), child: Text('No published content found.'),
      ) else ...[
        Text('$total published results'),
        const SizedBox(height: 12),
        for (final raw in items)
          if (raw is Map<String, dynamic>)
            _FeedTile(data: raw, isNote: isNotes),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          OutlinedButton(
            onPressed: page > 1 ? () { page--; load(); } : null,
            child: const Text('Previous')),
          Text('Page $page'),
          OutlinedButton(
            onPressed: page * 12 < total ? () { page++; load(); } : null,
            child: const Text('Next')),
        ]),
      ],
    ],
  );
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({required this.data, required this.isNote});
  final Map<String, dynamic> data;
  final bool isNote;
  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? 'Untitled';
    final subtitle = isNote
      ? '${data['department_name'] ?? ''} · ${data['subject_code'] ?? ''} · Semester ${data['semester'] ?? '?'}'
      : data['summary']?.toString() ?? '';
    final restricted = isNote && data['is_sensitive'] == true;
    return Card(
      color: Colors.white.withValues(alpha: 0.86),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('$subtitle${restricted ? '\nVerified only' : ''}',
          maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.78,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: [
                  Text(title, style: const TextStyle(
                    fontSize: 23, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(subtitle),
                  const Divider(height: 32),
                  if (isNote) ...[
                    if (restricted)
                      const Text('Verified Student Card access is required.'),
                    const Text(
                      'The native secure note reader is not available yet. '
                      'It will use the same server-side permissions as the website.',
                    ),
                  ] else
                    SelectableText(
                      data['body']?.toString() ?? 'No article body available.',
                      style: const TextStyle(height: 1.55),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
