import 'package:flutter_test/flutter_test.dart';

import 'package:formation/features/shared/data/fixture_repository.dart';
import 'package:formation/features/shared/domain/models.dart';

const _week = {
  'number': 3,
  'season': 1,
  'weekOfSeason': 3,
  'kickOff': '2026-10-26T13:30:00.000Z',
  'fullTime': '2026-10-30T20:00:00.000Z',
  'nextKickOff': '2026-11-02T14:30:00.000Z',
  'points': 42.5,
};

void main() {
  test('a session carries its match week and the transfer window', () {
    final session = Session.fromJson({
      'startsAt': '2026-10-31T00:00:00.000Z',
      'endsAt': '2026-11-01T00:00:00.000Z',
      'entered': true,
      'points': 3,
      'slots': <Object>[],
      'teamEvents': <Object>[],
      'substitutionsUsed': 0,
      'freeSubstitutionsLeft': 3,
      'matchWeek': _week,
      'transferWindowOpen': true,
    });
    expect(session.transferWindowOpen, isTrue);
    expect(session.matchWeek!.label, 'Season 1 · Week 3');
    expect(session.matchWeek!.points, 42.5);
    expect(session.matchWeek!.preSeason, isFalse);
    expect(session.matchWeek!.labelFor(SportMode.basketball), 'Season 1 · Week 3');
  });

  test('before the season, each sport names its pre-season its own way', () {
    final week = MatchWeek.fromJson({..._week, 'kickOff': '2026-10-19T13:30:00.000Z', 'preSeason': true});
    expect(week.labelFor(SportMode.football), startsWith('Pre-season friendlies · Season 1 kick-off '));
    expect(week.labelFor(SportMode.basketball), startsWith('Preseason games · Season 1 tip-off '));
    expect(week.labelFor(SportMode.americanFootball), startsWith('Preseason games · Season 1 kickoff '));
    expect(SportMode.football.preSeason, 'Pre-season');
    expect(SportMode.basketball.preSeason, 'Preseason');
  });

  test('a league parses its fixtures, byes and W/D/L table', () {
    final league = League.fromJson({
      'id': 'l1',
      'name': 'Office',
      'mode': 'football',
      'visibility': 'private',
      'joinCode': 'ABCD',
      'startsAt': '2026-10-25T00:00:00.000Z',
      'endsAt': '2026-12-01T00:00:00.000Z',
      'status': 'live',
      'maxMembers': null,
      'memberCount': 3,
      'createdBy': 'anna',
      'joined': true,
      'joinable': false,
      'standings': <Object>[],
      'fixtures': [
        {
          'week': 3,
          'weekOfSeason': 3,
          'kickOff': '2026-10-26T13:30:00.000Z',
          'fullTime': '2026-10-30T20:00:00.000Z',
          'homeId': 'a',
          'homeName': 'anna',
          'awayId': 'b',
          'awayName': 'ben',
          'homePoints': 84.2,
          'awayPoints': 61,
          'status': 'final',
        },
        {
          'week': 3,
          'weekOfSeason': 3,
          'kickOff': '2026-10-26T13:30:00.000Z',
          'fullTime': '2026-10-30T20:00:00.000Z',
          'homeId': 'c',
          'homeName': 'cy',
          'awayId': null,
          'awayName': null,
          'homePoints': 0,
          'awayPoints': 0,
          'status': 'final',
        },
      ],
      'table': [
        {
          'rank': 1,
          'userId': 'a',
          'username': 'anna',
          'played': 1,
          'won': 1,
          'drawn': 0,
          'lost': 0,
          'pointsFor': 84.2,
          'pointsAgainst': 61,
          'tablePoints': 3,
          'form': ['W'],
        },
      ],
    });
    expect(league.hasFixtures, isTrue);
    expect(league.fixtures.first.isFinal, isTrue);
    expect(league.fixtures.last.isBye, isTrue);
    expect(league.table.single.tablePoints, 3);
    expect(league.table.single.form, ['W']);
  });

  test('a result card parses its man of the match, goals and turning point', () {
    final result = MatchWeekResult.fromJson({
      'week': _week,
      'final': true,
      'points': -7,
      'rank': 4,
      'players': 128,
      'manOfTheMatch': {'symbol': 'TSLAx', 'points': 26},
      'goals': [
        {'at': '2026-10-27T20:00:00.000Z', 'symbol': 'TSLAx', 'label': '2 goals', 'points': 8},
      ],
      'turningPoint': {'at': '2026-10-27T15:03:00.000Z', 'points': -30},
    });
    expect(result.isFinal, isTrue);
    expect(result.manOfTheMatch!.symbol, 'TSLAx');
    expect(result.goals.single.label, '2 goals');
    expect(result.turningPoint!.points, -30);
  });

  test('live events, live fixtures and skill parse from a session and a profile', () {
    final session = Session.fromJson({
      'startsAt': '2026-10-27T00:00:00.000Z',
      'endsAt': '2026-10-28T00:00:00.000Z',
      'entered': true,
      'points': 3,
      'slots': <Object>[],
      'teamEvents': <Object>[],
      'substitutionsUsed': 0,
      'freeSubstitutionsLeft': 3,
      'liveEvents': [
        {
          'slotIndex': 9,
          'mint': 'm',
          'symbol': 'TSLAx',
          'code': 'goal',
          'label': 'Goal',
          'points': 4,
          'status': 'provisional',
          'at': '2026-10-27T15:03:00.000Z',
        },
        {
          'slotIndex': 1,
          'mint': 'k',
          'symbol': 'KOx',
          'code': 'clean_sheet',
          'label': 'Clean sheet',
          'points': 4,
          'status': 'disallowed',
          'at': '2026-10-27T15:03:00.000Z',
        },
      ],
      'liveFixtures': [
        {
          'leagueId': 'l',
          'leagueName': 'Office',
          'opponent': 'ben',
          'points': 42.1,
          'opponentPoints': 38,
          'final': false,
        },
      ],
    });
    expect(session.liveFor(9).single.isGoal, isTrue);
    expect(session.liveFor(1).single.isDisallowed, isTrue);
    expect(session.liveFor(1).single.isGoal, isFalse);
    expect(session.liveFixtures.single.opponent, 'ben');

    final skill = Skill.fromJson({
      'rating': 71.4,
      'weeks': 4,
      'ranked': true,
      'alphaPerWeekPct': 2.1,
      'hitRatePct': 64,
      'shrewdCaptainPct': 75,
      'form': ['W', 'W', 'L', 'W'],
    });
    expect(skill.ranked, isTrue);
    expect(skill.form.last, 'W');
  });

  test('the portfolio health card parses sectors, tiers, balance and lessons', () {
    final health = PortfolioHealth.fromJson({
      'mode': 'basketball',
      'week': 3,
      'weekOfSeason': 3,
      'season': 1,
      'points': -12.5,
      'tiers': [
        {'tier': 'momentum', 'count': 2},
        {'tier': 'balanced', 'count': 1},
      ],
      'sectors': [
        {'sector': 'technology', 'label': 'Technology', 'sharePct': 61},
        {'sector': 'financials', 'label': 'Financials', 'sharePct': 39},
      ],
      'balance': {'sectors': 2, 'needed': 4, 'bonus': 5, 'earned': false},
      'carried': {'symbol': 'NVDAx', 'points': 14},
      'dragged': null,
      'lessons': ['61% of your team is in technology.'],
    });
    expect(health.isBalanced, isFalse);
    expect(health.tiers['momentum'], 2);
    expect(health.sectors.first.label, 'Technology');
    expect(health.carried!.symbol, 'NVDAx');
    expect(health.dragged, isNull);
  });

  test('fixture mode serves a result card', () async {
    final repo = FixtureRepository(walletAddress: 'TestWallet1111111111111111111111111111111');
    final result = await repo.getMatchWeekResult(SportMode.football);
    expect(result.week.weekOfSeason, inInclusiveRange(1, 12));
  });
}
