import {
  Controller,
  Get,
  Header,
  HttpException,
  HttpStatus,
  Injectable,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';
import type { CanActivate, ExecutionContext } from '@nestjs/common';
import { OgService, parseMode } from './og.service.js';
import type { OgPreview } from './og.service.js';

const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 60;

/**
 * A fixed-window limit per caller, for the one group of endpoints that has no
 * `AuthGuard` in front of it.
 *
 * Deliberately a few lines rather than a dependency: these endpoints return
 * two short strings from two indexed queries, so the only thing worth stopping
 * is someone walking every user id. Counters are per process and reset on
 * restart, which is the same scope the auth challenge cache already has.
 */
@Injectable()
export class OgRateLimitGuard implements CanActivate {
  private readonly hits = new Map<string, { count: number; resetAt: number }>();

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{ ip?: string }>();
    const key = request.ip ?? 'unknown';
    const now = Date.now();

    // Sweeping on write keeps the map from growing without a timer to clean up
    // after, which matters because nothing else here holds state.
    if (this.hits.size > 10_000) {
      for (const [k, v] of this.hits) if (v.resetAt < now) this.hits.delete(k);
    }

    const entry = this.hits.get(key);
    if (!entry || entry.resetAt < now) {
      this.hits.set(key, { count: 1, resetAt: now + WINDOW_MS });
      return true;
    }
    if (entry.count >= MAX_PER_WINDOW) {
      throw new HttpException('Too many requests', HttpStatus.TOO_MANY_REQUESTS);
    }
    entry.count += 1;
    return true;
  }
}

/**
 * Open Graph previews, read by the `ogRender` Cloud Function.
 *
 * Unauthenticated: a link crawler has no wallet and cannot sign a challenge.
 * The responses are cached at the edge for a few minutes, because a popular
 * link is fetched once per chat platform per share, not once per viewer.
 */
@Controller('og')
@UseGuards(OgRateLimitGuard)
export class OgController {
  constructor(private readonly og: OgService) {}

  @Get('managers/:userId')
  @Header('cache-control', 'public, max-age=300, s-maxage=600')
  manager(
    @Param('userId') userId: string,
    @Query('mode') mode?: string,
  ): Promise<OgPreview> {
    return this.og.manager(userId, parseMode(mode));
  }

  @Get('leagues/:leagueId')
  @Header('cache-control', 'public, max-age=300, s-maxage=600')
  league(@Param('leagueId') leagueId: string): Promise<OgPreview> {
    return this.og.league(leagueId);
  }
}
