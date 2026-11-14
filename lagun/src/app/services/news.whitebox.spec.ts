
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { NewsService } from './news.service';
import { SupabaseService } from './supabase.service';

function createQuery() {
    const query = {
        select: vi.fn(),
        eq: vi.fn(),
        order: vi.fn(),
        maybeSingle: vi.fn(),
    };

    query.select.mockReturnValue(query);
    query.eq.mockReturnValue(query);
    query.order.mockResolvedValue({ data: [], error: null });
    query.maybeSingle.mockResolvedValue({ data: null, error: null });

    return query;
}

describe('White Box - NewsService', () => {
    let service: NewsService;
    let query: ReturnType<typeof createQuery>;
    let from: ReturnType<typeof vi.fn>;

    const article = {
        id: 'news-1',
        slug: 'noticia-prueba',
        title: 'Noticia de prueba',
        content: 'Contenido',
        excerpt: 'Resumen',
        cover_image_url: null,
        status: 'published',
        author_id: 'autor-1',
        last_edited_by: null,
        published_at: '2026-11-13T12:00:00Z',
        created_at: '2026-11-12T12:00:00Z',
        updated_at: '2026-11-13T12:00:00Z',
        buy_link: null,
        category_id: 'cat-1',
    };

    beforeEach(() => {
        query = createQuery();
        from = vi.fn().mockReturnValue(query);

        TestBed.configureTestingModule({
            providers: [
                {
                    provide: SupabaseService,
                    useValue: {
                        supabase: { from },
                    },
                },
            ],
        });

        service = TestBed.inject(NewsService);
    });

    afterEach(() => {
        vi.restoreAllMocks();
    });

    it('WEB-WB-09: consulta noticias publicadas ordenadas', async () => {
        query.order.mockResolvedValue({
            data: [article],
            error: null,
        });

        const result = await service.getPublishedNews();

        expect(from).toHaveBeenCalledWith('news_articles');
        expect(query.eq).toHaveBeenCalledWith('status', 'published');
        expect(query.order).toHaveBeenCalledWith('published_at', {
            ascending: false,
        });
        expect(result).toHaveLength(1);
        expect(result[0].title).toBe('Noticia de prueba');
    });

    it('WEB-WB-10: devuelve lista vacía cuando no existen noticias', async () => {
        query.order.mockResolvedValue({
            data: null,
            error: null,
        });

        const result = await service.getPublishedNews();

        expect(result).toEqual([]);
    });

    it('WEB-WB-11: propaga errores al consultar noticias', async () => {
        const error = { code: '42501', message: 'Sin permisos' };
        vi.spyOn(console, 'error').mockImplementation(() => { });

        query.order.mockResolvedValue({
            data: null,
            error,
        });

        await expect(service.getPublishedNews()).rejects.toBe(error);
    });

    it('WEB-WB-12: transforma relaciones devueltas como arreglos', async () => {
        query.order.mockResolvedValue({
            data: [
                {
                    ...article,
                    news_categories: [{ name: 'Tecnología' }],
                    profiles: [
                        {
                            id: 'autor-1',
                            full_name: 'Autor prueba',
                            avatar_url: null,
                        },
                    ],
                },
            ],
            error: null,
        });

        const result = await service.getPublishedNews();

        expect(result[0].news_categories).toEqual({
            name: 'Tecnología',
        });
        expect(result[0].profiles?.full_name).toBe('Autor prueba');
    });

    it('WEB-WB-13: convierte relaciones vacías en null', async () => {
        query.order.mockResolvedValue({
            data: [
                {
                    ...article,
                    news_categories: [],
                    profiles: [],
                },
            ],
            error: null,
        });

        const result = await service.getPublishedNews();

        expect(result[0].news_categories).toBeNull();
        expect(result[0].profiles).toBeNull();
    });

    it('WEB-WB-14: conserva relaciones representadas como objetos', async () => {
        query.order.mockResolvedValue({
            data: [
                {
                    ...article,
                    news_categories: { name: 'Noticias' },
                    profiles: {
                        id: 'autor-1',
                        full_name: 'Autor',
                        avatar_url: null,
                    },
                },
            ],
            error: null,
        });

        const result = await service.getPublishedNews();

        expect(result[0].news_categories?.name).toBe('Noticias');
        expect(result[0].profiles?.id).toBe('autor-1');
    });

    it('WEB-WB-15: obtiene categorías en orden ascendente', async () => {
        query.order.mockResolvedValue({
            data: [
                { id: '1', name: 'Ciencia' },
                { id: '2', name: 'Tecnología' },
            ],
            error: null,
        });

        const result = await service.getCategories();

        expect(from).toHaveBeenCalledWith('news_categories');
        expect(query.select).toHaveBeenCalledWith('id, name');
        expect(query.order).toHaveBeenCalledWith('name', {
            ascending: true,
        });
        expect(result).toHaveLength(2);
    });

    it('WEB-WB-16: devuelve lista vacía si las categorías son null', async () => {
        query.order.mockResolvedValue({
            data: null,
            error: null,
        });

        expect(await service.getCategories()).toEqual([]);
    });

    it('WEB-WB-17: propaga errores al obtener categorías', async () => {
        const error = { code: '500', message: 'Error de consulta' };
        vi.spyOn(console, 'error').mockImplementation(() => { });

        query.order.mockResolvedValue({
            data: null,
            error,
        });

        await expect(service.getCategories()).rejects.toBe(error);
    });

    it('WEB-WB-18: limpia espacios del slug antes de consultar', async () => {
        query.maybeSingle.mockResolvedValue({
            data: article,
            error: null,
        });

        const result = await service.getNewsBySlug('  noticia-prueba  ');

        expect(from).toHaveBeenCalledWith('news_articles');
        expect(query.eq).toHaveBeenCalledWith('slug', 'noticia-prueba');
        expect(query.eq).toHaveBeenCalledWith('status', 'published');
        expect(query.maybeSingle).toHaveBeenCalledOnce();
        expect(result.id).toBe('news-1');
    });

    it('WEB-WB-19: informa cuando el slug no existe', async () => {
        query.maybeSingle.mockResolvedValue({
            data: null,
            error: null,
        });

        await expect(
            service.getNewsBySlug('inexistente'),
        ).rejects.toThrow(
            'No se encontró una noticia publicada con slug: inexistente',
        );
    });

    it('WEB-WB-20: propaga errores en la consulta por slug', async () => {
        const error = { code: '42501', message: 'Acceso denegado' };
        vi.spyOn(console, 'error').mockImplementation(() => { });

        query.maybeSingle.mockResolvedValue({
            data: null,
            error,
        });

        await expect(service.getNewsBySlug('privada')).rejects.toBe(error);
    });

    it('WEB-WB-21: registra el comportamiento con slug vacío', async () => {
        query.maybeSingle.mockResolvedValue({
            data: null,
            error: null,
        });

        await expect(service.getNewsBySlug('   ')).rejects.toThrow(
            'No se encontró una noticia publicada con slug:',
        );

        expect(query.eq).toHaveBeenCalledWith('slug', '');
    });
});
