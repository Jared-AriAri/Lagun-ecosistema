import { Injectable, inject } from '@angular/core';
import { SupabaseService } from './supabase.service';

export interface ReviewArticle {
    id: string;
    slug: string;
    title: string;
    content: string;
    excerpt: string | null;
    cover_image_url: string | null;
    status: 'draft' | 'published' | 'archived';
    author_id: string;
    last_edited_by: string | null;
    created_at: string;
    updated_at: string;
    buy_link: string | null;
    rating: number | null;
    genre_id: string | null;
    game_genres?: { name: string } | null;
    profiles?: { id: string; full_name: string | null; avatar_url: string | null } | null;
}

@Injectable({ providedIn: 'root' })
export class ReviewService {
    private supa = inject(SupabaseService);

    async getPublishedReviews(): Promise<ReviewArticle[]> {
        const { data, error } = await this.supa.supabase
            .from('reviews')
            .select(`
                *,
                game_genres!reviews_genre_id_fkey ( name ),
                profiles:author_id ( id, full_name, avatar_url )
            `)
            .eq('status', 'published')
            .order('created_at', { ascending: false });

        if (error) {
            console.error('Supabase getPublishedReviews error:', JSON.stringify(error, null, 2), error);
            throw error;
        }

        return (data || []).map((art: any) => this.formatReview(art));
    }

    async getGenres() {
        const { data, error } = await this.supa.supabase
            .from('game_genres')
            .select('id, name')
            .order('name', { ascending: true });

        if (error) {
            console.error('Supabase getGenres error:', JSON.stringify(error, null, 2), error);
            throw error;
        }

        return data || [];
    }

    async getReviewBySlug(slug: string): Promise<ReviewArticle> {
        const cleanSlug = (slug || '').trim();

        const { data, error } = await this.supa.supabase
            .from('reviews')
            .select(`
                *,
                game_genres!reviews_genre_id_fkey ( name ),
                profiles:author_id ( id, full_name, avatar_url )
            `)
            .eq('slug', cleanSlug)
            .eq('status', 'published')
            .maybeSingle();

        if (error) {
            console.error('Supabase getReviewBySlug error:', JSON.stringify(error, null, 2), error);
            throw error;
        }

        if (!data) {
            throw new Error(`No se encontró una reseña publicada con slug: ${cleanSlug}`);
        }

        return this.formatReview(data);
    }

    private formatReview(art: any): ReviewArticle {
        return {
            ...art,
            game_genres: Array.isArray(art.game_genres) ? art.game_genres[0] ?? null : art.game_genres ?? null,
            profiles: Array.isArray(art.profiles) ? art.profiles[0] ?? null : art.profiles ?? null
        };
    }
}