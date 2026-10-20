import { Global, Module } from '@nestjs/common';
import { AuthController } from './auth.controller.js';
import { AdminGuard, AdminUserGuard, AuthGuard, OptionalAuthGuard } from './auth.guard.js';
import { AuthService } from './auth.service.js';
import { SessionService } from './session.service.js';

@Global()
@Module({
  controllers: [AuthController],
  providers: [AuthService, SessionService, AuthGuard, OptionalAuthGuard, AdminGuard, AdminUserGuard],
  exports: [AuthService, SessionService, AuthGuard, OptionalAuthGuard, AdminGuard, AdminUserGuard],
})
export class AuthModule {}
