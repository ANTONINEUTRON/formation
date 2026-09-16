import { Global, Module } from '@nestjs/common';
import { UsersService } from '../users/users.service.js';
import { XStocksService } from '../xstocks/xstocks.service.js';
import { ChainService } from './chain.service.js';
import { CONFIG, loadConfig } from './config.js';
import { DbService } from './db.service.js';

@Global()
@Module({
  providers: [
    { provide: CONFIG, useFactory: () => loadConfig() },
    DbService,
    ChainService,
    UsersService,
    XStocksService,
  ],
  exports: [CONFIG, DbService, ChainService, UsersService, XStocksService],
})
export class CoreModule {}
