import 'note_reader_page.dart';
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
  int _feedGeneration = 0;
  int _filterGeneration = 0;
  int total = 0, page = 1;
  String stream = '', semester = '', department = '', subject = '';
  List<Map<String, dynamic>> departments = [];
  List<Map<String, dynamic>> subjects = [];
  List<int> semesters = [];
  bool get isNotes => widget.type == 'notes';

  @override
  void initState() {
    super.initState();
    if (isNotes) { loadFilters(); }
    load();
  }

  @override
  void didUpdateWidget(covariant PublicFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type || oldWidget.api != widget.api) {
      page = 1;
      search.clear();
      stream = '';
      department = '';
      semester = '';
      subject = '';
      departments = [];
      subjects = [];
      semesters = [];
      // Switching between Notes and Updates must never reuse old filter data.
      _filterGeneration++;
      if (isNotes) loadFilters();
      load();
    }
  }

  Future<void> loadFilters() async {
    final generation = ++_filterGeneration;
    try {
      final data = await widget.api.fetch('filters');
      if (!mounted || generation != _filterGeneration) return;
      setState(() {
        departments = (data['departments'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>().toList();
        subjects = (data['subjects'] as List<dynamic>? ?? [])
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
    final generation = ++_feedGeneration;
    setState(() { loading = true; error = null; });
    try {
      final data = await widget.api.fetch(widget.type, page: page,
        search: search.text, stream: stream, semester: semester,
        department: department, subject: subject);
      if (mounted && generation == _feedGeneration) { setState(() {
        items = (data['items'] as List<dynamic>?) ?? [];
        total = (data['total'] as num?)?.toInt() ?? 0;
      }); }
    } catch (_) {
      if (mounted && generation == _feedGeneration) {
        setState(() {
          items = []; total = 0;
          error = 'Unable to load published content. Check your connection and retry.';
        });
      }
    } finally {
      if (mounted && generation == _feedGeneration) {
        setState(() => loading = false);
      }
    }
  }
  void filter() { page = 1; load(); }

  List<int> get availableSemesters {
    if (department.isEmpty) return semesters;
    return subjects.where((item) => item['department_id'] == department)
        .map((item) => item['semester']).whereType<num>()
        .map((value) => value.toInt()).toSet().toList()..sort();
  }

  List<Map<String, dynamic>> get availableSubjects {
    return subjects.where((item) =>
      (department.isEmpty || item['department_id'] == department) &&
      (semester.isEmpty || item['semester']?.toString() == semester)).toList();
  }

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
        maxLength: 100,
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
          key: const Key('department-filter'),
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            key: ValueKey('department-${identityHashCode(widget.api)}'),
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
              semester = '';
              subject = '';
              filter();
            },
          ),
        ),
      if (isNotes)
        DropdownButtonFormField<String>(
          key: ValueKey('semester-$department'),
          initialValue: semester,
          decoration: const InputDecoration(labelText: 'Semester'),
          items: [
            const DropdownMenuItem(value: '', child: Text('All semesters')),
            for (final i in availableSemesters)
              DropdownMenuItem(value: i.toString(), child: Text('Semester $i')),
          ],
          onChanged: (value) { semester = value ?? ''; subject = ''; filter(); },
        ),
      if (isNotes && availableSubjects.isNotEmpty)
        Padding(
          key: const Key('subject-filter'),
          padding: const EdgeInsets.only(top: 12),
          child: DropdownButtonFormField<String>(
            key: ValueKey('subject-$department-$semester'),
            initialValue: subject,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Subject'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All subjects')),
              for (final item in availableSubjects)
                DropdownMenuItem(
                  value: item['id']?.toString() ?? '',
                  child: Text(
                    '${item['code'] ?? ''} · ${item['name'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) { subject = value ?? ''; filter(); },
          ),
        ),
      if (!isNotes) Wrap(spacing: 8, children: [
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
            _FeedTile(data: raw, isNote: isNotes, api: widget.api),
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
  const _FeedTile({required this.data, required this.isNote, required this.api});
  final Map<String, dynamic> data;
  final bool isNote;
  final PublicFeedApi api;
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
        onTap: () {
          if (isNote) {
            if (restricted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Verified student access is required for this note.'),
              ));
              return;
            }
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => NoteReaderPage(
                noteId: data['id']?.toString() ?? '', api: api,
              ),
            ));
            return;
          }
          showModalBottomSheet<void>(
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
                  if (!isNote && data['is_pinned'] == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('Pinned update', style: TextStyle(
                        color: Color(0xFF183C68), fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 12),
                  Text(subtitle),
                  if (!isNote) ...[
                    if ((data['stream']?.toString() ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Section: ${data['stream']}'),
                      ),
                    const SizedBox(height: 8),
                    if ((data['category']?.toString() ?? '').isNotEmpty)
                      Text('Category: ${data['category']}'),
                    if ((data['event_date']?.toString() ?? '').isNotEmpty)
                      Text('Event: ${data['event_date']}'),
                    if ((data['deadline_date']?.toString() ?? '').isNotEmpty)
                      Text('Deadline: ${data['deadline_date']}'),
                  ],
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
        );
        },
      ),
    );
  }
}
