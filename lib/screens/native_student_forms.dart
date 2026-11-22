import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import '../services/native_student_forms_api.dart';
import '../services/mobile_turnstile.dart';

/// Native contact form using the shared website intake and contact-scoped proof.
class NativeContactFormPage extends StatefulWidget {
  const NativeContactFormPage({super.key, required this.api, required this.baseUrl,
    this.signedIn = false});
  final NativeStudentFormsApi api;
  final String baseUrl;
  final bool signedIn;
  @override
  State<NativeContactFormPage> createState() => _NativeContactFormPageState();
}

class _NativeContactFormPageState extends State<NativeContactFormPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(), email = TextEditingController(),
      subject = TextEditingController(), message = TextEditingController();
  String topic = 'question';
  late final DateTime started = DateTime.now();
  bool sending = false, success = false;
  String? error;
  @override
  void dispose() {
    name.dispose(); email.dispose(); subject.dispose(); message.dispose();
    super.dispose();
  }
  Future<void> submit() async {
    if (sending || !form.currentState!.validate()) return;
    setState(() { sending = true; error = null; });
    try {
      final proof = await requestMobileTurnstile(context,
        httpsOrigin: widget.baseUrl, purpose: 'contact');
      if (proof == null || proof.isEmpty) throw StateError('Security check incomplete.');
      final elapsed = DateTime.now().difference(started).inMilliseconds;
      await widget.api.sendContact(name: name.text.trim(),
        email: email.text.trim(), topic: topic,
        subject: subject.text.trim(), message: message.text.trim(),
        proof: proof, elapsedMs: elapsed, signedIn: widget.signedIn);
      if (mounted) setState(() => success = true);
    } catch (_) {
      if (mounted) setState(() => error =
        'Message could not be sent. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Contact SMIUNotes')),
    body: success ? const Center(child: Text('Your message was received. Thank you.'))
      : Form(key: form, child: ListView(
        padding: const EdgeInsets.all(20), children: [
          const Text('How can we help?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (!widget.signedIn) ...[
            TextFormField(controller: name, maxLength: 80,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null),
            TextFormField(controller: email, maxLength: 254,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => RegExp(r'^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$')
                .hasMatch((v ?? '').trim()) ? null : 'Enter a valid email'),
          ] else
            TextFormField(controller: subject, maxLength: 160,
              decoration: const InputDecoration(labelText: 'Subject'),
              validator: (v) => (v ?? '').trim().length >= 3
                ? null : 'Enter a subject'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: topic,
            decoration: const InputDecoration(labelText: 'Issue category'),
            items: const [
              DropdownMenuItem(value: 'question', child: Text('General question')),
              DropdownMenuItem(value: 'correction', child: Text('Correction')),
              DropdownMenuItem(value: 'contribution', child: Text('Contribute notes')),
              DropdownMenuItem(value: 'copyright', child: Text('Copyright / takedown')),
              DropdownMenuItem(value: 'privacy', child: Text('Privacy / deletion')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => topic = v ?? 'question'),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: message, maxLength: 4000,
            minLines: 5, maxLines: 9,
            decoration: const InputDecoration(labelText: 'Message'),
            validator: (v) => (v ?? '').trim().length >= 10
              ? null : 'Write at least 10 characters'),
          const Text('Never include passwords, OTPs or sensitive secrets.',
            style: TextStyle(fontSize: 12)),
          if (error != null) Padding(padding: const EdgeInsets.all(12),
            child: Text(error!, style: TextStyle(
              color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('native-contact-submit'),
            onPressed: sending ? null : submit,
            icon: const Icon(Icons.send_outlined),
            label: Text(sending ? 'Sending…' : 'Send message'),
          ),
        ],
      )),
  );
}

/// Native image selection for the existing authorized verification RPC.
class NativeStudentCardFormPage extends StatefulWidget {
  const NativeStudentCardFormPage({super.key, required this.api});
  final NativeStudentFormsApi api;
  @override
  State<NativeStudentCardFormPage> createState() => _NativeStudentCardFormPageState();
}
class _NativeStudentCardFormPageState extends State<NativeStudentCardFormPage> {
  Uint8List? card;
  bool busy = false, done = false;
  String? error;
  Future<void> pick() async {
    try {
      final bytes = await NativeStudentFormsApi.chooseImage();
      if (bytes != null && mounted) setState(() { card = bytes; error = null; });
    } catch (_) {
      if (mounted) setState(() => error =
        'Choose a JPG, PNG or WebP between 2 KB and 2.5 MB.');
    }
  }
  Future<void> send() async {
    if (busy || card == null) return;
    setState(() { busy = true; error = null; });
    try {
      await widget.api.submitStudentCard(card!);
      if (mounted) setState(() { done = true; card = null; });
    } catch (_) {
      if (mounted) setState(() => error =
        'Card was not submitted. Check your status and try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Verify Student ID')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Student identity verification',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      const Text('Upload only your own SMIU Student Card. You may cover '
        'your photograph, but keep the name and Student ID readable.'),
      const SizedBox(height: 18),
      if (done) const Text('Submitted for admin review. Your existing '
        'provisional verification deadline remains in effect.')
      else ...[
        OutlinedButton.icon(onPressed: busy ? null : pick,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(card == null ? 'Choose card image' :
            'Image selected (${card!.length} bytes)')),
        const SizedBox(height: 12),
        FilledButton(onPressed: busy || card == null ? null : send,
          key: const Key('native-card-submit'),
          child: Text(busy ? 'Submitting…' : 'Submit Student Card')),
      ],
      if (error != null) Text(error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]),
  );
}

/// Native support claim: verified students only; never marks a transfer paid.
class NativeSupportFormPage extends StatefulWidget {
  const NativeSupportFormPage({super.key, required this.api});
  final NativeStudentFormsApi api;
  @override
  State<NativeSupportFormPage> createState() => _NativeSupportFormPageState();
}
class _NativeSupportFormPageState extends State<NativeSupportFormPage> {
  late Future<Map<String, dynamic>> details;
  final amount = TextEditingController(text: '100'),
    phone = TextEditingController(), note = TextEditingController();
  String? methodId, error;
  Uint8List? receipt;
  bool consent = false, publicName = false, publicAmount = false,
    busy = false, done = false;

  @override
  void initState() { super.initState(); details = widget.api.supportOptions(); }
  @override
  void dispose() { amount.dispose(); phone.dispose(); note.dispose(); super.dispose(); }

  Future<void> pick() async {
    try {
      final bytes = await NativeStudentFormsApi.chooseImage();
      if (bytes != null && mounted) setState(() { receipt = bytes; error = null; });
    } catch (_) {
      if (mounted) setState(() => error = 'Select a valid receipt image (max 2.5 MB).');
    }
  }

  Future<void> submit() async {
    if (busy || !consent || receipt == null || methodId == null) return;
    if (!RegExp(r'^(?:0|[1-9][0-9]*)(?:\\.[0-9]{1,2})?$')
        .hasMatch(amount.text.trim()) ||
        !RegExp(r'^03[0-9]{9}$').hasMatch(phone.text.trim())) {
      setState(() => error = 'Check your amount and 11-digit phone number.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await widget.api.submitSupport(
        receipt: receipt!, methodId: methodId!, amount: amount.text.trim(),
        phone: phone.text.trim(), note: note.text.trim(), name: '',
        publicName: publicName, publicAmount: publicName && publicAmount);
      if (mounted) setState(() { done = true; receipt = null; });
    } catch (_) {
      if (mounted) setState(() => error =
        'Submission could not be confirmed. If the receipt was uploaded, '
        'contact the team before submitting again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Support SMIUNotes')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: details,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.hasError) return Center(child: TextButton(
            onPressed: () => setState(() { details = widget.api.supportOptions(); }),
            child: const Text('Unable to load methods. Retry')));
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!['eligible'] != true) {
          return const Center(child: Padding(padding: EdgeInsets.all(24),
            child: Text('Student Card verification is required before '
              'submitting a support claim in the app.')));
        }
        final methods = (snapshot.data!['methods'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>().toList();
        if (methods.isEmpty) return const Center(child: Text(
          'No payment methods are currently available.'));
        final chosen = methodId ?? methods.first['id']?.toString() ?? '';
        final selection = methods.firstWhere(
          (m) => m['id']?.toString() == chosen, orElse: () => methods.first);
        return ListView(
          key: const Key('native-support-form'),
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Support free student notes',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('Only submit after making your transfer. '
              'Payment confirmation requires independent admin review.'),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: chosen,
              decoration: const InputDecoration(labelText: 'Transfer method'),
              items: [for (final m in methods)
                DropdownMenuItem(value: m['id']?.toString(),
                  child: Text(m['label']?.toString() ?? 'Bank'))],
              onChanged: (v) => setState(() => methodId = v),
            ),
            const SizedBox(height: 12),
            SelectableText('Recipient: ${selection['recipient_name'] ?? ''}'),
            SelectableText('Account/IBAN: ${selection['payment_identifier'] ?? ''}'),
            Text(selection['instructions']?.toString() ?? ''),
            const SizedBox(height: 12),
            TextField(controller: amount, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount (PKR)')),
            TextField(controller: phone, keyboardType: TextInputType.phone,
              maxLength: 11, decoration: const InputDecoration(
                labelText: 'Contact phone (03XXXXXXXXX)')),
            TextField(controller: note, maxLength: 350,
              decoration: const InputDecoration(labelText: 'Message (optional)')),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: busy ? null : pick,
              icon: const Icon(Icons.receipt_long),
              label: Text(receipt == null ? 'Select receipt image'
                : 'Receipt selected')),
            CheckboxListTile(
              title: const Text('Show my name on Supporters Wall (optional)'),
              value: publicName,
              onChanged: (v) => setState(() {
                publicName = v == true;
                if (!publicName) publicAmount = false;
              })),
            if (publicName)
              CheckboxListTile(
                title: const Text('Show my verified amount (optional)'),
                value: publicAmount,
                onChanged: (v) => setState(() => publicAmount = v == true)),
            CheckboxListTile(
              title: const Text('This support is voluntary and subject to bank review.'),
              value: consent,
              onChanged: (v) => setState(() => consent = v == true)),
            if (error != null) Text(error!, style: TextStyle(
              color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 14),
            if (done) const Text('Receipt claim sent for manual review.')
            else FilledButton(
              key: const Key('native-support-submit'),
              onPressed: busy || !consent || receipt == null ? null : submit,
              child: Text(busy ? 'Submitting…' : 'Submit transfer receipt')),
          ],
        );
      },
    ),
  );
}
