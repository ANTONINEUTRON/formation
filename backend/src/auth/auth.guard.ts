import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  Inject,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import type { AuthUser } from '../domain/dto.js';
import { AuthService } from './auth.service.js';

export type AuthedRequest = Request & { user?: AuthUser };

function readUser(auth: AuthService, req: AuthedRequest): AuthUser | undefined {
  const header = req.header('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  const payload = token ? auth.readToken(token) : null;
  return payload ? { id: payload.sub, walletAddress: payload.wallet } : undefined;
}

/** Requires a valid bearer token. */
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    req.user = readUser(this.auth, req);
    if (!req.user) throw new UnauthorizedException();
    return true;
  }
}

/** Attaches the user when a valid token is present; never rejects. */
@Injectable()
export class OptionalAuthGuard implements CanActivate {
  constructor(private readonly auth: AuthService) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<AuthedRequest>();
    req.user = readUser(this.auth, req);
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

export const CurrentUser = createParamDecorator(
  (_: unknown, context: ExecutionContext) =>
    context.switchToHttp().getRequest<AuthedRequest>().user,
);
