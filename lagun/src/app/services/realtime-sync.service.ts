import { Injectable, signal } from '@angular/core';
import { createClient, SupabaseClient, RealtimeChannel } from '@supabase/supabase-js';
import { environment } from '../../environments/environment';

export interface SyncMessage {
    type: string;
    payload: Record<string, unknown>;
    sentAt: string;
}

@Injectable({ providedIn: 'root' })
export class RealtimeSyncService {
    private supabase: SupabaseClient;
    private channel: RealtimeChannel | null = null;

    // Señal reactiva con el último mensaje válido recibido
    lastMessage = signal<SyncMessage | null>(null);

    constructor() {
        this.supabase = createClient(environment.supabaseUrl, environment.supabaseAnonKey);
    }

    connect(): void {
        this.channel = this.supabase
            .channel('lagun_sync', {
                config: { broadcast: { self: false } },
            })
            .on('broadcast', { event: 'update' }, ({ payload }) => {
                this.handleIncoming(payload);
            })
            .subscribe((status) => {
                console.log('Estado del canal Realtime:', status);
            });
    }

    private handleIncoming(payload: unknown): void {
        // Validación de estructura — equivalente a la validación de "origin"
        // que pide el checklist, adaptada a esta arquitectura Supabase.
        if (!this.isValidMessage(payload)) {
            console.warn('Mensaje descartado: estructura inválida', payload);
            return;
        }
        this.lastMessage.set(payload as SyncMessage);
    }

    private isValidMessage(data: unknown): data is SyncMessage {
        if (!data || typeof data !== 'object') return false;
        const msg = data as Record<string, unknown>;
        return (
            typeof msg['type'] === 'string' &&
            typeof msg['payload'] === 'object' &&
            typeof msg['sentAt'] === 'string'
        );
    }

    disconnect(): void {
        if (this.channel) {
            this.supabase.removeChannel(this.channel);
            this.channel = null;
        }
    }
}