import 'package:material_ui/material_ui.dart';

/// Visible reader actions for both guests and authenticated students.
/// Guests are prompted to sign in when interacting; offline saving is
/// authorized separately for verified students.
class ReaderToolbarActions extends StatefulWidget {
  const ReaderToolbarActions({
    super.key, required this.loadState,
    required this.toggleBookmark,
    required this.toggleCompleted,
    this.download, this.onDownloadUnavailable,
  });
  final Future<Map<String, bool>> Function() loadState;
  final Future<bool> Function(bool current) toggleBookmark;
  final Future<bool> Function(bool current) toggleCompleted;
  final Future<void> Function(void Function(int, int) progress)? download;
  final VoidCallback? onDownloadUnavailable;

  @override
  State<ReaderToolbarActions> createState() => _ReaderToolbarActionsState();
}

class _ReaderToolbarActionsState extends State<ReaderToolbarActions> {
  bool bookmarked = false, completed = false, busy = false;
  bool downloading = false;
  String? stateError;
  int currentPage = 0, totalPages = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await widget.loadState();
      if (mounted) {
        setState(() {
          bookmarked = info['bookmarked'] == true;
          completed = info['completed'] == true;
        });
      }
    } catch (_) {
      if (mounted) { setState(() => stateError = 'Unable to load study status.'); }
    }
  }

  void _message(String text) {
    if (!mounted) { return; }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
  }

  Future<void> _toggle({required bool isBookmark}) async {
    if (busy || downloading) { return; }
    setState(() => busy = true);
    try {
      final current = isBookmark ? bookmarked : completed;
      final success = isBookmark
        ? await widget.toggleBookmark(current)
        : await widget.toggleCompleted(current);
      if (!mounted) { return; }
      if (success) {
        setState(() {
          if (isBookmark) { bookmarked = !current; }
          else { completed = !current; }
        });
        _message(isBookmark
          ? (!current ? 'Saved to My Library' : 'Removed from bookmarks')
          : (!current ? 'Marked as completed' : 'Marked as unfinished'));
      } else {
        _message('Action unavailable. Sign in and retry.');
      }
    } catch (_) {
      _message('Action failed. Please retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _download() async {
    if (widget.download == null || busy || downloading) { return; }
    setState(() => downloading = true);
    try {
      await widget.download!((done, count) {
        currentPage = done;
        totalPages = count;
        if (mounted) setState(() {});
      });
      _message('Available in Offline Library for 48 hours.');
    } catch (_) {
      _message('Unable to save offline. Verify your Student Card and internet connection.');
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min, children: [
      if (stateError != null) IconButton(
        tooltip: 'Retry study status', onPressed: _load,
        icon: const Icon(Icons.sync_problem_outlined, size: 19)),
      IconButton(
        key: const Key('reader-bookmark'),
        tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark this note',
        onPressed: busy || downloading ? null : () => _toggle(isBookmark: true),
        icon: Icon(bookmarked ? Icons.bookmark : Icons.bookmark_border,
          size: 21),
      ),
      IconButton(
        key: const Key('reader-completed'),
        tooltip: completed ? 'Mark unfinished' : 'Mark completed',
        onPressed: busy || downloading ? null : () => _toggle(isBookmark: false),
        icon: Icon(completed ? Icons.task_alt_rounded
          : Icons.check_circle_outline_rounded, size: 21),
      ),
      if (widget.download != null || widget.onDownloadUnavailable != null)
        IconButton(
          key: const Key('reader-offline-download'),
          tooltip: downloading
            ? 'Saving page $currentPage of $totalPages'
            : 'Save encrypted offline note',
          onPressed: busy || downloading ? null :
            widget.download != null ? _download : widget.onDownloadUnavailable,
          icon: downloading
            ? const SizedBox(width: 19, height: 19,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.download_for_offline_outlined, size: 21),
        ),
    ],
  );
}
