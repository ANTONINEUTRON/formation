import {
  Inject,
  Injectable,
  InternalServerErrorException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { CONFIG } from './config.js';
import type { AppConfig } from './config.js';

/** Lazily-created Supabase client using the service role key. */
@Injectable()
export class DbService {
  private client?: SupabaseClient;

  constructor(@Inject(CONFIG) private readonly config: AppConfig) {}

  get supabase(): SupabaseClient {
    if (!this.client) {
      if (!this.config.supabaseUrl || !this.config.supabaseServiceKey) {
        throw new ServiceUnavailableException(
          'Database is not configured (SUPABASE_URL, SUPABASE_SERVICE_KEY)',
        );
      }
      this.client = createClient(
        this.config.supabaseUrl,
        this.config.supabaseServiceKey,
        { auth: { persistSession: false } },
      );
    }
    return this.client;
  }
}

/** Returns `data` from a Supabase response or throws its error. */
export function unwrap<T>(result: {
  data: T | null;
  error: { message: string } | null;
}): T {
  if (result.error) {
    throw new InternalServerErrorException(result.error.message);
  }
  return result.data as T;
}
