import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/features/wallet/data/wallet_connector.dart';
import 'package:formation/features/wallet/ui/cubits/wallet_cubit.dart';
import 'package:formation/features/wallet/ui/widgets/wallet_tap_gate.dart';

class _MemoryStorage implements Storage {
  final _values = <String, dynamic>{};
  @override
  dynamic read(String key) => _values[key];
  @override
  Future<void> write(String key, dynamic value) async => _values[key] = value;
  @override
  Future<void> delete(String key) async => _values.remove(key);
  @override
  Future<void> clear() async => _values.clear();
  @override
  Future<void> close() async {}
}

/// Behaves like mobile Chrome: refuses the first wallet hop for want of a
/// tap, then succeeds once the action is started again.
class _ChromeLikeConnector implements WalletConnector {
  int attempts = 0;

  @override
  bool get canRestoreSilently => true;

  @override
  Future<List<WalletOption>> availableWallets() async => const [];

  @override
  Future<WalletConnection?> connect({String? walletName, bool silent = false}) async => null;

  @override
  Future<SignInProof?> signIn({
    String? walletName,
    required String statement,
    required String nonce,
    required String issuedAt,
  }) async =>
      null;

  @override
  Future<void> disconnect(String? sessionToken) async {}

  @override
  Future<WalletSignature> signMessage(
    Uint8List message, {
    required String address,
    String? sessionToken,
  }) async {
    if (attempts++ == 0) throw const WalletTapRequired();
    return WalletSignature(value: Uint8List(64));
  }

  @override
  Future<WalletSignature> signAndSendTransaction(
    Uint8List transaction, {
    required String address,
    String? sessionToken,
  }) async {
    if (attempts++ == 0) throw const WalletTapRequired();
    return const WalletSignature(value: 'signature');
  }
}

void main() {
  setUpAll(() => HydratedBloc.storage = _MemoryStorage());

  test('waits for a tap, then finishes the action from it', () async {
    final connector = _ChromeLikeConnector();
    final cubit = WalletCubit(connector: connector);

    var done = false;
    final signing = cubit.signMessage(Uint8List(8)).then((_) => done = true);
    await pumpEventQueue();

    // Refused once, and now holding — not failed.
    expect(cubit.state.needsTap, isTrue);
    expect(done, isFalse);

    cubit.continueInWallet();
    await signing;
    expect(done, isTrue);
    expect(connector.attempts, 2);
    expect(cubit.state.needsTap, isFalse);
  });

  test('cancelling fails the action with a plain message, not a crash', () async {
    final cubit = WalletCubit(connector: _ChromeLikeConnector());
    final signing = cubit.signAndSendTransaction(Uint8List(8));
    await pumpEventQueue();

    cubit.cancelWalletAction();
    await expectLater(signing, throwsA(isA<WalletException>()));
    expect(cubit.state.needsTap, isFalse);
  });

  test('disconnecting releases anything still waiting', () async {
    final cubit = WalletCubit(connector: _ChromeLikeConnector());
    final signing = cubit.signMessage(Uint8List(8));
    await pumpEventQueue();

    // Listen before disconnecting, since disconnecting is what fails it.
    final released = expectLater(signing, throwsA(isA<WalletException>()));
    await cubit.disconnectWallet();
    await released;
  });

  testWidgets('shows an Open wallet button while an action waits', (tester) async {
    final cubit = WalletCubit(connector: _ChromeLikeConnector());

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: WalletTapGate(child: Scaffold())),
      ),
    );
    expect(find.text('Open wallet'), findsNothing);

    final signing = cubit.signMessage(Uint8List(8));
    await tester.pump();
    expect(find.text('Open wallet'), findsOneWidget);

    await tester.tap(find.text('Open wallet'));
    await tester.pump();
    await signing;
    expect(find.text('Open wallet'), findsNothing);
  });
}
