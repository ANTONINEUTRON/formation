import 'package:flutter/material.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Edits the player's name, bio and email.
///
/// Name and bio are public — they appear on the leaderboard and on the manager
/// profile other players see. Email is private and the sheet says so, because
/// nobody should have to guess which of these strangers can read.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    required this.profile,
    required this.repository,
    super.key,
  });

  final Profile profile;
  final FormationRepository repository;

  /// Returns the updated profile, or null if the player backed out.
  static Future<Profile?> show(
    BuildContext context, {
    required Profile profile,
    required FormationRepository repository,
  }) =>
      showModalBottomSheet<Profile>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => EditProfileSheet(profile: profile, repository: repository),
      );

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  static const _maxBio = 160;

  late final _username = TextEditingController(text: widget.profile.username);
  late final _bio = TextEditingController(text: widget.profile.bio ?? '');
  late final _email = TextEditingController(text: widget.profile.email ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await widget.repository.updateProfile(
        username: _username.text.trim(),
        bio: _bio.text.trim(),
        email: _email.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
      context.showSuccessToast(message: 'Profile updated.');
    } catch (e) {
      // The backend owns the rules — "that name is taken", "3-20 characters" —
      // and writes those messages for players, so show them as they are.
      if (!mounted) return;
      setState(() => _saving = false);
      context.showErrorToast(message: errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              enabled: !_saving,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'Display name',
                helperText: 'Public. 3–20 letters, numbers or underscores.',
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _bio,
              enabled: !_saving,
              maxLength: _maxBio,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Bio',
                helperText: 'Public. Shown to anyone who opens your profile.',
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _email,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                helperText: 'Private. Never shown to other players.',
                prefixIcon: Icon(Icons.lock_outline, size: 18),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
