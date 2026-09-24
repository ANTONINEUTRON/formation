import 'package:flutter/material.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/features/leagues/ui/cubits/leagues_cubit.dart';

/// Durations the backend accepts.
const _durations = <Duration>[
  Duration(hours: 1),
  Duration(hours: 6),
  Duration(hours: 24),
  Duration(days: 3),
  Duration(days: 7),
];

/// Creates a league, or a head-to-head duel when an opponent is named.
///
/// The creator picks when it starts and how long it runs; lineups lock when it
/// opens, while the general league keeps running underneath.
class CreateLeagueSheet extends StatefulWidget {
  const CreateLeagueSheet({required this.cubit, super.key});

  final LeaguesCubit cubit;

  static Future<void> show(BuildContext context, LeaguesCubit cubit) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => CreateLeagueSheet(cubit: cubit),
      );

  @override
  State<CreateLeagueSheet> createState() => _CreateLeagueSheetState();
}

class _CreateLeagueSheetState extends State<CreateLeagueSheet> {
  final _name = TextEditingController();
  final _opponent = TextEditingController();
  Duration _duration = _durations[2];
  bool _isPrivate = true;
  bool _isDuel = false;
  DateTime _startsAt = DateTime.now().add(const Duration(minutes: 5));
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _opponent.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(data: AppTheme.darkTheme, child: child!),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
      builder: (context, child) => Theme(data: AppTheme.darkTheme, child: child!),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_name.text.trim().length < 3) {
      context.showErrorToast(message: 'Give the league a name of 3 characters or more.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.cubit.create(
        name: _name.text.trim(),
        isPrivate: _isDuel || _isPrivate,
        startsAt: _startsAt,
        duration: _duration,
        opponent: _isDuel ? _opponent.text.trim() : null,
      );
      if (mounted) {
        Navigator.of(context).pop();
        context.showInfoToast(message: 'League created.');
      }
    } catch (e) {
      if (mounted) context.showErrorToast(message: errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'New league',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDuel,
              onChanged: (v) => setState(() => _isDuel = v),
              title: const Text('Head to head'),
              subtitle: const Text('Two players only, by username or wallet'),
            ),
            if (_isDuel)
              TextField(
                controller: _opponent,
                decoration: const InputDecoration(labelText: 'Opponent'),
              )
            else
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isPrivate,
                onChanged: (v) => setState(() => _isPrivate = v),
                title: const Text('Private'),
                subtitle: const Text('Only people with the code can join'),
              ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: _pickStart,
              leading: const Icon(Icons.schedule),
              title: const Text('Starts'),
              subtitle: Text(
                '${formatShortDate(_startsAt)} at '
                '${TimeOfDay.fromDateTime(_startsAt).format(context)}',
              ),
            ),
            const SizedBox(height: 8),
            const Text('Runs for', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final d in _durations)
                  ChoiceChip(
                    label: Text(formatDuration(d)),
                    selected: _duration == d,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _duration = d),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Creating…' : 'Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
