import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:formation/core/errors/app_exception.dart';
import 'package:formation/features/assistant_manager/domain/assistant_models.dart';
import 'package:formation/features/assistant_manager/ui/cubits/assistant_cubit.dart';
import 'package:formation/features/shared/data/api_repository.dart';
import 'package:formation/features/shared/data/fixture_repository.dart';
import 'package:formation/features/shared/domain/models.dart';
import 'package:formation/features/wallet/data/wallet_connector.dart';

class _FakeSigner implements WalletSigner {
  @override
  SignInProof? takeSignInProof() => null;

  @override
  String get walletAddress => 'GER2werVnaHehJ9dDZN7KVpf41aepYaLEEBgZ27MTUhW';

  @override
  Future<Uint8List> signMessage(Uint8List message) async => Uint8List(64);

  @override
  Future<String> signAndSendTransaction(Uint8List transaction) async => 'signature';
}

const _basketball = AssistantContext(mode: SportMode.basketball);

void main() {
  group('AssistantCubit (fixture backend)', () {
    late FixtureRepository repository;
    late AssistantCubit cubit;

    setUp(() {
      repository = FixtureRepository(walletAddress: 'wallet');
      cubit = AssistantCubit(repository: repository);
    });

    tearDown(() => cubit.close());

    test('asks for a character first, then answers and charges a credit', () async {
      await cubit.load();
      expect(cubit.state.profile!.characterId, isNull);
      expect(cubit.state.profile!.credits, 5);

      await cubit.pickCharacter('mentor');
      expect(cubit.state.profile!.character!.name, 'The Mentor');

      await cubit.send(_basketball, 'Review my squad');
      final conversation = cubit.state.conversation(SportMode.basketball);
      expect(conversation.map((m) => m.role), [AssistantRole.manager, AssistantRole.assistant]);
      expect(cubit.state.profile!.credits, 4);
      expect(cubit.state.sending, isFalse);
      // Each sport keeps its own conversation.
      expect(cubit.state.conversation(SportMode.football), isEmpty);
    });

    test('applying a suggested fill puts the stock in the lineup', () async {
      await cubit.load();
      await cubit.pickCharacter('analyst');
      await cubit.send(_basketball, 'Fill my empty slots');

      final reply = cubit.state.conversation(SportMode.basketball).last;
      final fill = reply.suggestions.single as FillSlotSuggestion;
      expect(fill.needsPurchase, isFalse);

      await cubit.apply(SportMode.basketball, 1, 0);
      expect(cubit.state.conversation(SportMode.basketball).last.statuses, [SuggestionStatus.applied]);
      final roster = await repository.getRoster(SportMode.basketball);
      expect(roster.slots[fill.slotIndex].stock?.mint, fill.mint);
      expect(cubit.state.pose, AssistantPose.celebrating);
    });

    test('runs out of credits and says so instead of answering', () async {
      await cubit.load();
      await cubit.pickCharacter('scout');
      for (var i = 0; i < 5; i++) {
        await cubit.send(_basketball, 'question $i');
      }
      expect(cubit.state.outOfCredits, isTrue);

      await cubit.send(_basketball, 'one more');
      expect(cubit.state.error, contains('out of'));
      expect(cubit.state.pose, AssistantPose.concerned);
      // The unanswered question stays on screen; no reply was added.
      expect(cubit.state.conversation(SportMode.basketball).last.text, 'one more');
    });
  });

  group('ApiRepository assistant calls', () {
    ApiRepository withChat(http.Response Function(http.Request) chat, List<Object?> sent) =>
        ApiRepository(
          baseUrl: 'http://localhost:3000',
          signer: _FakeSigner(),
          client: MockClient((request) async {
            final body = switch (request.url.path) {
              '/auth/challenge' => jsonEncode({'message': 'Sign in'}),
              '/auth/verify' => jsonEncode({
                  'token': 't',
                  'user': {'id': 'u', 'username': 'me', 'walletAddress': 'w'},
                }),
              _ => null,
            };
            if (body != null) return http.Response(body, 200);
            sent.add(jsonDecode(request.body));
            return chat(request);
          }),
        );

    test('sends the context envelope and parses suggestions', () async {
      final sent = <Object?>[];
      final repository = withChat(
        (_) => http.Response(
          jsonEncode({
            'text': 'Captain AAPLx.',
            'mood': 'happy',
            'suggestions': [
              {'kind': 'setCaptain', 'slotIndex': 4, 'symbol': 'AAPLx', 'position': 'C', 'vice': false, 'reason': 'steady'},
              {'kind': 'somethingNew', 'reason': 'ignored by older apps'},
            ],
            'credits': 3,
          }),
          200,
        ),
        sent,
      );

      final reply = await repository.askAssistant(
        const AssistantContext(mode: SportMode.americanFootball, screen: 'draft', focusMint: 'mint-1'),
        const [AssistantMessage(role: AssistantRole.manager, text: 'Who?')],
      );

      expect(sent.single, {
        'context': {'mode': 'american_football', 'screen': 'draft', 'focus': {'mint': 'mint-1'}},
        'messages': [
          {'role': 'manager', 'text': 'Who?'},
        ],
      });
      expect(reply.mood, AssistantMood.happy);
      expect(reply.credits, 3);
      expect(reply.suggestions, [
        const CaptainSuggestion(slotIndex: 4, symbol: 'AAPLx', position: 'C', vice: false, reason: 'steady'),
      ]);
    });

    test('a 402 is recognisable as out of credits; a 502 keeps its message', () async {
      final out = withChat((_) => http.Response(jsonEncode({'message': 'You are out of credits'}), 402), []);
      await expectLater(
        out.askAssistant(_basketball, const [AssistantMessage(role: AssistantRole.manager, text: 'hi')]),
        throwsA(isA<ValidationException>().having((e) => e.code, 'code', outOfCreditsCode)),
      );

      final down = withChat(
        (_) => http.Response(jsonEncode({'message': 'Could not answer. You were not charged.'}), 502),
        [],
      );
      await expectLater(
        down.askAssistant(_basketball, const [AssistantMessage(role: AssistantRole.manager, text: 'hi')]),
        throwsA(isA<NetworkException>().having((e) => e.message, 'message', contains('not charged'))),
      );
    });
  });
}
