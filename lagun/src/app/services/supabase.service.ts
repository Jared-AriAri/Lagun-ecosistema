import { Injectable, NgZone, inject } from '@angular/core';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { environment } from '../../environments/environment';

@Injectable({ providedIn: 'root' })
export class SupabaseService {
  private client: SupabaseClient;
  private ngZone = inject(NgZone);

  constructor() {
    this.client = createClient(
      environment.supabaseUrl,
      environment.supabaseAnonKey,
      {
        auth: {
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: true,
          storageKey: 'lagun-auth-token',
          lock: async (name, acquireTimeout, fn) => await fn()
        },
        realtime: {
          params: {
            eventsPerSecond: 10,
          }
        }
      }
    );
  }

  get supabase(): SupabaseClient {
    return this.client;
  }

  run<T>(fn: () => T): T {
    return this.ngZone.run(fn);
  }
}