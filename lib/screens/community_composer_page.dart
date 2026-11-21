import 'package:material_ui/material_ui.dart';
import '../services/community_write_api.dart';

/// Requires validated student access token; never mounted in default guest UI.
class CommunityComposerPage extends StatefulWidget {
  const CommunityComposerPage({
    super.key,
    required this.api,
    this.accessToken,
    this.tokenProvider,
    this.threadId,
  });
  final CommunityWriteApi api;
  final String? accessToken;
  final String Function()? tokenProvider;
  final String? threadId;

  @override
  State<CommunityComposerPage> createState() => _CommunityComposerPageState();
}

class _CommunityComposerPageState extends State<CommunityComposerPage> {
  final title = TextEditingController();
  final body = TextEditingController();
  String category = 'questions', error = '';
  bool saving = false;

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (saving) return;
    setState(() { saving = true; error = ''; });
    try {
      // Resolve at submit time, not at route creation, to honor logout/rotation.
      final token = widget.tokenProvider?.call() ?? widget.accessToken;
      if (token == null) throw StateError('Student sign-in required.');
      if (widget.threadId != null) {
        await widget.api.reply(
          accessToken: token,
          threadId: widget.threadId!,
          message: body.text,
        );
      } else {
        await widget.api.createDiscussion(
          accessToken: token,
          title: title.text,
          message: body.text,
          category: category,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => error =
          'Unable to post. Check the content, discussion lock, or posting limit.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(
      widget.threadId == null ? 'New discussion' : 'Reply to discussion')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.threadId == null) ...[
          TextField(
            key: const Key('composer-title'),
            controller: title,
            maxLength: 160,
            decoration: const InputDecoration(labelText: 'Discussion title'),
          ),
          DropdownButtonFormField<String>(
            initialValue: category,
            items: const [
              DropdownMenuItem(value: 'questions', child: Text('Questions')),
              DropdownMenuItem(value: 'study', child: Text('Study')),
              DropdownMenuItem(value: 'announcements',
                child: Text('Announcements')),
            ],
            onChanged: saving ? null :
              (value) => setState(() => category = value ?? 'questions'),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('composer-body'),
          controller: body,
          maxLength: widget.threadId == null ? 6000 : 3000,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(labelText: 'Message'),
        ),
        if (error.isNotEmpty)
          Text(error, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('composer-submit'),
          onPressed: saving ? null : submit,
          icon: const Icon(Icons.send),
          label: Text(saving ? 'Posting…' : 'Post'),
        ),
      ],
    ),
  );
}
