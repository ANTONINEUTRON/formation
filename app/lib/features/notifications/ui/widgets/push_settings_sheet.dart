import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/adaptive_sheet.dart';
import 'package:formation/core/widgets/loading_indicator.dart';
import 'package:formation/features/notifications/data/push_controller.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Push settings: this device on or off, what to push, and quiet hours.
/// Everything still lands in the in-app inbox whatever is chosen here.
class PushSettingsSheet extends StatefulWidget {
  const PushSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    final repository = context.read<FormationRepository>();
    final controller = context.read<PushController>();
    return showAdaptiveSheet<void>(
      context: context,
      builder: (_) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: repository),
          RepositoryProvider.value(value: controller),
        ],
        child: const PushSettingsSheet(),
      ),
    );
  }

  @override
  State<PushSettingsSheet> createState() => _PushSettingsSheetState();
}

class _PushSettingsSheetState extends State<PushSettingsSheet> {
  PushSettings? _settings;
  bool _deviceOn = false;
  bool _busy = false;

  FormationRepository get _repository => context.read<FormationRepository>();
  PushController get _controller => context.read<PushController>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_repository.getPushSettings(), _controller.enabledToken()]);
      if (!mounted) return;
      setState(() {
        _settings = results[0] as PushSettings;
        _deviceOn = results[1] != null;
      });
    } catch (e) {
      if (mounted) context.showErrorToast(message: errorText(e));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) context.showErrorToast(message: errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleDevice(bool on) => _run(() async {
        if (on) {
          final ok = await _controller.enable();
          if (!ok && mounted) {
            context.showErrorToast(message: 'Notifications are blocked for Formation on this device.');
          }
          setState(() => _deviceOn = ok);
        } else {
          await _controller.disable();
          setState(() => _deviceOn = false);
        }
        final settings = await _repository.getPushSettings();
        if (mounted) setState(() => _settings = settings);
      });

  Future<void> _save({Map<String, bool>? categories, bool? quietEnabled, int? quietStart, int? quietEnd}) =>
      _run(() async {
        final settings = await _repository.savePushSettings(
          categories: categories,
          quietEnabled: quietEnabled,
          quietStart: quietStart,
          quietEnd: quietEnd,
          timeZone: deviceTimeZone(),
        );
        if (mounted) setState(() => _settings = settings);
      });

  Future<void> _pickTime({required bool start}) async {
    final settings = _settings!;
    final minutes = start ? settings.quietStart : settings.quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    final value = picked.hour * 60 + picked.minute;
    await _save(quietStart: start ? value : null, quietEnd: start ? null : value);
  }

  String _clock(int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) return const SizedBox(height: 280, child: LoadingIndicator());

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Push notifications', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            
            if (!settings.available) ...[
              const SizedBox(height: 10),
              const Text(
                "The server isn't sending pushes yet. Your choices are saved for when it does.",
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _deviceOn,
              onChanged: _busy ? null : _toggleDevice,
              title: const Text('Push to this device', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                settings.devices == 0 ? 'No devices yet' : '${settings.devices} device(s) registered',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const Divider(),
            for (final MapEntry(key: category, value: (title, detail)) in PushSettings.categoryLabels.entries)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: settings.isOn(category),
                onChanged: _busy ? null : (on) => _save(categories: {category: on}),
                title: Text(title),
                subtitle: Text(detail, style: const TextStyle(fontSize: 12)),
              ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.quietEnabled,
              onChanged: _busy ? null : (on) => _save(quietEnabled: on),
              title: const Text('Quiet hours'),
              subtitle: Text(
                'Nothing pushes between ${_clock(settings.quietStart)} and ${_clock(settings.quietEnd)} '
                '(${settings.timeZone})',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (settings.quietEnabled)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _pickTime(start: true),
                      child: Text('From ${_clock(settings.quietStart)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy ? null : () => _pickTime(start: false),
                      child: Text('Until ${_clock(settings.quietEnd)}'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
