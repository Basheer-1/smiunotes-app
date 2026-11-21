import 'package:material_ui/material_ui.dart';

import '../services/authenticated_reader_api.dart';

typedef AuthorizedNoteRequest = Future<Map<String, dynamic>> Function({
  required String accessToken,
  required String noteId,
  required bool manifest,
  int? page,
});

/// Staging-only protected reader. Existing note-media performs the final
/// Student Card authorization and signs each page only when requested.
class AuthenticatedNoteReaderPage extends StatefulWidget {
  const AuthenticatedNoteReaderPage({
    super.key,
    required this.noteId,
    required this.accessToken,
    this.api,
    this.request,
  });

  final String noteId;
  final String accessToken;
  final AuthenticatedReaderApi? api;
  final AuthorizedNoteRequest? request;

  @override
  State<AuthenticatedNoteReaderPage> createState() =>
      _AuthenticatedNoteReaderPageState();
}

class _AuthenticatedNoteReaderPageState extends State<AuthenticatedNoteReaderPage> {
  late Future<Map<String, dynamic>> manifest;
  int _sessionRevision = 0;

  Future<Map<String, dynamic>> fetch({bool isManifest = true, int? page}) {
    final call = widget.request ?? widget.api?.request;
    if (call == null) {
      throw StateError('Authorized reader client was not configured.');
    }
    return call(
      accessToken: widget.accessToken,
      noteId: widget.noteId,
      manifest: isManifest,
      page: page,
    );
  }

  @override
  void initState() {
    super.initState();
    manifest = fetch();
  }

  @override
  void didUpdateWidget(covariant AuthenticatedNoteReaderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId ||
        oldWidget.accessToken != widget.accessToken ||
        oldWidget.request != widget.request ||
        oldWidget.api != widget.api) {
      _sessionRevision++;
      manifest = fetch();
    }
  }

  void retry() => setState(() => manifest = fetch());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verified Notes Reader')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: manifest,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Note unavailable or verification has expired.'),
              OutlinedButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry authorized request'),
              ),
            ],
          ));
        }
        final data = snapshot.data!;
        final pages = data['pages'] is List
            ? data['pages'] as List<dynamic> : const <dynamic>[];
        return ListView.builder(
          key: const Key('authenticated-note-reader'),
          padding: const EdgeInsets.all(18),
          itemCount: pages.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title']?.toString() ?? 'Note',
                    style: const TextStyle(fontSize: 24,
                      fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Pages: ${pages.length}'),
                  const SizedBox(height: 16),
                ],
              );
            }
            final item = pages[index - 1];
            if (item is! Map<String, dynamic>) {
              return const SizedBox.shrink();
            }
            final number = (item['page_number'] as num?)?.toInt() ?? index;
            final w = (item['width'] as num?)?.toDouble() ?? 800;
            final h = (item['height'] as num?)?.toDouble() ?? 1100;
            return _AuthorizedPage(
              key: ValueKey('protected-${widget.noteId}-$number-$_sessionRevision'),
              number: number,
              aspect: w > 0 && h > 0 ? w / h : 0.72,
              loader: () => fetch(isManifest: false, page: number),
            );
          },
        );
      },
    ),
  );
}

class _AuthorizedPage extends StatefulWidget {
  const _AuthorizedPage({
    super.key, required this.number, required this.aspect,
    required this.loader,
  });

  final int number;
  final double aspect;
  final Future<Map<String, dynamic>> Function() loader;

  @override
  State<_AuthorizedPage> createState() => _AuthorizedPageState();
}

class _AuthorizedPageState extends State<_AuthorizedPage> {
  late Future<Map<String, dynamic>> page;
  // Signed WebP images are sensitive. Evict only our own URLs when leaving
  // this page; never clear the app-wide cache used by public content.
  final Set<String> _signedUrls = <String>{};

  void _evictSignedPages() {
    for (final url in _signedUrls) {
      NetworkImage(url).evict();
    }
    _signedUrls.clear();
  }

  @override
  void dispose() {
    _evictSignedPages();
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    page = widget.loader();
  }

  void retry() {
    _evictSignedPages();
    setState(() => page = widget.loader());
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 20),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text('Page ${widget.number}'),
        ),
        AspectRatio(
          aspectRatio: widget.aspect,
          child: FutureBuilder<Map<String, dynamic>>(
            future: page,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final value = snapshot.data;
              if (snapshot.hasError || value == null) {
                return Center(child: OutlinedButton(
                  onPressed: retry, child: const Text('Retry page')));
              }
              final url = Uri.tryParse(value['url']?.toString() ?? '');
              if (url == null || url.scheme != 'https' ||
                  url.userInfo.isNotEmpty) {
                return const Center(child: Text('Invalid signed page.'));
              }
              _signedUrls.add(url.toString());
              return Image.network(
                url.toString(),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: OutlinedButton(
                    onPressed: retry,
                    child: const Text('Refresh expired page'),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
