import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { DB } from '../core/db.js';
import type { Db } from '../core/db.js';
import { SPORT_MODES } from '../domain/sport.js';
import type { SportMode } from '../domain/sport.js';

/** Everything a crawler is allowed to know about a page. */
export interface OgPreview {
  title: string;
  description: string;
}

const SPORT_LABELS: Record<SportMode, string> = {
  football: 'football',
  basketball: 'basketball',
  american_football: 'American football',
};

/**
 * Share previews for links people paste into Telegram, X and group chats.
 *
 * Unauthenticated by design — a crawler has no wallet and cannot sign — so
 * this deliberately returns the smallest thing that makes a link worth
 * clicking: a name, a rank, a member count. No holdings, no lineup, no wallet
 * address, nothing the player has not already made public by appearing on a
 * leaderboard. The real endpoints behind `AuthGuard` stay the only way to read
 * any of that.
 */
@Injectable()
export class OgService {
  constructor(@Inject(DB) private readonly db: Db) {}

  async manager(userId: string, mode: SportMode): Promise<OgPreview> {
    const user = await this.db
      .selectFrom('users')
      .select(['id', 'username'])
      .where('id', '=', userId)
      .executeTakeFirst();
    if (!user) throw new NotFoundException('No such player');

    const score = await this.db
      .selectFrom('classic_scores')
      .select(['total_points'])
      .where('user_id', '=', user.id)
      .where('sport_mode', '=', mode)
      .executeTakeFirst();

    const points = Math.round(score?.total_points ?? 0);
    // Rank is a position among everyone with a score, which is exactly what the
    // leaderboard already shows publicly.
    const rank = score
      ? await this.rankOf(mode, score.total_points)
      : null;

    const standing = rank === null ? 'Unranked' : `Rank #${rank}`;
    return {
      title: `${user.username} on Formation`,
      description: `${standing} · ${points.toLocaleString('en-US')} pts in the ${SPORT_LABELS[mode]} league. Beat the market, climb the table.`,
    };
  }

  async league(leagueId: string): Promise<OgPreview> {
    const league = await this.db
      .selectFrom('leagues')
      .select(['id', 'name', 'sport_mode', 'visibility', 'status', 'max_members'])
      .where('id', '=', leagueId)
      .executeTakeFirst();
    if (!league) throw new NotFoundException('No such league');

    // A private league's name is part of what makes it private, and the link
    // is shared by the person who has the join code. The preview confirms the
    // link is real without describing what is behind it.
    if (league.visibility === 'private') {
      return {
        title: 'A private league on Formation',
        description: 'You need the join code to enter. Fantasy sports played with stocks you actually own.',
      };
    }

    const members = await this.db
      .selectFrom('league_members')
      .select((eb) => eb.fn.countAll<string>().as('count'))
      .where('league_id', '=', league.id)
      .executeTakeFirst();

    const count = Number(members?.count ?? 0);
    const state = league.status === 'final' ? 'Finished' : league.status === 'live' ? 'Live now' : 'Starting soon';
    const size = league.max_members ? `${count}/${league.max_members}` : `${count}`;

    return {
      title: `${league.name} — Formation`,
      description: `${state} · ${size} managers · ${SPORT_LABELS[league.sport_mode]}. Draft a squad of stocks you own and score for beating the market.`,
    };
  }

  /** How many players are strictly ahead of [points], plus one. */
  private async rankOf(mode: SportMode, points: number): Promise<number> {
    const ahead = await this.db
      .selectFrom('classic_scores')
      .select((eb) => eb.fn.countAll<string>().as('count'))
      .where('sport_mode', '=', mode)
      .where('total_points', '>', points)
      .executeTakeFirst();
    return Number(ahead?.count ?? 0) + 1;
  }
}

/** Parses the `mode` query parameter, defaulting to football. */
export function parseMode(value: unknown): SportMode {
  return SPORT_MODES.includes(value as SportMode) ? (value as SportMode) : 'football';
}
