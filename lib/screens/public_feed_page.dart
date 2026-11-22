import 'note_reader_page.dart';
import '../services/external_link_opener.dart';
import '../services/update_deadline.dart';
import 'package:material_ui/material_ui.dart';
import '../services/public_feed_api.dart';

class PublicFeedPage extends StatefulWidget {
  const PublicFeedPage({super.key, required this.type, this.api = const PublicFeedApi(), this.onSaveNote,
    this.initialDepartment = '', this.initialSemester = '',
    this.refreshVersion = 0});
  final String type;
  final PublicFeedApi api;
  final Future<bool> Function(String noteId)? onSaveNote;
  final String initialDepartment;
  final String initialSemester;
  /// Incremented by the shell when a feed tab is visited or selected again.
  final int refreshVersion;
  @override
  State<PublicFeedPage> createState() => _PublicFeedPageState();
}

class _PublicFeedPageState extends State<PublicFeedPage>
    with WidgetsBindingObserver {
  final search = TextEditingController();
  List<dynamic> items = [];
  String? error;
  bool loading = false;
  int _feedGeneration = 0;
  int _filterGeneration = 0;
  int total = 0, page = 1;
  String stream = '', category = '', semester = '', department = '', subject = '';
  List<Map<String, dynamic>> departments = [];
  List<Map<String, dynamic>> subjects = [];
  List<int> semesters = [];
  bool get isNotes => widget.type == 'notes';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    department = widget.initialDepartment;
    semester = widget.initialSemester;
    if (isNotes) { loadFilters(); }
    load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    }
  }

  Future<void> refresh() async {
    // Refresh both the visible feed and dependent catalogue options.
    if (isNotes) {
      await Future.wait([loadFilters(), load()]);
    } else {
      await load();
    }
  }

  @override
  void didUpdateWidget(covariant PublicFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type || oldWidget.api != widget.api ||
        oldWidget.initialDepartment != widget.initialDepartment ||
        oldWidget.initialSemester != widget.initialSemester) {
      page = 1;
      search.clear();
      stream = '';
      category = '';
      department = widget.initialDepartment;
      semester = widget.initialSemester;
      subject = '';
      departments = [];
      subjects = [];
      semesters = [];
      // Switching between Notes and Updates must never reuse old filter data.
      _filterGeneration++;
      if (isNotes) loadFilters();
      load();
    } else if (oldWidget.refreshVersion != widget.refreshVersion) {
      refresh();
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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final generation = ++_feedGeneration;
    setState(() { loading = true; error = null; });
    try {
      final data = await widget.api.fetch(widget.type, page: page,
        search: search.text, stream: stream, semester: semester,
        department: department, subject: subject,
        category: isNotes ? '' : category);
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
  Widget build(BuildContext context) => RefreshIndicator(
    key: Key('feed-refresh-indicator-${widget.type}'),
    onRefresh: refresh,
    child: ListView(
    key: Key('feed-${widget.type}'),
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
    children: [
      Text(isNotes ? 'Browse notes' : 'University updates',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
          color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text(isNotes
          ? 'Published study material by subject and semester.'
          : 'Latest campus announcements and student opportunities.')),
        IconButton.filledTonal(
          key: Key('feed-refresh-button-${widget.type}'),
          tooltip: 'Refresh latest ${isNotes ? 'notes' : 'updates'}',
          onPressed: loading ? null : refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ]),
      const SizedBox(height: 20),
      TextField(
        key: Key('search-${widget.type}'),
        maxLength: 100,
        controller: search,
        onSubmitted: (_) => filter(),
        decoration: InputDecoration(
          hintText: 'Search', prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(onPressed: filter, icon: const Icon(Icons.arrow_forward)),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
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
      if (!isNotes) ...[
        Wrap(spacing: 8, children: [
          for (final value in const ['', 'campus', 'opportunities'])
            ChoiceChip(
              key: Key('update-stream-${value.isEmpty ? 'all' : value}'),
              label: Text(value.isEmpty ? 'All' : value == 'campus' ? 'Campus' : 'Opportunities'),
              selected: stream == value,
              onSelected: (_) { stream = value; category = ''; filter(); },
            ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('update-category-$stream'),
          initialValue: category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Category'),
          items: const [
            DropdownMenuItem(value: '', child: Text('All categories')),
            DropdownMenuItem(value: 'academics', child: Text('Academics')),
            DropdownMenuItem(value: 'exams', child: Text('Exams')),
            DropdownMenuItem(value: 'admissions', child: Text('Admissions')),
            DropdownMenuItem(value: 'fees', child: Text('Fees')),
            DropdownMenuItem(value: 'events', child: Text('Events')),
            DropdownMenuItem(value: 'scholarships', child: Text('Scholarships')),
            DropdownMenuItem(value: 'campus', child: Text('Campus')),
            DropdownMenuItem(value: 'opportunities', child: Text('Opportunities')),
            DropdownMenuItem(value: 'other', child: Text('Other')),
          ],
          onChanged: (value) { category = value ?? ''; filter(); },
        ),
      ],
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
            _FeedTile(data: raw, isNote: isNotes, api: widget.api,
              onSaveNote: widget.onSaveNote),
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
  ),
  );
}

class _FeedTile extends StatelessWidget {
  const _FeedTile({
    required this.data, required this.isNote, required this.api,
    this.onSaveNote,
  });
  final Map<String, dynamic> data;
  final bool isNote;
  final PublicFeedApi api;
  final Future<bool> Function(String noteId)? onSaveNote;

  String get title => data['title']?.toString() ?? 'Untitled';
  String get summary => isNote
    ? '${data['department_name'] ?? ''} · ${data['subject_code'] ?? ''} · Semester ${data['semester'] ?? '?'}'
    : data['summary']?.toString() ?? '';
  bool get restricted => isNote && data['is_sensitive'] == true;

  Future<void> _openExternal(BuildContext context, Object? url) async {
    try {
      await const ExternalLinkOpener().openHttps(url);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Unable to open this link safely.'),
      ));
    }
  }

  void _openDetail(BuildContext context) {
    if (isNote) {
      if (restricted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Verified Student Card access is required.'),
        ));
        return;
      }
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => NoteReaderPage(
          noteId: data['id']?.toString() ?? '', api: api),
      ));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .86,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 38),
            children: [
              if (data['is_pinned'] == true)
                Text('IMPORTANT UPDATE', style: TextStyle(
                  color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800,
                  letterSpacing: 1.1)),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontSize: 26,
                fontWeight: FontWeight.w900, height: 1.18)),
              const SizedBox(height: 14),
              Text(summary, style: const TextStyle(
                fontSize: 15, height: 1.55)),
              const SizedBox(height: 18),
              if ((data['stream']?.toString() ?? '').isNotEmpty)
                Text('Section: ${data['stream']}'),
              if ((data['category']?.toString() ?? '').isNotEmpty)
                Text('Category: ${data['category']}'),
              _UpdateStatusPill(
                status: universityUpdateStatus(
                  data['deadline_date'], data['event_date']),
              ),
              const SizedBox(height: 10),
              if ((data['event_date']?.toString() ?? '').isNotEmpty)
                Text('Event: ${data['event_date']}'),
              if ((data['deadline_date']?.toString() ?? '').isNotEmpty)
                Text('Deadline: ${data['deadline_date']}'),
              const Divider(height: 34),
              SelectableText(data['body']?.toString() ??
                'No article body available.',
                style: const TextStyle(fontSize: 16, height: 1.7)),
              const SizedBox(height: 24),
              if (ExternalLinkOpener.trustedHttps(data['application_url']) != null)
                FilledButton.icon(
                  key: const Key('update-apply-now-detail'),
                  onPressed: isUpdateApplicationExpired(data['deadline_date'])
                     ? null : () => _openExternal(sheetContext, data['application_url']),
                  icon: Icon(isUpdateApplicationExpired(data['deadline_date'])
                     ? Icons.lock_clock_outlined : Icons.open_in_new_rounded),
                   label: Text(isUpdateApplicationExpired(data['deadline_date'])
                     ? 'Applications Closed' : 'Apply Now'),
                ),
              if (ExternalLinkOpener.trustedHttps(data['source_url']) != null)
                OutlinedButton.icon(
                  onPressed: () => _openExternal(sheetContext,
                    data['source_url']),
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Original source'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final imagePath = data['image_url']?.toString() ?? '';
    final origin = Uri.tryParse(api.baseUrl);
    final image = !isNote &&
      RegExp(r'^/api/updates/image/[0-9a-f-]{36}$', caseSensitive: false)
        .hasMatch(imagePath) &&
      origin != null && origin.scheme == 'https' && origin.host.isNotEmpty &&
      origin.userInfo.isEmpty
      ? origin.resolve(imagePath).toString() : null;
    final applyUrl = ExternalLinkOpener.trustedHttps(data['application_url']);
    final applyExpired = isUpdateApplicationExpired(data['deadline_date']);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant)),
      color: scheme.surface.withValues(alpha: .96),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (image != null)
          SizedBox(
            height: 176,
            width: double.infinity,
            child: Image.network(image, fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                color: scheme.primaryContainer,
                child: Icon(Icons.article_outlined, size: 48,
                  color: scheme.primary),
              )),
          )
        else if (!isNote)
          Container(
            height: 95,
            width: double.infinity,
            decoration: BoxDecoration(gradient: LinearGradient(
              colors: [scheme.primary, scheme.tertiary])),
            child: const Icon(Icons.campaign_outlined, size: 42,
              color: Colors.white),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 15),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 7, runSpacing: 6, children: [
              if (!isNote) ...[
                _FeedPill((data['stream']?.toString() ?? 'Update') ==
                      'opportunities' ? 'Opportunities' : 'Campus'),
                _UpdateStatusPill(
                  status: universityUpdateStatus(
                    data['deadline_date'], data['event_date']),
                ),
                if ((data['category']?.toString() ?? '').isNotEmpty)
                  _FeedPill(data['category'].toString()),
                if (data['is_pinned'] == true)
                  const _FeedPill('Important'),
                if ((data['deadline_date']?.toString() ?? '').isNotEmpty)
                  _FeedPill('Deadline ${data['deadline_date']}'),
              ] else ...[
                _FeedPill('Semester ${data['semester'] ?? '?'}'),
                if (restricted) const _FeedPill('Verified only'),
              ]
            ]),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _openDetail(context),
              child: Text(title,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  height: 1.23, color: scheme.onSurface)),
            ),
            const SizedBox(height: 9),
            Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5)),
            if (!isNote && data['published_at'] != null) ...[
              const SizedBox(height: 11),
              Text(data['published_at'].toString().split('T').first,
                style: TextStyle(color: scheme.onSurfaceVariant,
                  fontSize: 12)),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _openDetail(context),
                icon: Icon(isNote ? Icons.menu_book_outlined
                  : Icons.article_outlined),
                label: Text(isNote ? 'Read notes' : 'Read update'),
              )),
              if (isNote && onSaveNote != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  key: Key('save-note-${data['id']}'),
                  tooltip: 'Save note to bookmarks',
                  icon: const Icon(Icons.bookmark_add_outlined),
                  onPressed: () async {
                    final saved = await onSaveNote!(data['id']?.toString() ?? '');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(saved ? 'Note saved to your account.'
                        : 'Sign in or retry to save this note.'),
                    ));
                  },
                ),
              ],
              if (!isNote && applyUrl != null) ...[
                const SizedBox(width: 8),
                Expanded(child: FilledButton.icon(
                  key: Key('update-apply-${data['id']}'),
                  onPressed: applyExpired ? null :
                     () => _openExternal(context, applyUrl.toString()),
                  icon: Icon(applyExpired ? Icons.lock_clock_outlined
                     : Icons.open_in_new_rounded, size: 18),
                   label: Text(applyExpired ? 'Applications Closed'
                     : 'Apply Now'),
                )),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _UpdateStatusPill extends StatelessWidget {
  const _UpdateStatusPill({required this.status});
  final UniversityUpdateStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, foreground, background) = switch (status) {
      UniversityUpdateStatus.active => (
        'Active', Icons.check_circle_outline_rounded,
        const Color(0xFF147D50), const Color(0xFFE6F7ED)),
      UniversityUpdateStatus.upcoming => (
        'Upcoming', Icons.event_outlined,
        const Color(0xFF1959A5), const Color(0xFFE6F0FF)),
      UniversityUpdateStatus.expired => (
        'Expired', Icons.schedule_outlined,
        const Color(0xFFA83342), const Color(0xFFFFEBEE)),
    };
    return Container(
      key: Key('update-status-${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: foreground.withValues(alpha: .20)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: foreground),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: foreground, fontSize: 11,
          fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _FeedPill extends StatelessWidget {
  const _FeedPill(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700,
        color: scheme.onPrimaryContainer)),
    );
  }
}
