import 'package:material_ui/material_ui.dart';
import '../services/contributors_api.dart';

class ContributorsDirectoryPage extends StatefulWidget {
  const ContributorsDirectoryPage({
    super.key, this.api = const ContributorsApi(),
  });
  final ContributorsApi api;
  @override
  State<ContributorsDirectoryPage> createState() => _ContributorsDirectoryPageState();
}

class _ContributorsDirectoryPageState extends State<ContributorsDirectoryPage> {
  final search = TextEditingController();
  String department = '', sort = 'notes';
  int page = 1, departmentsPage = 1, generation = 0;
  bool loading = true, hasMore = false;
  String? error;
  List<Map<String, dynamic>> people = [], boards = [], departments = [];

  @override
  void initState() {
    super.initState();
    load();
  }
  @override
  void dispose() {
    generation++;
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final requestId = ++generation;
    setState(() { loading = true; error = null; });
    try {
      final data = await widget.api.fetch(
        query: search.text, department: department, sort: sort,
        page: page, departmentsPage: departmentsPage,
      );
      if (!mounted || requestId != generation) return;
      List<Map<String, dynamic>> rows(Object? input) =>
          input is List ? input.whereType<Map<String, dynamic>>().toList() : [];
      setState(() {
        people = rows(data['items']);
        boards = rows(data['leaderboards']);
        departments = rows(data['departments']);
        hasMore = data['has_more'] == true;
        loading = false;
      });
    } catch (_) {
      if (!mounted || requestId != generation) return;
      setState(() { error = 'Unable to load contributors. Please retry.'; loading = false; });
    }
  }

  void applyFilters() { page = 1; load(); }

  Widget _person(Map<String, dynamic> person, {bool ranked = false}) {
    final colors = Theme.of(context).colorScheme;
    final name = person['name']?.toString() ?? 'Contributor';
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words.where((s) => s.isNotEmpty)
        .take(2).map((s) => s[0].toUpperCase()).join();
    final notes = person['notes'] is num ? (person['notes'] as num).toInt() : 0;
    final departments = person['departments'] is List
        ? (person['departments'] as List).join(' · ') : '';
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colors.surface.withValues(alpha: .9),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(children: [
        if (ranked) ...[
          SizedBox(width: 28, child: Text('${person['rank'] ?? '–'}',
            style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800))),
        ],
        CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Text(initials.isEmpty ? '?' : initials,
            style: TextStyle(color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800)),
            if (departments.isNotEmpty)
              Text(departments, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
          ],
        )),
        Text('$notes notes', style: TextStyle(
          color: colors.primary, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Contributors')),
      body: ListView(
        key: const Key('contributors-native-directory'),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(colors: [
                colors.primary, const Color(0xFF4775AB)]),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.diversity_3_outlined, color: Colors.white, size: 34),
                SizedBox(height: 13),
                Text('The people behind your notes.',
                  style: TextStyle(color: Colors.white, fontSize: 25,
                    height: 1.2, fontWeight: FontWeight.w900)),
                SizedBox(height: 10),
                Text('Meet students who share published course notes.',
                  style: TextStyle(color: Colors.white, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text('Department Top 10', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w900, color: colors.onSurface)),
          const SizedBox(height: 10),
          if (!loading && boards.isEmpty)
            const Text('Rankings will appear as students share more notes.'),
          for (final board in boards) ...[
            Card(elevation: 0, margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22)),
              child: Padding(padding: const EdgeInsets.all(15),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(board['name']?.toString() ?? 'Department',
                      style: const TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    for (final raw in (board['leaders'] is List
                      ? board['leaders'] as List : const []))
                      if (raw is Map<String, dynamic>) _person(raw, ranked: true),
                  ],
                )),
            ),
          ],
          if (!loading && boards.isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: departmentsPage > 1 ? () {
                  departmentsPage--; load();
                } : null,
                child: const Text('Previous departments'),
              ),
              TextButton(
                onPressed: boards.length == 6 ? () {
                  departmentsPage++; load();
                } : null,
                child: const Text('More'),
              ),
            ]),
          const SizedBox(height: 18),
          Text('All Contributors', style: TextStyle(fontSize: 22,
            color: colors.onSurface, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contributor-search'),
            controller: search,
            maxLength: 100,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Search by name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18))),
            onSubmitted: (_) => applyFilters(),
          ),
          DropdownButtonFormField<String>(
            key: const Key('contributor-department'),
            initialValue: department,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Department'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All departments')),
              for (final d in departments)
                DropdownMenuItem(value: d['id']?.toString() ?? '',
                  child: Text(d['name']?.toString() ?? 'Department',
                    overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (value) { department = value ?? ''; applyFilters(); },
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'notes', label: Text('Most notes')),
              ButtonSegment(value: 'name', label: Text('Name A–Z')),
            ],
            selected: {sort},
            onSelectionChanged: (value) {
              sort = value.first; applyFilters();
            },
          ),
          const SizedBox(height: 18),
          if (loading)
            const Center(child: Padding(padding: EdgeInsets.all(16),
              child: CircularProgressIndicator()))
          else if (error != null) ...[
            Text(error!, key: const Key('contributor-error')),
            OutlinedButton.icon(onPressed: load,
              icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ] else if (people.isEmpty)
            const Text('No contributors match these filters.')
          else ...[
            for (final p in people) _person(p),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              OutlinedButton(onPressed: page > 1 ? () {
                page--; load();
              } : null, child: const Text('Previous')),
              Text('Page $page'),
              OutlinedButton(onPressed: hasMore ? () {
                page++; load();
              } : null, child: const Text('Next')),
            ]),
          ],
        ],
      ),
    );
  }
}
