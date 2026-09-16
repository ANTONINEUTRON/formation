import { Controller, Get } from '@nestjs/common';
import { XStockDto } from '../domain/dto.js';
import { XStocksService } from './xstocks.service.js';

@Controller('xstocks')
export class XStocksController {
  constructor(private readonly xstocks: XStocksService) {}

  @Get()
  list(): Promise<XStockDto[]> {
    return this.xstocks.list();
  }
}
