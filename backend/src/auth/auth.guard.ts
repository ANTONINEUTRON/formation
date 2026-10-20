import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  ForbiddenException,
  HttpException,
  HttpStatus,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import type { AuthUser } from '../domain/dto.js';
import { AuthService } from './auth.service.js';
import { SessionService } from './session.service.js';

export type AuthedRequest = Request & { user?: AuthUser };
/** A request through AdminUserGuard: who is acting, a wallet address or 'key'. */
export type AdminRequest = AuthedRequest & { admin?: string };

function readUser(auth: AuthService, req: AuthedRequest): AuthUser | undefined {
  const header = req.header('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  const payload = token ? auth.readToken(token) : null;
  return payload ? { id: payload.sub, walletAddress: payload.wallet } : undefined;
}

/** Requires a valid bearer token for an account that is still usable. */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly auth: AuthService,
    private readonly sessions: SessionService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    req.user = readUser(this.auth, req);
    if (!req.user) throw new UnauthorizedException();
    if (!(await this.sessions.allow(req.user.id))) {
      throw new ForbiddenException('This account is suspended');
    }
    return true;
  }
}

/** Attaches the user when a valid token is present; never rejects. */
@Injectable()
export class OptionalAuthGuard implements CanActivate {
  constructor(
    private readonly auth: AuthService,
    private readonly sessions: SessionService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    const user = readUser(this.auth, req);
    // A suspended account browses as a guest rather than being refused.
    req.user = user && (await this.sessions.allow(user.id)) ? user : undefined;
    return true;
  }
}

/** Demo controls: requires the `x-admin-key` header to match ADMIN_KEY. */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(@Inject(CONFIG) private readonly config: AppConfig) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<Request>();
    if (!this.config.adminKey || req.header('x-admin-key') !== this.config.adminKey) {
      throw new UnauthorizedException('Admin key required');
    }
    return true;
  }
}

/** Requests per minute one admin may make. */
const ADMIN_RATE_PER_MINUTE = 60;

/**
 * The admin dashboard's guard. Lets a request through when it carries either
 * a session for a wallet in ADMIN_WALLETS, or the x-admin-key header (for
 * scripts). Sets `req.admin` to the wallet, or 'key', for the audit log.
 */
@Injectable()
export class AdminUserGuard implements CanActivate {
  private readonly windows = new Map<string, { start: number; count: number }>();

  constructor(
    @Inject(CONFIG) private readonly config: AppConfig,
    private readonly auth: AuthService,
  ) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<AdminRequest>();

    const key = req.header('x-admin-key');
    if (key !== undefined) {
      if (!this.config.adminKey || key !== this.config.adminKey) {
        throw new UnauthorizedException('Admin key required');
      }
      req.admin = 'key';
    } else {
      const user = readUser(this.auth, req);
      if (!user) throw new UnauthorizedException();
      if (!this.config.adminWallets.includes(user.walletAddress)) {
        throw new ForbiddenException('Not available');
      }
      req.user = user;
      req.admin = user.walletAddress;
    }

    this.limit(req.admin);
    return true;
  }

  private limit(admin: string) {
    const now = Date.now();
    const window = this.windows.get(admin);
    if (!window || now - window.start >= 60_000) {
      this.windows.set(admin, { start: now, count: 1 });
      return;
    }
    if (++window.count > ADMIN_RATE_PER_MINUTE) {
      throw new HttpException('Too many admin requests, slow down', HttpStatus.TOO_MANY_REQUESTS);
    }
  }
}

/** The acting admin set by AdminUserGuard: a wallet address, or 'key'. */
export const CurrentAdmin = createParamDecorator(
  (_: unknown, context: ExecutionContext) =>
    context.switchToHttp().getRequest<AdminRequest>().admin ?? 'key',
);

export const CurrentUser = createParamDecorator(
  (_: unknown, context: ExecutionContext) =>
    context.switchToHttp().getRequest<AuthedRequest>().user,
);
