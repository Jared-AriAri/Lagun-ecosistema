import { Component, OnInit, inject, signal, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterModule } from '@angular/router';
import { NewsService, NewsArticle } from '../../../services/news.service';

@Component({
    selector: 'app-news-detail',
    standalone: true,
    imports: [CommonModule, RouterModule],
    templateUrl: './news-detail.page.html',
    changeDetection: ChangeDetectionStrategy.OnPush
})
export class NewsDetailPage implements OnInit {
    private route = inject(ActivatedRoute);
    private newsService = inject(NewsService);

    article = signal<NewsArticle | null>(null);
    loading = signal(true);
    errorMessage = signal('');

    async ngOnInit() {
        const slug = this.route.snapshot.paramMap.get('slug');

        if (!slug) {
            this.errorMessage.set('No se recibió el slug de la noticia.');
            this.loading.set(false);
            return;
        }

        try {
            const data = await this.newsService.getNewsBySlug(slug);
            this.article.set(data);
        } catch (error: any) {
            console.error('Error al obtener la noticia:', JSON.stringify(error, null, 2), error);
            this.article.set(null);
            this.errorMessage.set(error?.message || 'No se pudo cargar la noticia.');
        } finally {
            this.loading.set(false);
        }
    }
}