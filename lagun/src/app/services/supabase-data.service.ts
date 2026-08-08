import { Injectable } from '@angular/core';
import { SupabaseService } from '../services/supabase.service';

@Injectable({ providedIn: 'root' })
export class SupabaseDataService {
  constructor(private supa: SupabaseService) {}

  async getArticles() {
    const { data, error } = await this.supa.supabase
      .from('news_articles')
      .select('*');

    if (error) throw error;
    return data;
  }
}
