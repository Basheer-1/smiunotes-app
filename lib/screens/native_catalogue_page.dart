import 'package:material_ui/material_ui.dart';

import '../services/public_feed_api.dart';
import 'public_feed_page.dart';

/// Native catalogue discovery driven by the same published-note filter API.
/// Empty semesters and departments are never shown as selectable destinations.
class NativeCataloguePage extends StatefulWidget {
  const NativeCataloguePage({super.key, this.api = const PublicFeedApi()});
  final PublicFeedApi api;

  @override
  State<NativeCataloguePage> createState() => _NativeCataloguePageState();
}

class _NativeCataloguePageState extends State<NativeCataloguePage> {
  late Future<Map<String, dynamic>> _filters;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _filters = widget.api.fetch('filters');

  void _openNotes({String department = '', String semester = ''}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Browse notes')),
        body: PublicFeedPage(
          type: 'notes',
          api: widget.api,
          initialDepartment: department,
          initialSemester: semester,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Browse catalogue')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _filters,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Unable to load the notes catalogue.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(_reload),
                icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ));
        }
        final data = snapshot.data!;
        final subjects = (data['subjects'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>().toList();
        final departments = (data['departments'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>().toList();
        final semesters = (data['semesters'] as List<dynamic>? ?? [])
            .whereType<num>().map((n) => n.toInt()).toSet().toList()..sort();
        final visibleDepartments = departments.where((dept) => subjects
            .any((s) => s['department_id']?.toString() ==
                dept['id']?.toString())).toList();

        return ListView(
          key: const Key('native-catalogue'),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            Text('Find your study material',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Only departments and semesters with published notes appear here.'),
            const SizedBox(height: 18),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Browse all notes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openNotes,
            ),
            const SizedBox(height: 20),
            Text('By semester', style: Theme.of(context).textTheme.titleLarge),
            for (final semester in semesters)
              ListTile(
                key: Key('browse-semester-$semester'),
                leading: const Icon(Icons.school_outlined),
                title: Text('Semester $semester'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openNotes(semester: '$semester'),
              ),
            const SizedBox(height: 18),
            Text('By department', style: Theme.of(context).textTheme.titleLarge),
            if (visibleDepartments.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('No published departments yet.'),
              ),
            for (final department in visibleDepartments)
              ExpansionTile(
                key: Key('browse-department-${department['id']}'),
                title: Text(department['name']?.toString() ?? 'Department'),
                leading: const Icon(Icons.account_balance_outlined),
                children: [
                  for (final semester in (subjects
                      .where((s) => s['department_id']?.toString() ==
                          department['id']?.toString())
                      .map((s) => s['semester'])
                      .whereType<num>()
                      .map((n) => n.toInt()).toSet().toList()..sort()))
                    ListTile(
                      title: Text('Semester $semester'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openNotes(
                        department: department['id']?.toString() ?? '',
                        semester: '$semester',
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    ),
  );
}
