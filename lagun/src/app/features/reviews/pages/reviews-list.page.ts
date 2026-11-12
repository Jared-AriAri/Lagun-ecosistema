import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { ReviewService, ReviewArticle } from '../../../services/review.service';

@Component({
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './reviews-list.page.html'
})
export class ReviewsListPage implements OnInit {
  private reviewService = inject(ReviewService);

  allReviews = signal<ReviewArticle[]>([]);
  genresList = signal<string[]>([]);
  loading = signal(true);
  errorMessage = signal('');

  searchQuery = signal('');
  selectedGenre = signal('TODOS');
  sortOrder = signal<'recientes' | 'antiguos' | 'mejor-score'>('recientes');

  filteredReviews = computed(() => {
    let results = [...this.allReviews()];
    const query = this.searchQuery().trim().toLowerCase();
    const genre = this.selectedGenre();
    const order = this.sortOrder();

    if (query) {
      results = results.filter((r) =>
        (r.title || '').toLowerCase().includes(query) ||
        (r.excerpt || '').toLowerCase().includes(query) ||
        (r.content || '').toLowerCase().includes(query)
      );
    }

    if (genre !== 'TODOS') {
      results = results.filter((r) =>
        ((r.game_genres?.name || 'GENERAL').toUpperCase()) === genre
      );
    }

    results.sort((a, b) => {
      if (order === 'mejor-score') {
        return (b.rating || 0) - (a.rating || 0);
      }

      const dateA = new Date(a.updated_at || a.created_at || 0).getTime();
      const dateB = new Date(b.updated_at || b.created_at || 0).getTime();
      return order === 'recientes' ? dateB - dateA : dateA - dateB;
    });

    return results;
  });

  async ngOnInit() {
    try {
      const [reviews, genres] = await Promise.all([
        this.reviewService.getPublishedReviews(),
        this.reviewService.getGenres()
      ]);

      this.allReviews.set(reviews);
      this.genresList.set([
        'TODOS',
        ...[...new Set((genres || []).map((g: any) => String(g.name || '').toUpperCase()).filter(Boolean))]
      ]);
      this.errorMessage.set('');
    } catch (error: any) {
      console.error('Error cargando reseñas:', JSON.stringify(error, null, 2), error);
      this.allReviews.set([]);
      this.genresList.set(['TODOS']);
      this.errorMessage.set(error?.message || 'No se pudieron cargar las reseñas.');
    } finally {
      this.loading.set(false);
    }
  }

  onSearch(event: Event) {
    const value = (event.target as HTMLInputElement).value ?? '';
    this.searchQuery.set(value);
  }

  filterByGenre(name: string) {
    this.selectedGenre.set(name);
  }

  setSort(order: 'recientes' | 'antiguos' | 'mejor-score') {
    this.sortOrder.set(order);
  }

  clearFilters() {
    this.searchQuery.set('');
    this.selectedGenre.set('TODOS');
    this.sortOrder.set('recientes');
  }

  trackByReviewId(index: number, item: ReviewArticle) {
    return item.id;
  }
}