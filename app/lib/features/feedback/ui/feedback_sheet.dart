import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/features/feedback/domain/feedback.dart';
import 'package:formation/features/shared/data/formation_repository.dart';

/// "Send feedback": a bug, an idea or anything else, with an optional rating
/// and screenshot. There's no email field: replies go to the profile email,
/// and the sheet says which one (or how to add one).
class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({required this.repository, this.replyEmail, super.key});

  final FormationRepository repository;

  /// The profile email replies go to; null when there isn't one.
  final String? replyEmail;

  static Future<void> show(
    BuildContext context, {
    required FormationRepository repository,
    String? replyEmail,
  }) =>
      showAdaptiveSheet<void>(
        context: context,
        builder: (_) => FeedbackSheet(repository: repository, replyEmail: replyEmail),
      );

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  FeedbackKind _kind = FeedbackKind.idea;
  int? _rating;
  final _message = TextEditingController();
  Uint8List? _screenshot;
  String _mime = 'image/png';
  String? _screenshotError;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Send turns on once there's something to read.
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _canSend => !_sending && _message.text.trim().length >= FeedbackLimits.minMessage;

  Future<void> _pickScreenshot() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > FeedbackLimits.maxScreenshotBytes) {
      setState(() => _screenshotError = 'That screenshot is too large (5 MB max).');
      return;
    }
    setState(() {
      _screenshot = bytes;
      _screenshotError = null;
      _mime = switch ((file.extension ?? 'png').toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        _ => 'image/png',
      };
    });
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await widget.repository.sendFeedback(
        kind: _kind,
        message: _message.text.trim(),
        rating: _rating,
        screenshot: _screenshot,
        screenshotMime: _screenshot == null ? null : _mime,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      context.showSuccessToast(message: 'Thanks — we read every one.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      context.showErrorToast(message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.replyEmail;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Send feedback', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<FeedbackKind>(
              segments: [
                for (final kind in FeedbackKind.values) ButtonSegment(value: kind, label: Text(kind.label)),
              ],
              selected: {_kind},
              onSelectionChanged: _sending ? null : (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 18),
            const Text(
              "How's Formation so far?",
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (var n = 1; n <= 5; n++)
                  IconButton(
                    tooltip: '$n of 5',
                    visualDensity: VisualDensity.compact,
                    // Tapping the chosen one again clears it: the rating is optional.
                    onPressed: _sending ? null : () => setState(() => _rating = _rating == n ? null : n),
                    icon: Icon(
                      _rating != null && n <= _rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: _rating != null && n <= _rating! ? AppColors.warning : AppColors.textMuted,
                      size: 30,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _message,
              enabled: !_sending,
              minLines: 3,
              maxLines: 6,
              maxLength: FeedbackLimits.maxMessage,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: _kind.hint),
            ),
            const SizedBox(height: 4),
            if (_screenshot == null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _sending ? null : _pickScreenshot,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Add a screenshot'),
                ),
              )
            else
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_screenshot!, width: 56, height: 56, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Screenshot attached', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  IconButton(
                    tooltip: 'Remove screenshot',
                    onPressed: _sending ? null : () => setState(() => _screenshot = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            if (_screenshotError != null)
              Text(_screenshotError!, style: const TextStyle(fontSize: 12, color: AppColors.error)),
            const SizedBox(height: 8),
            Text(
              email == null || email.isEmpty
                  ? "Add an email to your profile if you'd like a reply."
                  : "We'll reply to $email.",
              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _canSend ? _send : null,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_sending ? 'Sending…' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}
