import { Component, OnInit, inject, signal, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterModule } from '@angular/router';
import { ReviewService, ReviewArticle } from '../../../services/review.service';

@Component({
    selector: 'app-review-detail',
    standalone: true,
    imports: [CommonModule, RouterModule],
    templateUrl: './review-detail.page.html',
    changeDetection: ChangeDetectionStrategy.OnPush
})
export class ReviewDetailPage implements OnInit {
    private route = inject(ActivatedRoute);
    private reviewService = inject(ReviewService);

    article = signal<ReviewArticle | null>(null);
    loading = signal(true);
    errorMessage = signal('');

    async ngOnInit() {
        const slug = this.route.snapshot.paramMap.get('slug');

        if (!slug) {
            this.errorMessage.set('No se recibió el slug de la reseña.');
            this.loading.set(false);
            return;
        }

        try {
            const data = await this.reviewService.getReviewBySlug(slug);
            this.article.set(data);
        } catch (error: any) {
            console.error('Error al obtener la reseña:', JSON.stringify(error, null, 2), error);
            this.article.set(null);
            this.errorMessage.set(error?.message || 'No se pudo cargar la reseña.');
        } finally {
            this.loading.set(false);
        }
    }
}