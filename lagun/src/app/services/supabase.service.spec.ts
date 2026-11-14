
import { NgZone } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { environment } from '../../environments/environment';
import { SupabaseService } from './supabase.service';

describe('White Box - SupabaseService', () => {
    let service: SupabaseService;
    let originalUrl: string;
    let originalKey: string;

    beforeEach(() => {
        TestBed.resetTestingModule();

        originalUrl = environment.supabaseUrl;
        originalKey = environment.supabaseAnonKey;

        environment.supabaseUrl = 'https://lagun-pruebas.supabase.co';
        environment.supabaseAnonKey = 'clave-publica-de-pruebas';

        localStorage.removeItem('lagun-auth-token');

        TestBed.configureTestingModule({
            providers: [SupabaseService],
        });

        service = TestBed.inject(SupabaseService);
    });

    afterEach(() => {
        service?.supabase.auth.stopAutoRefresh();

        TestBed.resetTestingModule();

        environment.supabaseUrl = originalUrl;
        environment.supabaseAnonKey = originalKey;

        localStorage.removeItem('lagun-auth-token');
    });

    it('WEB-WB-22: construye el cliente Supabase', () => {
        expect(service).toBeDefined();
        expect(service.supabase).toBeDefined();
        expect(service.supabase.auth).toBeDefined();
        expect(service.supabase.from('news_articles')).toBeDefined();
    });

    it('WEB-WB-23: devuelve siempre el mismo cliente', () => {
        const first = service.supabase;
        const second = service.supabase;

        expect(first).toBe(second);
    });

    it('WEB-WB-24: ejecuta funciones y devuelve su resultado', () => {
        const result = service.run(() => 25 + 17);

        expect(result).toBe(42);
    });

    it('WEB-WB-25: ejecuta dentro de Angular NgZone', () => {
        const result = service.run(() => NgZone.isInAngularZone());

        expect(result).toBe(true);
    });

    it('WEB-WB-26: propaga excepciones de la función ejecutada', () => {
        expect(() =>
            service.run(() => {
                throw new Error('Error controlado');
            }),
        ).toThrow('Error controlado');
    });

    it('WEB-WB-27: conserva el resultado de una función asíncrona', async () => {
        const result = service.run(async () => ({
            status: 'ok',
            count: 3,
        }));

        await expect(result).resolves.toEqual({
            status: 'ok',
            count: 3,
        });
    });
});
