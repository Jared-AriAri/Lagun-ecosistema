import { Component, OnInit, OnDestroy, inject, NgZone, ChangeDetectorRef, signal, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { SupabaseService } from '../../../services/supabase.service';
import { RouterModule } from '@angular/router';
import { RealtimeChannel } from '@supabase/supabase-js';

@Component({
  selector: 'app-landing',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './landing.page.html',
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class LandingPage implements OnInit, OnDestroy {
  private supa = inject(SupabaseService);
  private zone = inject(NgZone);
  private cd = inject(ChangeDetectorRef);

  latestContent = signal<any[]>([]);
  loading = signal(true);
  activeCardId = signal<any>(null);
  isEventActive = signal(false);
  currentTheme = signal('');
  private channel?: RealtimeChannel;

  ngOnInit() {
    this.evaluateCalendarPeriod();
    this.fetchContent();
    this.setupRealtime();
  }

  ngOnDestroy() {
    if (this.channel) {
      this.supa.supabase.removeChannel(this.channel);
    }
  }

  evaluateCalendarPeriod() {
    const today = new Date();
    const currentMonth = today.getMonth();

    if (currentMonth === 5) {
      this.isEventActive.set(true);
      this.currentTheme.set('theme-cyber-june');
    } else {
      this.isEventActive.set(false);
      this.currentTheme.set('theme-default');
    }
  }

  async fetchContent() {
    this.loading.set(true);
    this.cd.detectChanges();

    const [news, reviews] = await Promise.all([
      this.supa.supabase
        .from('news_articles')
        .select('*')
        .eq('status', 'published')
        .order('published_at', { ascending: false })
        .limit(6),
      this.supa.supabase
        .from('reviews')
        .select('*')
        .eq('status', 'published')
        .order('created_at', { ascending: false })
        .limit(6)
    ]);

    this.zone.run(() => {
      if (news.error) console.error(news.error);
      if (reviews.error) console.error(reviews.error);

      const n = (news.data || []).map((i) => ({
        ...i,
        content_type: 'news',
        route: i.slug ? `/news/${i.slug}` : null
      }));

      const r = (reviews.data || []).map((i) => ({
        ...i,
        content_type: 'review',
        route: i.slug ? `/reviews/${i.slug}` : null
      }));

      const combined = [...n, ...r]
        .sort((a, b) => {
          const dateA = new Date(a.published_at || a.created_at || 0).getTime();
          const dateB = new Date(b.published_at || b.created_at || 0).getTime();
          return dateB - dateA;
        })
        .slice(0, 6);

      this.latestContent.set(combined);
      this.loading.set(false);
      this.cd.detectChanges();
    });
  }

  private setupRealtime() {
    this.channel = this.supa.supabase
      .channel('landing-updates')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'news_articles' }, () => this.fetchContent())
      .on('postgres_changes', { event: '*', schema: 'public', table: 'reviews' }, () => this.fetchContent())
      .subscribe();
  }
}