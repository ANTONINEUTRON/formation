import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:formation/core/theme/theme.dart';
import 'package:formation/core/utils/format.dart';
import 'package:formation/core/widgets/pay_token_picker.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/cubits/assistant_cubit.dart';
import 'package:formation/features/assistant_manager/ui/widgets/buy_credits_sheet.dart';
import 'package:formation/features/assistant_manager/ui/widgets/character_view.dart';
import 'package:formation/features/shared/data/formation_repository.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/shared/domain/roster_shapes.dart';
import 'package:formation/features/shared/ui/widgets/lineup_view.dart';
import 'package:formation/features/wallet/ui/widgets/fund_wallet_sheet.dart';

enum _Step { setup, drafting, review, applying, done, fromWallet }

enum _PickState { waiting, buying, placing, done, failed }

/// The free starter squad. The Manager picks a sport and a budget, their
/// Assistant Manager drafts a complete lineup, and on confirm the app buys
/// what they don't hold (each buy signed in the wallet) and fills the slots.
@RoutePage()
class StarterSquadPage extends StatefulWidget {
  const StarterSquadPage({this.mode, super.key});

  /// The sport to start on; basketball when opened from onboarding.
  final SportMode? mode;

  @override
  State<StarterSquadPage> createState() => _StarterSquadPageState();
}

class _StarterSquadPageState extends State<StarterSquadPage> {
  _Step _step = _Step.setup;
  SportMode _mode = SportMode.basketball;
  final _budget = TextEditingController(text: '10');
  String? _style;
  List<PayToken> _payTokens = const [PayToken.usdc];
  PayToken _payWith = PayToken.usdc;
  StarterSquad? _squad;
  String? _error;
  final Map<int, _PickState> _progress = {};
  final Map<int, String> _failures = {};

  /// Supported stocks the wallet already holds; 0 until checked.
  int _heldCount = 0;

  /// Sports whose team already has players, where a draft replaces picks.
  final Set<SportMode> _teamsWithPlayers = {};

  /// The last draft failed for want of credits: offer to buy some.
  bool _needsCredits = false;
  bool _usingWallet = false;

  /// Teams filled from the wallet, by sport, once "Use what I hold" ran.
  final Map<SportMode, Roster> _fromWallet = {};

  FormationRepository get _repository => context.read<FormationRepository>();

  @override
  void initState() {
    super.initState();
    _mode = widget.mode ?? SportMode.basketball;
    final slots = rosterShape(_mode).length;
    if ((double.tryParse(_budget.text) ?? 0) < slots) _budget.text = '$slots';
    _repository.getPayTokens().then((tokens) {
      if (mounted && tokens.isNotEmpty) setState(() => _payTokens = tokens);
    }).ignore();
    _countHoldings();
    _findTeamsWithPlayers();
  }

  Future<void> _findTeamsWithPlayers() async {
    for (final mode in SportMode.values) {
      try {
        final roster = await _repository.getRoster(mode);
        if (mounted && roster.slots.any((s) => s.isFilled)) setState(() => _teamsWithPlayers.add(mode));
      } catch (_) {
        // Unknown counts as empty: the draft still works, just without the warning.
      }
    }
  }

  Future<void> _countHoldings() async {
    try {
      final stocks = await _repository.getXStocks();
      final held = await _repository.getHeldBalances([for (final s in stocks) s.mint]);
      final count = held.values.where((amount) => amount > 0).length;
      if (mounted) setState(() => _heldCount = count);
    } catch (_) {
      // Without the count the Assistant Manager's draft is still on offer.
    }
  }

  /// Fields every sport's team from the stocks already in the wallet. The
  /// same stocks can play all three; a sport nothing fits is left empty.
  Future<void> _useWhatIHold() async {
    setState(() {
      _usingWallet = true;
      _error = null;
    });
    String? lastError;
    for (final mode in SportMode.values) {
      try {
        _fromWallet[mode] = await _repository.fillFromHoldings(mode);
      } catch (e) {
        lastError = errorText(e);
      }
    }
    if (!mounted) return;
    if (_fromWallet.isEmpty) {
      setState(() {
        _usingWallet = false;
        _error = lastError ?? "Couldn't build a team from your wallet. Try the draft below.";
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _usingWallet = false;
      _step = _Step.fromWallet;
      _mode = _fromWallet.containsKey(_mode) ? _mode : _fromWallet.keys.first;
    });
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  int get _slotCount => rosterShape(_mode).length;

  Future<void> _draft() async {
    final budget = double.tryParse(_budget.text.trim()) ?? 0;
    if (budget < _slotCount) {
      setState(
        () => _error = 'A ${_mode.label.toLowerCase()} squad needs at least \$$_slotCount (\$1 a player).',
      );
      return;
    }
    setState(() {
      _step = _Step.drafting;
      _error = null;
    });
    try {
      final squad = await _repository.draftStarterSquad(_mode, budgetUsd: budget, style: _style);
      if (!mounted) return;
      // Free drafts left and credits both move with a draft.
      context.read<AssistantCubit>().load().ignore();
      setState(() {
        _squad = squad;
        _step = _Step.review;
        _needsCredits = false;
      });
    } catch (e) {
      if (mounted) {
        final message = errorText(e);
        setState(() {
          _error = message;
          _needsCredits = message.contains('credits');
          _step = _squad == null ? _Step.setup : _Step.review;
        });
      }
    }
  }

  /// Leaves without drafting. The free drafts stay for another time.
  Future<void> _buildMyself() => context.router.maybePop();

  void _buyCredits() {
    final profile = context.read<AssistantCubit>().state.profile;
    if (profile == null || !profile.canBuyCredits) return;
    BuyCreditsSheet.show(context, profile.packs);
  }

  Future<void> _confirm(StarterSquad squad) async {
    setState(() {
      _step = _Step.applying;
      _progress
        ..clear()
        ..addAll({for (final p in squad.picks) p.slotIndex: _PickState.waiting});
      _failures.clear();
    });

    final stocks = {for (final s in await _repository.getXStocks()) s.mint: s};
    if (squad.formation != null) {
      try {
        await _repository.setFormation(squad.mode, squad.formation!);
      } catch (_) {
        // The default shape still takes every pick by position order.
      }
    }

    for (final pick in squad.picks) {
      if (!mounted) return;
      final stock = stocks[pick.mint];
      if (stock == null) {
        _fail(pick, 'No longer listed');
        continue;
      }
      try {
        if (pick.needsPurchase) {
          setState(() => _progress[pick.slotIndex] = _PickState.buying);
          final amount = _payWith.symbol == 'SKR' && squad.skrUsd != null
              ? pick.amountUsd / squad.skrUsd!
              : pick.amountUsd;
          final quote = await _repository.getSwapQuote(stock, amount, payWith: _payWith);
          await _repository.executeSwap(quote);
        }
        setState(() => _progress[pick.slotIndex] = _PickState.placing);
        await _repository.fillSlot(squad.mode, pick.slotIndex, stock);
        setState(() => _progress[pick.slotIndex] = _PickState.done);
      } catch (e) {
        _fail(pick, errorText(e));
      }
    }

    final placed = _progress.entries.where((e) => e.value == _PickState.done).map((e) => e.key).toSet();
    final captain = placed.contains(squad.captainSlot) ? squad.captainSlot : null;
    final vice = placed.contains(squad.viceCaptainSlot) ? squad.viceCaptainSlot : null;
    if (captain != null || vice != null) {
      await _repository.setCaptaincy(squad.mode, captainSlot: captain, viceCaptainSlot: vice).catchError((_) {
        return _repository.getRoster(squad.mode); // armbands can be set later on the team screen
      });
    }
    if (!mounted) return;
    context.read<AssistantCubit>().load().ignore();
    setState(() => _step = _Step.done);
  }

  void _fail(StarterPick pick, String reason) {
    if (!mounted) return;
    setState(() {
      _progress[pick.slotIndex] = _PickState.failed;
      _failures[pick.slotIndex] = reason;
    });
  }

  @override
  Widget build(BuildContext context) {
    final character =
        context.select<AssistantCubit, AssistantCharacter?>((c) => c.state.profile?.character) ??
        presetCharacters[3];
    final profile = context.select<AssistantCubit, AssistantProfile?>((c) => c.state.profile);
    final firstSquad = _teamsWithPlayers.isEmpty;
    final pose = switch (_step) {
      _Step.drafting || _Step.applying => AssistantPose.thinking,
      _Step.review || _Step.done || _Step.fromWallet => AssistantPose.celebrating,
      _Step.setup => AssistantPose.neutral,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(firstSquad ? 'Your first squad' : 'Assistant draft'),
        automaticallyImplyLeading: _step != _Step.applying,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Center(
                child: CharacterFigure(character: character, pose: pose, height: 180),
              ),
              const SizedBox(height: 12),
              ...switch (_step) {
                _Step.setup => _setup(character, profile, firstSquad),
                _Step.drafting => [_note('${character.name} is scouting the market…')],
                _Step.review => _review(_squad!, profile),
                _Step.applying || _Step.done => _applying(_squad!),
                _Step.fromWallet => _walletTeams(),
              },
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              if (_needsCredits && (profile?.canBuyCredits ?? false))
                Center(
                  child: TextButton.icon(
                    onPressed: _buyCredits,
                    icon: const Icon(Icons.bolt, size: 16),
                    label: const Text('Buy credits'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _note(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
  );

  List<Widget> _setup(AssistantCharacter character, AssistantProfile? profile, bool firstSquad) => [
    // Filling from the wallet only works on empty teams, so it's a first-squad offer.
    if (_heldCount > 0 && firstSquad) ...[
      _HoldingsCard(count: _heldCount, busy: _usingWallet, onUse: _useWhatIHold),
      const SizedBox(height: 20),
      const _Label('Or let your Assistant Manager draft one'),
    ],
    Text(
      'Let ${character.name.replaceFirst('The ', 'your ')} draft ${firstSquad ? 'your first squad' : 'a squad'}',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
    ),
    const SizedBox(height: 6),
    const Text(
      "Pick a sport and a budget. You'll see every pick, and why, before anything is bought.",
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textSecondary),
    ),
    Center(
      child: TextButton.icon(
        onPressed: () => FundWalletSheet.show(context),
        icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
        label: const Text('Need money in your wallet first?'),
      ),
    ),
    const SizedBox(height: 12),
    const _Label('Sport'),
    Wrap(
      spacing: 8,
      children: [
        for (final mode in SportMode.values)
          ChoiceChip(
            avatar: Icon(mode.icon, size: 16),
            label: Text(mode.label),
            selected: _mode == mode,
            onSelected: (_) => setState(() {
              _mode = mode;
              final budget = double.tryParse(_budget.text) ?? 0;
              if (budget < _slotCount) _budget.text = '$_slotCount';
            }),
          ),
      ],
    ),
    const SizedBox(height: 16),
    const _Label('Budget'),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _budget,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              prefixText: '\$ ',
              helperText: 'At least \$$_slotCount for $_slotCount players',
            ),
          ),
        ),
        const SizedBox(width: 12),
        PayTokenPicker(
          tokens: _payTokens,
          selected: _payWith,
          onChanged: (t) => setState(() => _payWith = t),
        ),
      ],
    ),
    const SizedBox(height: 16),
    const _Label('Style'),
    SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'safe', label: Text('Safe')),
        ButtonSegment(value: 'balanced', label: Text('Balanced')),
        ButtonSegment(value: 'bold', label: Text('Bold')),
      ],
      selected: {_style ?? character.style},
      onSelectionChanged: (s) => setState(() => _style = s.first),
    ),
    if (_teamsWithPlayers.contains(_mode)) ...[
      const SizedBox(height: 16),
      Text(
        'Your ${_mode.label.toLowerCase()} team already has players. Picks that replace them count as '
        "substitutions, so beyond today's free ones they cost points.",
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.warning),
      ),
    ],
    const SizedBox(height: 24),
    FilledButton(onPressed: _draft, child: Text('Draft my squad${_costLabel(profile)}')),
    if (profile != null) ...[
      const SizedBox(height: 6),
      Text(
        'You have ${profile.credits} credits',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    ],
    const SizedBox(height: 8),
    TextButton(onPressed: _buildMyself, child: const Text("I'll build it myself")),
  ];

  /// " · 3 credits": what a draft takes from the credit balance.
  String _costLabel(AssistantProfile? profile) {
    final cost = profile?.squadDraftCredits ?? 0;
    return cost == 0 ? '' : ' · $cost credits';
  }

  List<Widget> _review(StarterSquad squad, AssistantProfile? profile) {
    final spend = squad.toSpendUsd;
    final inSkr = _payWith.symbol == 'SKR' && squad.skrUsd != null;
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(squad.text, style: const TextStyle(color: AppColors.textPrimary, height: 1.4)),
      ),
      const SizedBox(height: 12),
      LineupView(roster: _asRoster(squad), title: 'Your squad', pitchOnly: true),
      const SizedBox(height: 16),
      const _Label('Why each pick'),
      for (final pick in squad.picks)
        _PickRow(
          pick: pick,
          armband: pick.slotIndex == squad.captainSlot
              ? 'C'
              : pick.slotIndex == squad.viceCaptainSlot
              ? 'V'
              : null,
        ),
      const SizedBox(height: 12),
      Text(
        spend == 0
            ? 'You already hold every pick. Nothing to buy.'
            : inSkr
            ? "You'll spend about ${formatAmount(spend / squad.skrUsd!)} SKR (\$${spend.toStringAsFixed(2)}), "
                  'signing one purchase per player.'
            : "You'll spend \$${spend.toStringAsFixed(2)} in ${_payWith.symbol}, signing one purchase per player.",
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      FilledButton(onPressed: () => _confirm(squad), child: const Text('Confirm & buy')),
      OutlinedButton(
        onPressed: _draft,
        child: Text('Draft again${_costLabel(profile)}'),
      ),
      TextButton(onPressed: _buildMyself, child: const Text("I'll build it myself")),
    ];
  }

  /// After "Use what I hold": each sport's team, with a switch between them.
  List<Widget> _walletTeams() {
    final roster = _fromWallet[_mode]!;
    final empty = roster.slots.where((s) => !s.isFilled).length;
    return [
      _note(
        _fromWallet.length == SportMode.values.length
            ? 'Your teams are set from your wallet, in all three sports.'
            : 'Your ${_fromWallet.keys.map((m) => m.label.toLowerCase()).join(' and ')} '
                  '${_fromWallet.length == 1 ? 'team is' : 'teams are'} set from your wallet.',
      ),
      const SizedBox(height: 12),
      if (_fromWallet.length > 1)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final mode in _fromWallet.keys)
              ChoiceChip(
                avatar: Icon(mode.icon, size: 16),
                label: Text(mode.label),
                selected: _mode == mode,
                onSelected: (_) => setState(() => _mode = mode),
              ),
          ],
        ),
      const SizedBox(height: 12),
      LineupView(roster: roster, title: 'Your ${_mode.label.toLowerCase()} team', pitchOnly: true),
      const SizedBox(height: 12),
      Text(
        empty == 0
            ? 'Every position is filled. Points start on the next price update; change anyone on the draft board.'
            : '$empty ${empty == 1 ? 'position is' : 'positions are'} still empty: nothing you hold fits '
                  "${empty == 1 ? 'it' : 'them'} yet. Fill them on the draft board whenever you like.",
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      FilledButton(onPressed: () => context.router.maybePop(), child: const Text('Go to my team')),
    ];
  }

  /// The drafted squad as a team, so it shows on the same pitch as every other.
  Roster _asRoster(StarterSquad squad) {
    final shape = rosterShape(squad.mode, squad.formation);
    final bySlot = {for (final p in squad.picks) p.slotIndex: p};
    return Roster(
      mode: squad.mode,
      formation: squad.formation,
      captainSlot: squad.captainSlot,
      viceCaptainSlot: squad.viceCaptainSlot,
      slots: [
        for (var i = 0; i < shape.length; i++)
          RosterSlot(
            position: shape[i],
            stock: bySlot[i] == null
                ? null
                : XStock(
                    symbol: bySlot[i]!.symbol,
                    companyName: bySlot[i]!.name,
                    mint: bySlot[i]!.mint,
                    tier: bySlot[i]!.tier,
                    priceUsd: bySlot[i]!.priceUsd,
                  ),
          ),
      ],
    );
  }

  List<Widget> _applying(StarterSquad squad) {
    final done = _step == _Step.done;
    final failed = _failures.length;
    return [
      _note(
        done
            ? failed == 0
                  ? 'Your squad is ready. Scoring starts on the next price update.'
                  : 'Squad set, with $failed pick${failed == 1 ? '' : 's'} still to fill. Players you hold already score.'
            : 'Building your squad. Approve each purchase in your wallet.',
      ),
      const SizedBox(height: 12),
      for (final pick in squad.picks)
        _PickRow(pick: pick, state: _progress[pick.slotIndex], failure: _failures[pick.slotIndex]),
      if (done) ...[
        const SizedBox(height: 16),
        FilledButton(onPressed: () => context.router.maybePop(), child: const Text('Go to my team')),
      ],
    ];
  }
}

/// "You already hold 6 stocks we support": the quickest way in for a Manager
/// who arrives with xStocks.
class _HoldingsCard extends StatelessWidget {
  const _HoldingsCard({required this.count, required this.busy, required this.onUse});

  final int count;
  final bool busy;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You already hold $count stock${count == 1 ? '' : 's'} we support',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Field them straight away, with nothing to buy. We pick the positions, the formation and '
            'the armbands; you can change any of it.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: busy ? null : onUse,
            icon: busy
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bolt, size: 18),
            label: const Text('Use what I hold'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: AppTextStyles.mono(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
    ),
  );
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.pick, this.armband, this.state, this.failure});

  final StarterPick pick;
  final String? armband;
  final _PickState? state;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    final trailing = switch (state) {
      null => Text(
        pick.needsPurchase ? '\$${pick.amountUsd.toStringAsFixed(2)}' : 'Held',
        style: AppTextStyles.mono(
          fontSize: 12,
          color: pick.needsPurchase ? AppColors.textPrimary : AppColors.primary,
        ),
      ),
      _PickState.waiting => const Icon(Icons.schedule, size: 18, color: AppColors.textMuted),
      _PickState.buying || _PickState.placing => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
      ),
      _PickState.done => const Icon(Icons.check_circle, size: 18, color: AppColors.primary),
      _PickState.failed => const Icon(Icons.error_outline, size: 18, color: AppColors.error),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: pick.tier.color.withValues(alpha: 0.7)),
            ),
            child: Text(
              pick.position,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pick.tier.color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pick.symbol,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (armband != null) ...[
                      const SizedBox(width: 6),
                      CircleAvatar(
                        radius: 8,
                        backgroundColor: AppColors.warning,
                        child: Text(
                          armband!,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textInverse,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  failure ?? pick.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: failure != null ? AppColors.error : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
