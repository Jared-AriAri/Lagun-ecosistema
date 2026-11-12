import { TestBed } from '@angular/core/testing';
import { createClient } from '@supabase/supabase-js';
import { afterEach, vi } from 'vitest';
import { NewsService } from './news.service';
import { SupabaseService } from './supabase.service';

// La integración usa NewsService + cliente REST REAL de Supabase.
// Solo el servidor HTTP remoto se reemplaza por respuestas sintéticas.
describe('NewsService + cliente Supabase REST - integración', () => {
  const requestUrls: string[] = [];
  const client = createClient('https://lagun-test.supabase.co', 'anon-key-test', {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false }
  });
  let service: NewsService;

  beforeEach(() => {
    requestUrls.length = 0;
    TestBed.configureTestingModule({
      providers: [NewsService, { provide: SupabaseService, useValue: { supabase: client } }]
    });
    service = TestBed.inject(NewsService);
  });

  afterEach(() => vi.unstubAllGlobals());

  it('flujo correcto: genera consulta REST con filtros y procesa noticia real del protocolo', async () => {
    vi.stubGlobal('fetch', vi.fn(async (input: RequestInfo | URL) => {
      requestUrls.push(String(input));
      return new Response(JSON.stringify([{
        id: 'synthetic-1', slug: 'agua', title: 'Agua', status: 'published',
        news_categories: [{ name: 'Medio ambiente' }], profiles: null
      }]), { status: 200, headers: { 'content-type': 'application/json' } });
    }));

    const news = await service.getPublishedNews();
    expect(news).toHaveLength(1);
    expect(news[0].news_categories).toEqual({ name: 'Medio ambiente' });
    const url = new URL(requestUrls[0]);
    expect(url.pathname).toBe('/rest/v1/news_articles');
    expect(url.searchParams.get('status')).toBe('eq.published');
    expect(url.searchParams.get('order')).toBe('published_at.desc');
  });

  it('flujo de error: propaga un error HTTP del repositorio', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => new Response(
      JSON.stringify({ code: '42501', message: 'permission denied for table news_articles' }),
      { status: 403, headers: { 'content-type': 'application/json' } }
    )));
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      await expect(service.getPublishedNews()).rejects.toMatchObject({ code: '42501' });
    } finally {
      consoleSpy.mockRestore();
    }
  });
});
