import 'note_reader_page.dart';
import '../services/external_link_opener.dart';
import '../services/update_deadline.dart';
import 'package:material_ui/material_ui.dart';
import '../services/public_feed_api.dart';

class PublicFeedPage extends StatefulWidget {
  const PublicFeedPage({super.key, required this.type, this.api = const PublicFeedApi(), this.onSaveNote,
    this.initialDepartment = '', this.initialSemester = '',
    this.refreshVersion = 0, this.loadContinue, this.onResume,
    this.onOpenNote, this.onOpenOffline, this.onQuickNavigate,
    this.onQuickInformation, this.canOpenRestricted = false});
  final String type;
  final PublicFeedApi api;
  final Future<bool> Function(String noteId)? onSaveNote;
  final String initialDepartment;
  final String initialSemester;
  /// Incremented by the shell when a feed tab is visited or selected again.
  final int refreshVersion;
  final Future<Map<String, dynamic>?> Function()? loadContinue;
  final ValueChanged<String>? onResume;
  final void Function(String noteId, bool restricted)? onOpenNote;
  final VoidCallback? onOpenOffline;
  final ValueChanged<int>? onQuickNavigate;
  final ValueChanged<String>? onQuickInformation;
  final bool canOpenRestricted;
  @override
  State<PublicFeedPage> createState() => _PublicFeedPageState();
}

class _PublicFeedPageState extends State<PublicFeedPage>
    with WidgetsBindingObserver {
  final search = TextEditingController();
  List<dynamic> items = [];
  String? error;
  bool loading = false;
  bool showFilters = false;
  Future<Map<String, dynamic>?>? _continueFuture;
  int _feedGeneration = 0;
  int _filterGeneration = 0;
  int total = 0, page = 1;
  String stream = '', category = '', semester = '', department = '', subject = '';
  List<Map<String, dynamic>> departments = [];
  List<Map<String, dynamic>> subjects = [];
  List<int> semesters = [];
  bool get isNotes => widget.type == 'notes';

  List<Map<String, dynamic>> get updateRows => items.whereType<Map<String, dynamic>>().toList();
  List<Map<String, dynamic>> get deadlineRows => updateRows.where((entry) =>
    (entry['deadline_date']?.toString() ?? '').isNotEmpty &&
    universityUpdateStatus(entry['deadline_date'], entry['event_date']) == UniversityUpdateStatus.active).toList();
  List<Map<String, dynamic>> get announcementRows => updateRows.where((entry) =>
    !deadlineRows.any((deadline) => deadline['id'] == entry['id'])).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    department = widget.initialDepartment;
    semester = widget.initialSemester;
    if (isNotes) { loadFilters(); _continueFuture = widget.loadContinue?.call(); }
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
      setState(() => _continueFuture = widget.loadContinue?.call());
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
    } else if (oldWidget.refreshVersion != widget.refreshVersion ||
        oldWidget.loadContinue != widget.loadContinue) {
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
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 92),
    children: [
      Text(isNotes ? 'Study Notes' : 'Campus Updates',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface)),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text(isNotes
          ? 'Find your course, then choose what to study.'
          : 'Latest campus announcements and student opportunities.')),
        IconButton.filledTonal(
          key: Key('feed-refresh-button-${widget.type}'),
          tooltip: 'Refresh latest ${isNotes ? 'notes' : 'updates'}',
          onPressed: loading ? null : refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ]),
      const SizedBox(height: 14),
      TextField(
        key: Key('search-${widget.type}'),
        maxLength: 100,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
        controller: search,
        onSubmitted: (_) => filter(),
        decoration: InputDecoration(
          hintText: isNotes ? 'Search courses, codes, lecturers...' : 'Search campus updates...', prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: IconButton(onPressed: filter, icon: const Icon(Icons.arrow_forward)),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
      ),
      const SizedBox(height: 10),
      if (isNotes && _continueFuture != null) FutureBuilder<Map<String, dynamic>?>(
        future: _continueFuture,
        builder: (context, snapshot) {
          final note = snapshot.data;
          if (note == null || note['note_id'] is! String) return const SizedBox.shrink();
          return Padding(padding: const EdgeInsets.only(bottom: 17),
            child: InkWell(
              key: const Key('continue-study-note'),
              onTap: () => widget.onResume?.call(note['note_id'] as String),
              borderRadius: BorderRadius.circular(12),
              child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
                child: Row(children: [
                  const Icon(Icons.menu_book_rounded, color: Color(0xFF80BDD9)),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Continue studying', style: TextStyle(
                        color: Color(0xFF9DCBE4), fontSize: 10)),
                      const SizedBox(height: 4),
                      Text(note['title']?.toString() ?? 'Saved note',
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    ])),
                  const SizedBox(width: 10),
                  const Text('Resume ›', style: TextStyle(fontSize: 11,
                    color: Color(0xFFC4E9FF))),
                ])),
            ));
        },
      ),
      if (isNotes) ...[
        Row(children: [
          const Expanded(child: Text('Quick access',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
          if (widget.onOpenOffline != null)
            TextButton.icon(
              key: const Key('open-offline-library'),
              onPressed: widget.onOpenOffline,
              icon: const Icon(Icons.offline_pin_outlined, size: 17),
              label: const Text('Offline notes'),
            ),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, constraints) {
          final width = (constraints.maxWidth - 9) / 2;
          return Wrap(
            spacing: 9, runSpacing: 9,
            children: [
              for (final entry in const [
                ('Browse Notes', Icons.auto_stories_outlined, 'notes'),
                ('Campus Updates', Icons.campaign_outlined, 'updates'),
                ('Contributors', Icons.groups_outlined, 'contributors'),
                ('Support', Icons.favorite_border_rounded, 'support'),
              ])
                SizedBox(width: width, child: OutlinedButton.icon(
                  key: Key('quick-${entry.$3}'),
                  onPressed: () {
                    switch (entry.$3) {
                      case 'notes':
                        search.clear();
                        subject = '';
                        filter();
                      case 'updates':
                        widget.onQuickNavigate?.call(2);
                      case 'contributors':
                      case 'support':
                        widget.onQuickInformation?.call(entry.$3);
                    }
                  },
                  icon: Icon(entry.$2, size: 18),
                  label: Text(entry.$1, maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(0, 48),
                    backgroundColor: Theme.of(context).colorScheme.surface
                      .withValues(alpha: .65),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  ),
                )),
            ],
          );
        }),
        const SizedBox(height: 6),
      ],
      if (isNotes) Align(alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const Key('notes-advanced-filters'),
          onPressed: () => setState(() => showFilters = !showFilters),
          icon: Icon(showFilters ? Icons.expand_less : Icons.tune, size: 16),
          label: Text(showFilters ? 'Hide advanced filters' : 'Advanced filters'),
        )),
      if (showFilters) ...[
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
      ],
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
        if (isNotes) ...[
          Text('Browse notes · $total available',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final raw in items.whereType<Map<String, dynamic>>())
            _FeedTile(data: raw, isNote: true, api: widget.api,
              onOpenNote: widget.onOpenNote,
              canOpenRestricted: widget.canOpenRestricted),
        ] else ...[
          if (deadlineRows.isNotEmpty) ...[
            Row(children: [
              const Expanded(child: Text('Active Deadlines', style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800))),
              Text('${deadlineRows.length} on this page', style: const TextStyle(
                fontSize: 10, color: Color(0xFF65C8A4))),
            ]),
            const SizedBox(height: 8),
            SizedBox(height: 245, child: ListView(scrollDirection: Axis.horizontal,
              children: [for (final entry in deadlineRows)
                SizedBox(width: 255, child: Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: _FeedTile(data: entry, isNote: false,
                    api: widget.api, compactUpdate: true),
                )),
              ])),
            const SizedBox(height: 14),
          ],
          Text('Recent Announcements · $total posts', style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final entry in announcementRows)
            _FeedTile(data: entry, isNote: false, api: widget.api),
        ],
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
    this.onOpenNote, this.canOpenRestricted = false,
    this.compactUpdate = false,
  });
  final Map<String, dynamic> data;
  final bool isNote;
  final PublicFeedApi api;
  final void Function(String noteId, bool restricted)? onOpenNote;
  final bool canOpenRestricted;
  final bool compactUpdate;

  String get title => data['title']?.toString() ?? 'Untitled';
  String get summary => isNote
    ? '${data['department_name'] ?? ''} · ${data['lecturer_names'] is List ? (data['lecturer_names'] as List).join(', ') : ''} · ${data['contributor_name'] ?? ''}'
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
      if (restricted && !canOpenRestricted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Verified Student Card access is required.'),
        ));
        return;
      }
      final id = data['id']?.toString() ?? '';
      if (onOpenNote != null) { onOpenNote!(id, restricted); return; }
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => NoteReaderPage(noteId: id, api: api),
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
    if (compactUpdate) {
      return Container(
        key: Key('deadline-card-${data['id']}'),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (image != null)
            ClipRRect(borderRadius: BorderRadius.circular(9),
              child: Image.network(image, width: double.infinity, height: 75,
                fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) =>
                  const SizedBox(height: 75, child: Center(
                    child: Icon(Icons.campaign_outlined, size: 35)))))
          else
            const SizedBox(height: 65,
              child: Center(child: Icon(Icons.campaign_outlined, size: 35))),
          const SizedBox(height: 8),
          Row(children: [
            _UpdateStatusPill(status: universityUpdateStatus(
              data['deadline_date'], data['event_date'])),
            const Spacer(),
            Flexible(child: Text(data['deadline_date']?.toString() ?? '',
              textAlign: TextAlign.end, style: TextStyle(
                fontSize: 10, color: scheme.onSurfaceVariant))),
          ]),
          const SizedBox(height: 7),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const Spacer(),
          Row(children: [
            TextButton(onPressed: () => _openDetail(context),
              child: const Text('Details', style: TextStyle(fontSize: 11))),
            const Spacer(),
            if (applyUrl != null)
              FilledButton(
                key: Key('update-apply-${data['id']}'),
                onPressed: applyExpired ? null :
                  () => _openExternal(context, applyUrl.toString()),
                child: Text(applyExpired ? 'Closed' : 'Apply Now',
                  style: const TextStyle(fontSize: 11)),
              ),
          ]),
        ]),
      );
    }
    if (!isNote) {
      return Card(
        margin: const EdgeInsets.only(bottom: 7),
        color: scheme.surface, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: scheme.outlineVariant)),
        child: InkWell(onTap: () => _openDetail(context),
          borderRadius: BorderRadius.circular(11),
          child: Padding(padding: const EdgeInsets.all(9),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(7),
                child: SizedBox(width: 49, height: 49,
                  child: image == null
                    ? const Icon(Icons.campaign_rounded)
                    : Image.network(image, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.campaign_rounded)))),
              const SizedBox(width: 9),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _UpdateStatusPill(status: universityUpdateStatus(
                      data['deadline_date'], data['event_date'])),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      data['published_at']?.toString().split('T').first ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10,
                        color: scheme.onSurfaceVariant))),
                  ]),
                  const SizedBox(height: 3),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w800)),
                  Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10,
                      color: scheme.onSurfaceVariant)),
                ])),
              if (applyUrl != null) ...[
                const SizedBox(width: 5),
                TextButton(
                  key: Key('update-apply-${data['id']}'),
                  onPressed: applyExpired ? null :
                    () => _openExternal(context, applyUrl.toString()),
                  child: Text(applyExpired ? 'Applications Closed' : 'Apply Now',
                    style: const TextStyle(fontSize: 10)),
                ),
              ] else
                const Icon(Icons.chevron_right_rounded, size: 18),
            ]))),
      );
    }
    if (isNote) {
      return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: scheme.surface, elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant)),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${data['subject_code'] ?? ''} · Semester ${data['semester'] ?? '?'}',
            style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 3),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
        subtitle: Text(summary,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
        onTap: () => _openDetail(context),
      ),
    );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant)),
      color: scheme.surface.withValues(alpha: .96),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (image != null)
          SizedBox(
            height: compactUpdate ? 92 : 70,
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
            height: compactUpdate ? 92 : 65,
            width: double.infinity,
            decoration: BoxDecoration(gradient: LinearGradient(
              colors: [scheme.primary, scheme.tertiary])),
            child: const Icon(Icons.campaign_outlined, size: 42,
              color: Colors.white),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                  height: 1.23, color: scheme.onSurface)),
            ),
            const SizedBox(height: 9),
            Text(summary, maxLines: compactUpdate ? 2 : 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5)),
            if (!isNote && data['published_at'] != null) ...[
              const SizedBox(height: 11),
              Text(data['published_at'].toString().split('T').first,
                style: TextStyle(color: scheme.onSurfaceVariant,
                  fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _openDetail(context),
                icon: Icon(isNote ? Icons.menu_book_outlined
                  : Icons.article_outlined),
                label: Text(isNote ? 'Read notes' : 'Read update'),
              )),
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
