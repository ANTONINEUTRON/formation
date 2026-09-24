import { Global, Inject, Module, OnModuleDestroy } from '@nestjs/common';
import { UsersService } from '../users/users.service.js';
import { XStocksService } from '../xstocks/xstocks.service.js';
import { ChainService } from './chain.service.js';
import { CLOCK, systemClock } from './clock.js';
import { CONFIG, loadConfig } from './config.js';
import type { AppConfig } from './config.js';
import { createDb, DB } from './db.js';
import type { Db } from './db.js';
import { BALANCE_SOURCE, PRICE_SOURCE } from './sources.js';

@Global()
@Module({
  providers: [
    { provide: CONFIG, useFactory: () => loadConfig() },
    { provide: CLOCK, useValue: systemClock },
    {
      provide: DB,
      useFactory: (config: AppConfig) => createDb(config.databaseUrl),
      inject: [CONFIG],
    },
    ChainService,
    { provide: PRICE_SOURCE, useExisting: ChainService },
    { provide: BALANCE_SOURCE, useExisting: ChainService },
    UsersService,
    XStocksService,
  ],
  exports: [
    CONFIG,
    CLOCK,
    DB,
    ChainService,
    PRICE_SOURCE,
    BALANCE_SOURCE,
    UsersService,
    XStocksService,
  ],
})
export class CoreModule implements OnModuleDestroy {
  constructor(@Inject(DB) private readonly db: Db) {}

  /** Closes the Postgres pool when the app shuts down (and between tests). */
  onModuleDestroy() {
    return this.db.destroy();
  }
}
