import { TestBed } from '@angular/core/testing';
import { NewsService } from './news.service';
import { SupabaseService } from './supabase.service';

const article = (overrides: Record<string, unknown> = {}) => ({
  id: 'test-1', slug: 'noticia-ejemplo', title: 'Noticia de prueba',
  content: 'Contenido sintético', excerpt: null, cover_image_url: null,
  status: 'published', author_id: 'author-test', last_edited_by: null,
  published_at: '2026-01-01T00:00:00Z', created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-01-01T00:00:00Z', buy_link: null, category_id: null,
  news_categories: [{ name: 'Ciencia' }], profiles: [], ...overrides
});

describe('NewsService - unitarias (repositorio aislado)', () => {
  let service: NewsService;
  let response: { data: unknown; error: unknown };
  let eqCalls: Array<[string, string]>;

  beforeEach(() => {
    response = { data: null, error: null };
    eqCalls = [];
    const query: any = {
      select: () => query,
      eq: (field: string, value: string) => { eqCalls.push([field, value]); return query; },
      order: async () => response,
      maybeSingle: async () => response
    };
    TestBed.configureTestingModule({
      providers: [NewsService, { provide: SupabaseService, useValue: {
        supabase: { from: () => query }
      }}]
    });
    service = TestBed.inject(NewsService);
  });

  it('caso válido: devuelve solo noticias publicadas y normaliza relaciones', async () => {
    response = { data: [article()], error: null };
    const result = await service.getPublishedNews();
    expect(result).toHaveLength(1);
    expect(result[0].news_categories).toEqual({ name: 'Ciencia' });
    expect(result[0].profiles).toBeNull();
    expect(eqCalls).toContainEqual(['status', 'published']);
  });

  it('caso límite: una consulta vacía devuelve una lista vacía', async () => {
    response = { data: null, error: null };
    await expect(service.getPublishedNews()).resolves.toEqual([]);
  });

  it('caso inválido: un slug inexistente produce error explícito', async () => {
    response = { data: null, error: null };
    await expect(service.getNewsBySlug(' inexistente ')).rejects.toThrow('No se encontró una noticia publicada');
    expect(eqCalls).toContainEqual(['slug', 'inexistente']);
    expect(eqCalls).toContainEqual(['status', 'published']);
  });
});
