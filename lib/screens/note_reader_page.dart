import 'package:material_ui/material_ui.dart';
import '../services/public_feed_api.dart';

/// Read-only WebP viewer; every page request is authorized and signed by server.
class NoteReaderPage extends StatefulWidget {
  const NoteReaderPage({
    super.key, required this.noteId, this.api = const PublicFeedApi(),
  });
  final String noteId;
  final PublicFeedApi api;
  @override
  State<NoteReaderPage> createState() => _NoteReaderPageState();
}

class _NoteReaderPageState extends State<NoteReaderPage> {
  late Future<Map<String, dynamic>> manifest;
  @override
  void initState() {
    super.initState();
    manifest = widget.api.fetchManifest(widget.noteId);
  }
  void retry() {
    setState(() => manifest = widget.api.fetchManifest(widget.noteId));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SMIUNotes Reader')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: manifest,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.hasError) {
          return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Reader unavailable. Note may require verification.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: retry,
                icon: const Icon(Icons.refresh), label: const Text('Retry')),
            ],
          ));
        }
        final data = snapshot.data!;
        final pages = data['pages'] is List
            ? data['pages'] as List<dynamic> : <dynamic>[];
        return ListView.builder(
          key: const Key('note-reader'),
          padding: const EdgeInsets.all(14),
          itemCount: pages.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['title']?.toString() ?? 'Note',
                      style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Pages: ${pages.length}'),
                    if ((data['description']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(data['description'].toString()),
                    ],
                  ],
                ),
              );
            }
            final raw = pages[index - 1];
            if (raw is! Map<String, dynamic>) return const SizedBox.shrink();
            final number = (raw['page_number'] as num?)?.toInt() ?? index;
            final width = (raw['width'] as num?)?.toDouble() ?? 800;
            final height = (raw['height'] as num?)?.toDouble() ?? 1100;
            return _SignedNotePage(
              key: ValueKey(number),
              api: widget.api, noteId: widget.noteId, number: number,
              aspectRatio: width > 0 && height > 0 ? width / height : 0.72,
            );
          },
        );
      },
    ),
  );
}

class _SignedNotePage extends StatefulWidget {
  const _SignedNotePage({
    super.key, required this.api, required this.noteId,
    required this.number, required this.aspectRatio,
  });
  final PublicFeedApi api;
  final String noteId;
  final int number;
  final double aspectRatio;
  @override
  State<_SignedNotePage> createState() => _SignedNotePageState();
}

class _SignedNotePageState extends State<_SignedNotePage> {
  late Future<String> signedUrl;
  @override
  void initState() {
    super.initState();
    signedUrl = widget.api.fetchSignedPageUrl(widget.noteId, widget.number);
  }
  void retry() {
    setState(() => signedUrl =
      widget.api.fetchSignedPageUrl(widget.noteId, widget.number));
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 20),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      Padding(padding: const EdgeInsets.all(10),
        child: Text('Page ${widget.number}')),
      AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: FutureBuilder<String>(
          future: signedUrl,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(child: OutlinedButton.icon(
                onPressed: retry, icon: const Icon(Icons.refresh),
                label: const Text('Retry page')));
            }
            return Image.network(
              snapshot.data!, fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Center(
                child: OutlinedButton.icon(onPressed: retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh expired page')),
              ),
            );
          },
        ),
      ),
    ]),
  );
}
