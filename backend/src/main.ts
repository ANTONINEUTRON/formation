import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';

async function bootstrap() {
  try {
    process.loadEnvFile();
  } catch {
    // No .env file; use the real environment.
  }
  const app = await NestFactory.create(AppModule);
  app.enableCors();
  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
