import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';

/**
 * Browser origins allowed to call the API.
 *
 * The Android app sends no `Origin` header, so none of this touches it — this
 * exists because the web app does, and `enableCors()` with no argument answers
 * every origin with the caller's own, which would let any page on the internet
 * read a signed-in player's data using their browser's credentials.
 *
 * Localhost is allowed by default so `flutter run -d chrome` works without
 * configuration; the deployed origins come from CORS_ORIGINS.
 */
function allowedOrigins(env: NodeJS.ProcessEnv): (string | RegExp)[] {
  const configured = (env.CORS_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter((origin) => origin.length > 0);

  return [...configured, /^http:\/\/localhost(:\d+)?$/, /^http:\/\/127\.0\.0\.1(:\d+)?$/];
}

async function bootstrap() {
  try {
    process.loadEnvFile();
  } catch {
    // No .env file; use the real environment.
  }
  const app = await NestFactory.create(AppModule);
  app.enableCors({
    origin: allowedOrigins(process.env),
    // The bearer token travels in a header the app sets itself, so there are
    // no cookies to send and no reason to ask for credentialed requests.
    credentials: false,
  });
  await app.listen(process.env.PORT ?? 3000);
}
await bootstrap();
