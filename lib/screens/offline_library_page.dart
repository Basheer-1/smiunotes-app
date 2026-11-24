import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import '../services/offline_notes_store.dart';

/// Offline-only viewer: never requests or exports the protected page URLs.
class OfflineNoteViewer extends StatefulWidget {
  const OfflineNoteViewer({super.key, required this.store,
    required this.owner, required this.noteId});
  final OfflineNotesStore store;
  final String owner, noteId;

  @override
  State<OfflineNoteViewer> createState() => _OfflineNoteViewerState();
}

class _OfflineNoteViewerState extends State<OfflineNoteViewer> {
  late Future<Map<String, dynamic>> metadata;
  @override
  void initState() {
    super.initState();
    metadata = widget.store.open(widget.owner, widget.noteId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Offline Reader')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: metadata,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Offline access expired or files unavailable. '
              'Reconnect to verify and download the note again.')));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        final pages = data['pages'] is List
          ? data['pages'] as List : const [];
        return ListView.builder(
          key: const Key('offline-reader'),
          padding: const EdgeInsets.all(14),
          itemCount: pages.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title']?.toString() ?? 'Offline note',
                    style: const TextStyle(fontSize: 21,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('${pages.length} protected pages · Available in this app only',
                    style: const TextStyle(fontSize: 12)),
                ]),
            );
            final item = pages[index - 1];
            if (item is! Map) return const SizedBox.shrink();
            final number = item['number'] as int? ?? index;
            final width = (item['width'] as num?)?.toDouble() ?? 800;
            final height = (item['height'] as num?)?.toDouble() ?? 1100;
            return Card(
              clipBehavior: Clip.antiAlias,
              margin: const EdgeInsets.only(bottom: 14),
              child: Column(children: [
                Padding(padding: const EdgeInsets.all(9),
                  child: Text('Page $number')),
                AspectRatio(
                  aspectRatio: width > 0 && height > 0 ? width / height : .72,
                  child: FutureBuilder<Uint8List>(
                    future: widget.store.page(widget.owner,
                      widget.noteId, number),
                    builder: (context, page) {
                      if (page.hasError) return const Center(
                        child: Text('Protected page unavailable'));
                      if (!page.hasData) return const Center(
                        child: CircularProgressIndicator());
                      return Image.memory(page.data!, fit: BoxFit.contain,
                        gaplessPlayback: false);
                    },
                  ),
                ),
              ]),
            );
          },
        );
      },
    ),
  );
}

class OfflineLibraryPage extends StatefulWidget {
  const OfflineLibraryPage({super.key, required this.store,
    required this.owner});
  final OfflineNotesStore store;
  final String owner;

  @override
  State<OfflineLibraryPage> createState() => _OfflineLibraryPageState();
}

class _OfflineLibraryPageState extends State<OfflineLibraryPage> {
  late Future<List<Map<String, dynamic>>> notes;
  @override
  void initState() {
    super.initState();
    refresh();
  }
  void refresh() => setState(() =>
    notes = widget.store.list(widget.owner));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Offline Library'),
      actions: [IconButton(tooltip: 'Refresh offline library',
        onPressed: refresh, icon: const Icon(Icons.refresh))],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: notes,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return snapshot.hasError
            ? const Center(child: Text('Unable to open offline library.'))
            : const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) return const Center(
          child: Padding(padding: EdgeInsets.all(24),
            child: Text('No offline notes yet. Open a note while online and '
              'use the download button in its reader titlebar.')),
        );
        return ListView(
          key: const Key('offline-library'),
          padding: const EdgeInsets.all(14),
          children: [
            const Padding(padding: EdgeInsets.only(bottom: 14),
              child: Text('Encrypted, app-only downloads · '
                'Re-verification required after 48 hours',
                style: TextStyle(fontSize: 12))),
            for (final note in snapshot.data!)
              Card(child: ListTile(
                leading: const Icon(Icons.offline_pin_outlined),
                title: Text(note['title']?.toString() ?? 'Saved note'),
                subtitle: Text('Valid until ${note['expires_at']?.toString().replaceFirst('T', ' ').split('.').first ?? ''} UTC',
                  style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  tooltip: 'Delete offline note',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await widget.store.remove(widget.owner,
                      note['note_id'] as String);
                    if (mounted) refresh();
                  }),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => OfflineNoteViewer(
                    store: widget.store, owner: widget.owner,
                    noteId: note['note_id'] as String))),
              )),
          ],
        );
      },
    ),
  );
}
