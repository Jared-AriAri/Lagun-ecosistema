import { Component, OnInit, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule } from '@angular/router';
import { NewsService, NewsArticle } from '../../../services/news.service';

@Component({
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './news-list.page.html'
})
export class NewsListPage implements OnInit {
  private newsService = inject(NewsService);

  allNews = signal<NewsArticle[]>([]);
  categoriesList = signal<string[]>([]);
  loading = signal(true);
  errorMessage = signal('');

  searchQuery = signal('');
  selectedCategory = signal('TODAS');
  sortOrder = signal<'recientes' | 'antiguos'>('recientes');

  filteredNews = computed(() => {
    let results = [...this.allNews()];
    const query = this.searchQuery().trim().toLowerCase();
    const cat = this.selectedCategory();
    const order = this.sortOrder();

    if (query) {
      results = results.filter((n) =>
        (n.title || '').toLowerCase().includes(query) ||
        (n.excerpt || '').toLowerCase().includes(query) ||
        (n.content || '').toLowerCase().includes(query)
      );
    }

    if (cat !== 'TODAS') {
      results = results.filter((n) =>
        ((n.news_categories?.name || 'GENERAL').toUpperCase()) === cat
      );
    }

    results.sort((a, b) => {
      const dateA = new Date(a.published_at || a.created_at || 0).getTime();
      const dateB = new Date(b.published_at || b.created_at || 0).getTime();
      return order === 'recientes' ? dateB - dateA : dateA - dateB;
    });

    return results;
  });

  async ngOnInit() {
    try {
      const [news, cats] = await Promise.all([
        this.newsService.getPublishedNews(),
        this.newsService.getCategories()
      ]);

      this.allNews.set(news);
      this.categoriesList.set([
        'TODAS',
        ...[...new Set((cats || []).map((c: any) => String(c.name || '').toUpperCase()).filter(Boolean))]
      ]);
      this.errorMessage.set('');
    } catch (error: any) {
      console.error('Error cargando noticias:', JSON.stringify(error, null, 2), error);
      this.allNews.set([]);
      this.categoriesList.set(['TODAS']);
      this.errorMessage.set(error?.message || 'No se pudieron cargar las noticias.');
    } finally {
      this.loading.set(false);
    }
  }

  onSearch(event: Event) {
    const value = (event.target as HTMLInputElement).value ?? '';
    this.searchQuery.set(value);
  }

  filterByCategory(name: string) {
    this.selectedCategory.set(name);
  }

  toggleSort() {
    this.sortOrder.update((o) => (o === 'recientes' ? 'antiguos' : 'recientes'));
  }

  clearFilters() {
    this.searchQuery.set('');
    this.selectedCategory.set('TODAS');
    this.sortOrder.set('recientes');
  }

  trackByNewsId(index: number, item: NewsArticle) {
    return item.id;
  }
}