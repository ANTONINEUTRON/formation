import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/draft/ui/cubits/draft_state.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/lineup.dart';
import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Drafting a roster: held stocks fill instantly, others go through a swap.
/// For football, also manages the FPL-style lineup.
class DraftCubit extends Cubit<DraftState> {
  DraftCubit({required FormationRepository repository, required this.mode})
      : _repository = repository,
        super(const DraftState());

  final FormationRepository _repository;
  final SportMode mode;

  Future<void> load() async {
    emit(state.copyWith(status: LoadStatus.loading));
    try {
      final (stocks, roster) = await (_repository.getXStocks(), _repository.getRoster(mode)).wait;
      final held = await _repository.getHeldBalances([for (final s in stocks) s.mint]);
      if (isClosed) return;
      emit(DraftState(status: LoadStatus.success, roster: roster, stocks: stocks, held: held));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.failure, error: errorText(e)));
    }
  }

  /// Stocks that fit [slotIndex]'s tier and aren't already on the roster,
  /// held ones first.
  List<XStock> eligible(int slotIndex) {
    final roster = state.roster;
    if (roster == null) return const [];
    final position = roster.slots[slotIndex].position;
    final taken = {
      for (var i = 0; i < roster.slots.length; i++)
        if (i != slotIndex && roster.slots[i].stock != null) roster.slots[i].stock!.mint,
    };
    return state.stocks.where((s) => position.accepts(s) && !taken.contains(s.mint)).toList()
      ..sort((a, b) {
        final heldA = state.heldBalance(a) > 0;
        final heldB = state.heldBalance(b) > 0;
        if (heldA != heldB) return heldA ? -1 : 1;
        return a.symbol.compareTo(b.symbol);
      });
  }

  /// Fills a slot with a stock the wallet already holds.
  Future<void> pick(int slotIndex, XStock stock) async {
    final roster = await _repository.fillSlot(mode, slotIndex, stock);
    if (!isClosed) emit(state.copyWith(roster: roster));
  }

  Future<SwapQuote> quote(XStock stock, double usdcAmount) =>
      _repository.getSwapQuote(stock, usdcAmount);

  /// Buys via the quoted swap, then fills the slot with the new holding.
  Future<double> buyAndFill(int slotIndex, SwapQuote quote) async {
    final shares = await _repository.executeSwap(quote);
    final held = await _repository.getHeldBalances([for (final s in state.stocks) s.mint]);
    if (!isClosed) emit(state.copyWith(held: held));
    await pick(slotIndex, quote.stock);
    return shares;
  }

  // ── Football lineup (FPL rules) ──────────────────────────────────────────────

  Future<void> setFormation(Formation formation) => _saveLineup(_lineup.withFormation(formation));

  Future<void> makeCaptain(int slot) => _saveLineup(_lineup.withCaptain(slot));

  Future<void> makeViceCaptain(int slot) => _saveLineup(_lineup.withViceCaptain(slot));

  void startSubstitution(int slot) => emit(state.copyWith(substituting: slot));

  void cancelSubstitution() => emit(state.copyWith(clearSubstituting: true));

  /// Slots the player being substituted can legally swap with.
  Set<int> substitutionTargets() {
    final from = state.substituting;
    final lineup = state.roster?.lineup;
    if (from == null || lineup == null) return const {};
    return {
      for (var i = 0; i < footballSquadRoles.length; i++)
        if (lineup.substitute(from, i) != null) i,
    };
  }

  Future<void> substituteWith(int slot) async {
    final from = state.substituting;
    if (from == null) return;
    final next = _lineup.substitute(from, slot);
    if (next == null) {
      emit(state.copyWith(clearSubstituting: true));
      throw StateError('That swap would break formation rules');
    }
    await _saveLineup(next);
  }

  Lineup get _lineup => state.roster!.lineup!;

  /// Applies the lineup immediately, then saves; reverts if saving fails.
  Future<void> _saveLineup(Lineup lineup) async {
    final previous = state.roster!;
    emit(state.copyWith(roster: previous.copyWith(lineup: lineup), clearSubstituting: true));
    try {
      final saved = await _repository.setLineup(mode, lineup);
      if (!isClosed) emit(state.copyWith(roster: saved));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(roster: previous));
      rethrow;
    }
  }
}
