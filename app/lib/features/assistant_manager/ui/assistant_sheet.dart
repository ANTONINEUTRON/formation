import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/layout/breakpoints.dart';
import 'package:formation/core/route/app_route.dart';
import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/extensions/context_extensions.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/cubits/assistant_cubit.dart';
import 'package:formation/features/assistant_manager/ui/widgets/buy_credits_sheet.dart';
import 'package:formation/features/assistant_manager/ui/widgets/character_picker.dart';
import 'package:formation/features/assistant_manager/ui/widgets/character_view.dart';
import 'package:formation/features/assistant_manager/ui/widgets/glass_panel.dart';
import 'package:formation/features/assistant_manager/ui/widgets/suggestion_card.dart';
import 'package:formation/features/shared/domain/models.dart';

/// Opens the Assistant Manager over the current screen: a glass sheet the
/// Manager can drag taller on a phone, a glass dialog on a wider window.
Future<void> showAssistantSheet(BuildContext context, AssistantContext assistantContext) {
  final cubit = context.read<AssistantCubit>();
  if (cubit.state.profile == null) cubit.load();
  final content = BlocProvider.value(
    value: cubit,
    child: AssistantSheet(context: assistantContext),
  );

  if (context.layoutSize.isCompact) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (sheetContext, scroll) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: GlassPanel(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: PrimaryScrollController(controller: scroll, child: content),
          ),
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (dialogContext) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: (MediaQuery.sizeOf(dialogContext).height * 0.88).clamp(420, 760),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: GlassPanel(borderRadius: BorderRadius.circular(28), child: content),
          ),
        ),
      ),
    ),
  );
}

class AssistantSheet extends StatefulWidget {
  const AssistantSheet({required this.context, super.key});

  final AssistantContext context;

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  bool _changingCharacter = false;

  @override
  Widget build(BuildContext context) {
    final compact = context.layoutSize.isCompact;
    return BlocBuilder<AssistantCubit, AssistantState>(
      builder: (context, state) {
        final profile = state.profile;
        final Widget body;
        if (profile == null) {
          body = state.error != null
              ? _Centered(
                  message: state.error!,
                  action: TextButton(
                    onPressed: () => context.read<AssistantCubit>().load(),
                    child: const Text('Try again'),
                  ),
                )
              : const Center(child: CircularProgressIndicator(color: AppColors.primary));
        } else if (!profile.available) {
          body = const _Centered(message: 'Your Assistant Manager is off duty right now. Check back soon.');
        } else if (profile.character == null || _changingCharacter) {
          body = Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: CharacterPicker(
              characters: profile.characters,
              currentId: profile.characterId,
              onPicked: (id) async {
                await context.read<AssistantCubit>().pickCharacter(id);
                if (mounted) setState(() => _changingCharacter = false);
              },
            ),
          );
        } else {
          body = _Chat(
            assistantContext: widget.context,
            state: state,
            character: profile.character!,
            onChangeCharacter: () => setState(() => _changingCharacter = true),
          );
        }

        return Column(
          children: [
            if (compact) const _Grabber(),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

class _Chat extends StatefulWidget {
  const _Chat({
    required this.assistantContext,
    required this.state,
    required this.character,
    required this.onChangeCharacter,
  });

  final AssistantContext assistantContext;
  final AssistantState state;
  final AssistantCharacter character;
  final VoidCallback onChangeCharacter;

  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  SportMode get _mode => widget.assistantContext.mode;

  @override
  void didUpdateWidget(covariant _Chat old) {
    super.didUpdateWidget(old);
    final before = old.state.conversation(_mode).length + (old.state.sending ? 1 : 0);
    final after = widget.state.conversation(_mode).length + (widget.state.sending ? 1 : 0);
    if (after > before) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final message = text ?? _input.text;
    if (message.trim().isEmpty) return;
    context.read<AssistantCubit>().send(widget.assistantContext, message);
    _input.clear();
  }

  Future<void> _buyFirst(int messageIndex, int suggestionIndex, FillSlotSuggestion s) async {
    final cubit = context.read<AssistantCubit>();
    final router = context.router;
    cubit.handedToPurchase(_mode, messageIndex, suggestionIndex);
    Navigator.of(context).pop();
    context.showInfoToast(message: 'Tap ${s.position} and buy ${s.symbol} to play it.');
    await router.push(DraftBoardRoute(mode: _mode));
  }

  void _buyCredits() {
    final profile = widget.state.profile;
    if (profile == null || !profile.canBuyCredits) return;
    BuyCreditsSheet.show(context, profile.packs);
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final messages = state.conversation(_mode);
    final credits = state.profile?.credits ?? 0;

    return Column(
      children: [
        _Header(
          character: widget.character,
          pose: state.pose,
          mode: _mode,
          credits: credits,
          onBuyCredits: state.profile?.canBuyCredits == true ? _buyCredits : null,
          onChangeCharacter: widget.onChangeCharacter,
          onNewConversation: messages.isEmpty
              ? null
              : () => context.read<AssistantCubit>().clearConversation(_mode),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: messages.isEmpty && !state.sending
              ? _Welcome(character: widget.character, pose: state.pose, mode: _mode)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length + (state.sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == messages.length) return const _Thinking();
                    final message = messages[i];
                    return _MessageView(
                      message: message,
                      onApply: (j) {
                        final s = message.suggestions[j];
                        if (s is FillSlotSuggestion && s.needsPurchase) {
                          _buyFirst(i, j, s);
                        } else {
                          context.read<AssistantCubit>().apply(_mode, i, j);
                        }
                      },
                    );
                  },
                ),
        ),
        if (state.error != null)
          _Notice(text: state.error!, onDismiss: () => context.read<AssistantCubit>().dismissError())
        else if (state.outOfCredits)
          _Notice(
            text: state.profile?.canBuyCredits == true
                ? "You're out of credits."
                : "You're out of credits. Buying more isn't available yet.",
            action: state.profile?.canBuyCredits == true
                ? TextButton(onPressed: _buyCredits, child: const Text('Buy credits'))
                : null,
          ),
        _QuickPrompts(
          prompts: _promptsFor(widget.assistantContext),
          enabled: !state.sending && !state.outOfCredits,
          onTap: _send,
        ),
        _Composer(controller: _input, enabled: !state.sending && !state.outOfCredits, onSend: _send),
      ],
    );
  }
}

/// Starters that fit where the Manager opened the assistant from.
List<String> _promptsFor(AssistantContext context) => switch (context.screen) {
  'draft' => ['Fill my empty slots', 'Which formation suits me?', 'Explain the tiers'],
  'league' || 'leagues' => ['How do I climb the table?', 'Why am I losing points?', 'Explain scoring'],
  _ => [
    'Review my squad',
    if (context.mode != SportMode.americanFootball) 'Who should I captain?',
    'Why am I losing points?',
    'How does scoring work?',
  ],
};

class _Header extends StatelessWidget {
  const _Header({
    required this.character,
    required this.pose,
    required this.mode,
    required this.credits,
    required this.onBuyCredits,
    required this.onChangeCharacter,
    required this.onNewConversation,
  });

  final AssistantCharacter character;
  final AssistantPose pose;
  final SportMode mode;
  final int credits;
  final VoidCallback? onBuyCredits;
  final VoidCallback onChangeCharacter;
  final VoidCallback? onNewConversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Row(
        children: [
          CharacterHead(character: character, pose: pose),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Assistant Manager · ${mode.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Tooltip(
            message:
                '$credits credit${credits == 1 ? '' : 's'} left · 1 per reply'
                '${onBuyCredits != null ? ' · tap to buy more' : ''}',
            child: InkWell(
              onTap: onBuyCredits,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: credits > 0 ? 0.14 : 0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: credits > 0 ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.toll_outlined,
                      size: 14,
                      color: credits > 0 ? AppColors.primary : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$credits',
                      style: AppTextStyles.mono(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: credits > 0 ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.surfaceElevated,
            onSelected: (value) => value == 'change' ? onChangeCharacter() : onNewConversation?.call(),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'change', child: Text('Change Assistant Manager')),
              PopupMenuItem(
                value: 'new',
                enabled: onNewConversation != null,
                child: const Text('New conversation'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.character, required this.pose, required this.mode});

  final AssistantCharacter character;
  final AssistantPose pose;
  final SportMode mode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          children: [
            CharacterFigure(character: character, pose: pose, height: (box.maxHeight * 0.68).clamp(140, 300)),
            const SizedBox(height: 12),
            Text(
              "Gaffer, I'm ${character.name.replaceFirst('The ', 'your ')}.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Ask me anything about your ${mode.label.toLowerCase()} team. I advise — you make the calls.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.message, required this.onApply});

  final AssistantMessage message;
  final ValueChanged<int> onApply;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == AssistantRole.manager;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
                border: Border.all(
                  color: mine
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Text(message.text, style: const TextStyle(color: AppColors.textPrimary, height: 1.4)),
            ),
          ),
          for (var j = 0; j < message.suggestions.length; j++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SuggestionCard(
                suggestion: message.suggestions[j],
                status: message.statuses[j],
                onApply: () => onApply(j),
              ),
            ),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
          SizedBox(width: 10),
          Text('Thinking it over…', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.onDismiss, this.action});

  final String text;
  final VoidCallback? onDismiss;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ),
          ?action,
          if (onDismiss != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.prompts, required this.enabled, required this.onTap});

  final List<String> prompts;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(prompts[i]),
          onPressed: enabled ? () => onTap(prompts[i]) : null,
          backgroundColor: Colors.white.withValues(alpha: 0.05),
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
          labelStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.enabled, required this.onSend});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                maxLength: 1000,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask your Assistant Manager…',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: enabled ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverse,
              ),
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
