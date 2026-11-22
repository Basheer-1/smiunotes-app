import 'package:material_ui/material_ui.dart';
import '../services/bookmark_api.dart';

/// Reads the signed-in student's bookmarks from the server on every visit.
/// No account IDs, access tokens or bookmark lists are persisted on device.
class MyBookmarksPage extends StatefulWidget {
  const MyBookmarksPage({
    super.key,
    required this.api,
    required this.currentAccessToken,
  });

  final BookmarkApi api;
  final String Function() currentAccessToken;

  @override
  State<MyBookmarksPage> createState() => _MyBookmarksPageState();
}

class _MyBookmarksPageState extends State<MyBookmarksPage> {
  late Future<Map<String, dynamic>> _result;
  String? _actionError;
  final Set<String> _removing = <String>{};
  bool _completedView = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    // Fetches current session at request time (supports rotation/sign-out).
    _result = Future.sync(
      () => _completedView
        ? widget.api.listCompleted(widget.currentAccessToken())
        : widget.api.list(widget.currentAccessToken()),
    );
  }

  void _refresh() {
    setState(() {
      _actionError = null;
      _reload();
    });
  }

  void _selectView(bool completed) {
    if (_completedView == completed) return;
    _completedView = completed;
    _refresh();
  }

  Future<void> _remove(String noteId) async {
    if (_removing.contains(noteId)) return;
    setState(() {
      _removing.add(noteId);
      _actionError = null;
    });
    try {
      final response = _completedView
        ? await widget.api.uncomplete(widget.currentAccessToken(), noteId)
        : await widget.api.remove(widget.currentAccessToken(), noteId);
      if (response['ok'] != true ||
          (_completedView ? response['completed'] != false
                          : response['bookmarked'] != false)) {
        throw const FormatException('Remove not confirmed.');
      }
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        setState(() => _actionError =
          'Unable to update study library. Check your sign-in and retry.');
      }
    } finally {
      if (mounted) setState(() => _removing.remove(noteId));
    }
  }


  Future<void> _toggleCompleted(String noteId, bool complete) async {
    if (_removing.contains(noteId)) return;
    setState(() { _removing.add(noteId); _actionError = null; });
    try {
      final response = complete
        ? await widget.api.complete(widget.currentAccessToken(), noteId)
        : await widget.api.uncomplete(widget.currentAccessToken(), noteId);
      if (response['ok'] != true ||
          response['completed'] != complete) {
        throw const FormatException('Completion status not confirmed.');
      }
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) {
        setState(() => _actionError =
          'Unable to update completed notes. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _removing.remove(noteId));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My study library'),
      actions: [IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Refresh bookmarks',
        onPressed: _refresh,
      )]),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _result,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Unable to load saved notes. Retry'),
          ));
        }
        final raw = snapshot.data!['items'];
        if (raw is! List<dynamic>) {
          return const Center(child: Text('Invalid saved notes response.'));
        }
        return ListView(
          key: const Key('my-bookmarks'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text('Your private study progress',
              style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              key: const Key('study-library-selector'),
              segments: const [
                ButtonSegment(value: false,
                  icon: Icon(Icons.bookmark_outline),
                  label: Text('Bookmarks')),
                ButtonSegment(value: true,
                  icon: Icon(Icons.task_alt_outlined),
                  label: Text('Completed')),
              ],
              selected: {_completedView},
              onSelectionChanged: (choice) => _selectView(choice.first),
            ),
            const SizedBox(height: 10),
            if (_actionError != null)
              Text(_actionError!, key: const Key('bookmark-action-error')),
            if (raw.isEmpty)
              Padding(padding: EdgeInsets.all(20),
                child: Text(_completedView
                  ? 'No completed notes yet.' : 'No bookmarked notes yet.')),
            for (final entry in raw)
              if (entry is Map<String, dynamic> &&
                  entry['note_id'] is String)
                Card(child: ListTile(
                  title: Text(entry['title']?.toString() ?? 'Saved note'),
                  subtitle: Text(_completedView
                    ? 'Completed note' : (entry['completed'] == true
                      ? 'Bookmarked · Also completed' : 'Saved note')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_completedView)
                        IconButton(
                          key: Key('toggle-completed-${entry['note_id']}'),
                          tooltip: entry['completed'] == true
                            ? 'Mark note not completed'
                            : 'Mark note completed',
                          icon: Icon(entry['completed'] == true
                            ? Icons.task_alt_rounded
                            : Icons.radio_button_unchecked_rounded),
                          onPressed: _removing.contains(entry['note_id'])
                            ? null : () => _toggleCompleted(
                              entry['note_id'] as String,
                              entry['completed'] != true),
                        ),
                      IconButton(
                        key: Key(_completedView
                          ? 'uncomplete-note-${entry['note_id']}'
                          : 'remove-bookmark-${entry['note_id']}'),
                        tooltip: _completedView ? 'Remove completed status'
                          : 'Remove bookmark',
                        icon: Icon(_completedView
                          ? Icons.remove_done_outlined
                          : Icons.bookmark_remove_outlined),
                        onPressed: _removing.contains(entry['note_id'])
                          ? null : () => _remove(entry['note_id'] as String),
                      ),
                    ],
                  ),
                )),
          ],
        );
      },
    ),
  );
}
