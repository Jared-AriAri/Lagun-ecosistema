import { Injectable, inject } from '@angular/core';
import { SupabaseService } from './supabase.service';

export interface NewsArticle {
    id: string;
    slug: string;
    title: string;
    content: string;
    excerpt: string | null;
    cover_image_url: string | null;
    status: 'draft' | 'published' | 'archived';
    author_id: string;
    last_edited_by: string | null;
    published_at: string | null;
    created_at: string;
    updated_at: string;
    buy_link: string | null;
    category_id: string | null;
    news_categories?: { name: string } | null;
    profiles?: { id: string; full_name: string | null; avatar_url: string | null } | null;
}

@Injectable({ providedIn: 'root' })
export class NewsService {
    private supa = inject(SupabaseService);

    async getPublishedNews(): Promise<NewsArticle[]> {
        const { data, error } = await this.supa.supabase
            .from('news_articles')
            .select(`
                *,
                news_categories!news_articles_category_id_fkey ( name ),
                profiles:author_id ( id, full_name, avatar_url )
            `)
            .eq('status', 'published')
            .order('published_at', { ascending: false });

        if (error) {
            console.error('Supabase getPublishedNews error:', JSON.stringify(error, null, 2), error);
            throw error;
        }

        return (data || []).map((art: any) => this.formatArticle(art));
    }

    async getCategories() {
        const { data, error } = await this.supa.supabase
            .from('news_categories')
            .select('id, name')
            .order('name', { ascending: true });

        if (error) {
            console.error('Supabase getCategories error:', JSON.stringify(error, null, 2), error);
            throw error;
        }

        return data || [];
    }

    async getNewsBySlug(slug: string): Promise<NewsArticle> {
        const cleanSlug = (slug || '').trim();

        const { data, error } = await this.supa.supabase
            .from('news_articles')
            .select(`
                *,
                news_categories!news_articles_category_id_fkey ( name ),
                profiles:author_id ( id, full_name, avatar_url )
            `)
            .eq('slug', cleanSlug)
            .eq('status', 'published')
            .maybeSingle();

        if (error) {
            console.error('Supabase getNewsBySlug error:', JSON.stringify(error, null, 2), error);
            throw error;
        }

        if (!data) {
            throw new Error(`No se encontró una noticia publicada con slug: ${cleanSlug}`);
        }

        return this.formatArticle(data);
    }

    private formatArticle(art: any): NewsArticle {
        return {
            ...art,
            news_categories: Array.isArray(art.news_categories)
                ? art.news_categories[0] ?? null
                : art.news_categories ?? null,
            profiles: Array.isArray(art.profiles)
                ? art.profiles[0] ?? null
                : art.profiles ?? null
        };
    }
}