import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/utils/format.dart';
import 'package:symbians/features/draft/ui/cubits/draft_state.dart';
import 'package:symbians/features/shared/data/formation_repository.dart';
import 'package:symbians/features/shared/domain/lineup.dart';
import 'package:symbians/features/shared/domain/load_status.dart';
import 'package:symbians/features/shared/domain/models.dart';

/// Drafting a team: held stocks fill instantly, others go through a swap.
/// For football it also owns the formation; football and basketball the armband.
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

  /// Stocks that fit [slotIndex]'s tier and aren't already on the team,
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

  // ── Formation and captaincy ─────────────────────────────────────────────────

  Formation get formation =>
      Formation.parse(state.roster?.formation ?? defaultFormation);

  /// What switching to [target] would drop, so the UI can confirm first.
  List<XStock> dropsFor(Formation target) {
    final roster = state.roster;
    if (roster == null) return const [];
    final preview = previewFormationChange(
      from: roster.formation ?? defaultFormation,
      to: target.name,
      picks: roster.picksBySlot,
    );
    return [
      for (final mint in preview.dropped)
        state.stocks.firstWhere((s) => s.mint == mint),
    ];
  }

  /// Saves the new shape. Returns the picks that came off the team.
  Future<List<XStock>> setFormation(Formation formation) async {
    emit(state.copyWith(isSaving: true));
    try {
      final change = await _repository.setFormation(mode, formation.name);
      if (!isClosed) emit(state.copyWith(roster: change.roster, isSaving: false));
      return change.dropped;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(isSaving: false));
      rethrow;
    }
  }

  Future<void> makeCaptain(int slot) => _saveCaptaincy(
        captainSlot: slot,
        viceCaptainSlot:
            state.roster?.viceCaptainSlot == slot ? state.roster?.captainSlot : state.roster?.viceCaptainSlot,
      );

  Future<void> makeViceCaptain(int slot) => _saveCaptaincy(
        captainSlot:
            state.roster?.captainSlot == slot ? state.roster?.viceCaptainSlot : state.roster?.captainSlot,
        viceCaptainSlot: slot,
      );

  Future<void> _saveCaptaincy({int? captainSlot, int? viceCaptainSlot}) async {
    emit(state.copyWith(isSaving: true));
    try {
      final roster = await _repository.setCaptaincy(
        mode,
        captainSlot: captainSlot,
        viceCaptainSlot: viceCaptainSlot,
      );
      if (!isClosed) emit(state.copyWith(roster: roster, isSaving: false));
    } catch (_) {
      if (!isClosed) emit(state.copyWith(isSaving: false));
      rethrow;
    }
  }
}
