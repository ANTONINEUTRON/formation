import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/cubits/assistant_cubit.dart';
import 'package:formation/features/assistant_manager/ui/widgets/character_view.dart';

/// "Create from photo": the Manager uploads a photo, picks whose style their
/// own Assistant Manager should have, and four poses are drawn in the same
/// look as the presets. The photo is only used for the drawing.
class CreateAvatarSheet extends StatefulWidget {
  const CreateAvatarSheet({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<AssistantCubit>();
    return showAdaptiveSheet<void>(
      context: context,
      builder: (_) => BlocProvider.value(value: cubit, child: const CreateAvatarSheet()),
    );
  }

  @override
  State<CreateAvatarSheet> createState() => _CreateAvatarSheetState();
}

class _CreateAvatarSheetState extends State<CreateAvatarSheet> {
  static const _maxBytes = 5 * 1000 * 1000;

  Uint8List? _photo;
  String _mime = 'image/jpeg';
  String _personality = 'mentor';
  final _name = TextEditingController();
  bool _consent = false;
  bool _drawing = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxBytes) {
      setState(() => _error = 'That photo is too large (5 MB max).');
      return;
    }
    final ext = (file.extension ?? 'jpg').toLowerCase();
    setState(() {
      _photo = bytes;
      _mime = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      _error = null;
    });
  }

  Future<void> _draw() async {
    final photo = _photo;
    if (photo == null) return;
    setState(() {
      _drawing = true;
      _error = null;
    });
    final error = await context.read<AssistantCubit>().createAvatar(
      photo: photo,
      mimeType: _mime,
      personality: _personality,
      name: _name.text.trim(),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      context.showSuccessToast(message: 'Meet your new Assistant Manager.');
    } else {
      setState(() {
        _drawing = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cost = context.select<AssistantCubit, int>((c) => c.state.profile?.avatarCost ?? 0);
    final ready = _photo != null && _consent && !_drawing;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create your own Assistant Manager',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'The photo is only used for the '
              "drawing and isn't kept.",
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _drawing ? null : _pick,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _photo == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.primary),
                          SizedBox(height: 8),
                          Text(
                            'Choose a clear photo of one person',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      )
                    : Image.memory(_photo!, fit: BoxFit.cover, width: double.infinity),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Personality', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in presetCharacters)
                  ChoiceChip(
                    avatar: CharacterHead(character: c, pose: AssistantPose.neutral, size: 22),
                    label: Text(c.name.replaceFirst('The ', '')),
                    selected: _personality == c.id,
                    onSelected: _drawing ? null : (_) => setState(() => _personality = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              presetCharacters.firstWhere((c) => c.id == _personality).tagline,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              enabled: !_drawing,
              maxLength: 24,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\n\r]'))],
              decoration: const InputDecoration(labelText: 'Name (optional)', hintText: 'e.g. Coach Toly'),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _consent,
              onChanged: _drawing ? null : (v) => setState(() => _consent = v ?? false),
              title: const Text(
                'This is a photo of me, or I have permission to use it',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: ready ? _draw : null,
              child: Text(
                _drawing
                    ? 'Drawing… this takes about a minute'
                    : cost == 0
                    ? 'Draw my Assistant Manager · Free'
                    : 'Draw my Assistant Manager · $cost credits',
              ),
            ),
            if (_drawing)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(color: AppColors.primary),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
