import { Global, Module } from '@nestjs/common';
import { AuthController } from './auth.controller.js';
import { AdminGuard, AuthGuard, OptionalAuthGuard } from './auth.guard.js';
import { AuthService } from './auth.service.js';

@Global()
@Module({
  controllers: [AuthController],
  providers: [AuthService, AuthGuard, OptionalAuthGuard, AdminGuard],
  exports: [AuthService, AuthGuard, OptionalAuthGuard, AdminGuard],
})
export class AuthModule {}
