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

  @override
  Future<List<String>> signAndSendTransactions(List<Uint8List> transactions) async =>
      [for (final _ in transactions) 'signature'];
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
      expect(cubit.state.profile!.credits, 11);

      await cubit.pickCharacter('mentor');
      expect(cubit.state.profile!.character!.name, 'The Mentor');

      await cubit.send(_basketball, 'Review my squad');
      final conversation = cubit.state.conversation(SportMode.basketball);
      expect(conversation.map((m) => m.role), [AssistantRole.manager, AssistantRole.assistant]);
      expect(cubit.state.profile!.credits, 10);
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
      for (var i = 0; i < 11; i++) {
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

  group('answer cards', () {
    test('parses every card type the backend sends, and skips unknown ones', () {
      final reply = AssistantReply.fromJson({
        'text': 'Here you go.',
        'mood': 'neutral',
        'suggestions': [],
        'credits': 3,
        'cards': [
          {
            'type': 'statBoard',
            'symbol': 'AAPLx',
            'name': 'Apple',
            'tier': 'blue_chip',
            'logoUrl': null,
            'priceUsd': 231.4,
            'change24hPct': 1.2,
            'sharesHeld': 2,
            'valueUsd': 462.8,
            'position': 'GK',
            'return7dPct': 3.1,
            'benchmark7dPct': 1.0,
            'alpha7dPct': 2.1,
            'chart': {
              '7D': [
                {
                  'symbol': 'AAPLx',
                  'points': [
                    [1760000000000, 0],
                    [1760003600000, 1.5],
                  ],
                },
              ],
            },
            'news': {
              'summary': 'Apple shipped a thing.',
              'sources': [
                {'title': 'Example', 'url': 'https://example.com'},
              ],
            },
          },
          {
            'type': 'squadBubbles',
            'bubbles': [
              {'symbol': 'KOx', 'tier': 'blue_chip', 'position': 'DEF', 'valueUsd': 40, 'alphaPct': -0.4},
            ],
          },
          {'type': 'html', 'title': 'Tier matrix', 'html': '<!doctype html><p>hi</p>', 'height': 200},
          {'type': 'hologram'},
        ],
      });

      expect(reply.cards, hasLength(3));
      expect((reply.cards[2] as HtmlCard).height, 200);
      final board = reply.cards.first as StatBoardCard;
      expect(board.tier, RiskTier.blueChip);
      expect(board.chart['7D']!.single.points.last.$2, 1.5);
      expect(board.newsSources.single.url, 'https://example.com');
      expect((reply.cards[1] as SquadBubblesCard).bubbles.single.alphaPct, -0.4);
    });

    test('the demo answers a question about a stock with a stat board', () async {
      final repository = FixtureRepository(walletAddress: 'wallet');
      final cubit = AssistantCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.pickCharacter('analyst');
      await cubit.send(const AssistantContext(mode: SportMode.football), 'What is AAPLx all about?');
      final cards = cubit.state.conversation(SportMode.football).last.cards;
      expect(cards.single, isA<StatBoardCard>());
      expect((cards.single as StatBoardCard).chart.keys, containsAll(chartRanges));
    });
  });

  group('custom avatar', () {
    test('drawing one makes it the active character and loads its poses', () async {
      final repository = FixtureRepository(walletAddress: 'w');
      final cubit = AssistantCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.profile!.avatarCost, 0);

      final photo = Uint8List.fromList([1, 2, 3]);
      final error = await cubit.createAvatar(
        photo: photo,
        mimeType: 'image/png',
        personality: 'maverick',
        name: 'Coach Toly',
      );

      expect(error, isNull);
      final profile = cubit.state.profile!;
      expect(profile.character!.isCustom, isTrue);
      expect(profile.character!.name, 'Coach Toly');
      expect(profile.character!.style, 'bold');
      expect(profile.avatarCost, 20); // the second one costs credits
      expect(cubit.state.avatarImages.keys, containsAll(AssistantPose.values));
    });

    test('uploads the photo as multipart with the personality and consent', () async {
      http.BaseRequest? sent;
      var multipart = '';
      final repository = ApiRepository(
        baseUrl: 'http://localhost:3000',
        signer: _FakeSigner(),
        client: MockClient.streaming((request, body) async {
          final path = request.url.path;
          if (path == '/auth/challenge') {
            return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode({'message': 'Sign in'}))), 200);
          }
          if (path == '/auth/verify') {
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'token': 't',
                    'user': {'id': 'u', 'username': 'me', 'walletAddress': 'w'},
                  }),
                ),
              ),
              200,
            );
          }
          sent = request;
          multipart = latin1.decode(await body.toBytes());
          return http.StreamedResponse(Stream.value(utf8.encode(jsonEncode({'credits': 5}))), 200);
        }),
      );

      final credits = await repository.createAvatar(
        photo: Uint8List.fromList([137, 80, 78, 71]),
        mimeType: 'image/png',
        personality: 'scout',
      );
      expect(credits, 5);
      expect(multipart, contains('name="personality"'));
      expect(multipart, contains('scout'));
      expect(multipart, contains('name="consent"'));
      expect(multipart, contains('filename="photo.png"'));
      expect(multipart.toLowerCase(), contains('content-type: image/png'));
      expect(sent!.url.path, '/assistant/avatar');
      expect(sent!.headers['authorization'], 'Bearer t');
      expect(sent!.headers['content-type'], startsWith('multipart/form-data'));
    });
  });

  group('buying credits (fixture backend)', () {
    test('quotes a pack in SKR and tops the balance up once paid', () async {
      final repository = FixtureRepository(walletAddress: 'wallet');
      final cubit = AssistantCubit(repository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      final profile = cubit.state.profile!;
      expect(profile.canBuyCredits, isTrue);

      final quote = await repository.quoteCredits(profile.packs.first);
      expect(quote.pack.credits, 50);
      expect(quote.skrAmount, 50); // $1 at the fixture's $0.02

      cubit.creditsBought(await repository.buyCredits(quote));
      expect(cubit.state.profile!.credits, 61);
      expect(cubit.state.outOfCredits, isFalse);
    });
  });

  group('ApiRepository assistant calls', () {
    ApiRepository withChat(http.Response Function(http.Request) chat, List<Object?> sent) => ApiRepository(
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
              {
                'kind': 'setCaptain',
                'slotIndex': 4,
                'symbol': 'AAPLx',
                'position': 'C',
                'vice': false,
                'reason': 'steady',
              },
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
        'context': {
          'mode': 'american_football',
          'screen': 'draft',
          'focus': {'mint': 'mint-1'},
        },
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

    test('buying credits builds, has the wallet sign, then confirms with the signature', () async {
      final sent = <Object?>[];
      final paths = <String>[];
      final repository = withChat((request) {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode(switch (request.url.path) {
            '/assistant/credits/build' => {
              'transaction': base64Encode([1, 2, 3]),
            },
            _ => {'credits': 305},
          }),
          200,
        );
      }, sent);
      const pack = CreditPack(id: 'credits-300', credits: 300, usd: 5);

      final balance = await repository.buyCredits(
        CreditQuote(quoteId: 'q-1', pack: pack, skrAmount: 250, expiresAt: DateTime(2030)),
      );

      expect(balance, 305);
      expect(paths, ['/assistant/credits/build', '/assistant/credits/confirm']);
      expect(sent.last, {'quoteId': 'q-1', 'signature': 'signature'});
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
