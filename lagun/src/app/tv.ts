import { Component, OnInit, OnDestroy, HostListener, inject, NgZone, ChangeDetectorRef, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { SupabaseService } from './services/supabase.service';
import { RealtimeChannel, Subscription } from '@supabase/supabase-js';

interface TvItem {
    id: string;
    slug: string;
    type: 'news' | 'reviews';
    title: string;
    subtitle: string;
    imageUrl: string | null;
    tag: string;
    score?: string;
}

interface TelemetryMetrics {
    reading_time_sec: number;
    stress_level: number;
    sleep_quality: number;
    needs_rest: boolean;
}

interface UserProfile {
    id: string;
    name: string;
    avatarUrl: string | null;
    email?: string;
}

@Component({
    selector: 'app-tv',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './tv.html',
    styleUrl: './tv.css'
})
export class TvComponent implements OnInit, OnDestroy {
    @ViewChild('searchInput') searchInput!: ElementRef<HTMLInputElement>;

    private supabaseService = inject(SupabaseService);
    private router = inject(Router);
    private ngZone = inject(NgZone);
    private cdr = inject(ChangeDetectorRef);
    private channel: RealtimeChannel | null = null;
    private authSubscription: Subscription | null = null;
    private clockInterval: any;
    private visibilityListener: any;
    private isResyncing = false;

    focusedZone: 'grid' | 'search' | 'profile' | 'logout' = 'grid';
    focusedIndex = 0;
    searchQuery = '';
    currentTime = '';
    isAuthLoading = true;
    isOffline = false;

    currentUser: UserProfile | null = null;

    items: TvItem[] = [];
    filteredItems: TvItem[] = [];

    telemetry: TelemetryMetrics = {
        reading_time_sec: 0,
        stress_level: 0,
        sleep_quality: 0,
        needs_rest: false
    };

    async ngOnInit() {
        this.startClock();
        await this.loadAllData();
        this.initSecurityListeners();
        this.initVisibilityListener();
    }

    ngOnDestroy() {
        if (this.channel) {
            this.supabaseService.supabase.removeChannel(this.channel);
        }
        if (this.clockInterval) {
            clearInterval(this.clockInterval);
        }
        if (this.authSubscription) {
            this.authSubscription.unsubscribe();
        }
        if (this.visibilityListener) {
            document.removeEventListener('visibilitychange', this.visibilityListener);
        }
    }

    private initVisibilityListener() {
        this.visibilityListener = () => {
            if (document.visibilityState === 'visible') {
                if (this.isResyncing) return;
                this.isResyncing = true;

                this.ngZone.run(async () => {
                    try {
                        await this.loadAllData();
                    } finally {
                        this.isResyncing = false;
                    }
                });
            }
        };
        document.addEventListener('visibilitychange', this.visibilityListener);
    }

    private async loadAllData() {
        await this.initAuthSession();
        await this.loadData();
        await this.loadTelemetry();
        this.listenToRealtime();
    }

    private async initAuthSession() {
        const client = this.supabaseService.supabase;

        try {
            const { data: { session } } = await client.auth.getSession();
            if (session?.user) {
                await this.loadUserProfile(session.user.id, session.user.email);
            } else {
                this.currentUser = null;
            }
            this.isOffline = false;
        } catch (error) {
            this.currentUser = null;
            this.isOffline = true;
        } finally {
            this.isAuthLoading = false;
            this.cdr.detectChanges();
        }

        if (!this.authSubscription) {
            const { data: { subscription } } = client.auth.onAuthStateChange(async (event, session) => {
                this.ngZone.run(async () => {
                    if (session?.user) {
                        await this.loadUserProfile(session.user.id, session.user.email);
                    } else {
                        this.currentUser = null;
                    }
                    this.isAuthLoading = false;
                    this.cdr.detectChanges();
                });
            });

            this.authSubscription = subscription;
        }
    }

    private async loadUserProfile(userId: string, email?: string) {
        try {
            const client = this.supabaseService.supabase;
            const { data: profile } = await client
                .from('profiles')
                .select('*')
                .eq('id', userId)
                .maybeSingle();

            const displayName = profile?.full_name || email?.split('@')[0] || 'Usuario';

            let rawAvatar = profile?.avatar_url || null;
            let finalAvatarUrl: string | null = null;

            if (rawAvatar) {
                if (rawAvatar.startsWith('http://') || rawAvatar.startsWith('https://')) {
                    finalAvatarUrl = rawAvatar;
                } else {
                    const { data: publicUrlData } = client
                        .storage
                        .from('avatars')
                        .getPublicUrl(rawAvatar);

                    finalAvatarUrl = publicUrlData?.publicUrl || null;
                }
            }

            this.currentUser = {
                id: userId,
                name: displayName,
                avatarUrl: finalAvatarUrl,
                email: email
            };
            this.isOffline = false;
        } catch (error) {
            this.currentUser = {
                id: userId,
                name: email?.split('@')[0] || 'Usuario',
                avatarUrl: null,
                email: email
            };
            this.isOffline = true;
        }
    }

    onLogin() {
        this.router.navigate(['/tv/login'], { queryParams: { returnUrl: '/tv' } });
    }

    async onLogout() {
        try {
            await this.supabaseService.supabase.auth.signOut();
            this.isOffline = false;
        } catch (error) {
            this.isOffline = true;
        }
        this.currentUser = null;
        this.focusedZone = 'grid';
        this.cdr.detectChanges();
    }

    private startClock() {
        this.updateClock();
        this.clockInterval = setInterval(() => {
            this.ngZone.run(() => {
                this.updateClock();
                this.cdr.detectChanges();
            });
        }, 1000);
    }

    private updateClock() {
        const now = new Date();
        this.currentTime = now.toLocaleTimeString('es-ES', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        }) + ' | ' + now.toLocaleDateString('es-ES', {
            weekday: 'short',
            day: 'numeric',
            month: 'short'
        });
    }

    async loadData() {
        try {
            const client = this.supabaseService.supabase;

            const { data: newsArticles } = await client
                .from('news_articles')
                .select('*')
                .order('created_at', { ascending: false })
                .limit(4);

            const { data: reviews } = await client
                .from('reviews')
                .select('*')
                .order('created_at', { ascending: false })
                .limit(4);

            const fetchedItems: TvItem[] = [];

            if (newsArticles) {
                newsArticles.forEach((news: any) => {
                    fetchedItems.push({
                        id: news.id,
                        slug: news.slug || news.id,
                        type: 'news',
                        title: news.title || 'Sin título',
                        subtitle: news.excerpt || news.description || 'Noticia reciente',
                        imageUrl: news.cover_image_url || null,
                        tag: 'NOTICIA'
                    });
                });
            }

            if (reviews) {
                reviews.forEach((review: any) => {
                    fetchedItems.push({
                        id: review.id,
                        slug: review.slug || review.id,
                        type: 'reviews',
                        title: review.title || 'Sin título',
                        subtitle: 'Reseña editorial',
                        imageUrl: review.cover_image_url || null,
                        tag: 'RESEÑA',
                        score: review.rating ? `${review.rating}/10` : undefined
                    });
                });
            }

            this.items = fetchedItems;
            this.applyFilter();
            this.isOffline = false;
            this.cdr.detectChanges();

        } catch (error) {
            this.isOffline = true;
            this.cdr.detectChanges();
        }
    }

    async loadTelemetry() {
        try {
            const client = this.supabaseService.supabase;
            const { data } = await client
                .from('user_telemetry_metrics')
                .select('reading_time_sec, articles_read, scroll_activity, stress_level, sleep_quality')
                .order('updated_at', { ascending: false })
                .limit(1)
                .maybeSingle();

            if (data) {
                this.updateTelemetryState(data);
            }
            this.isOffline = false;
        } catch (error) {
            this.isOffline = true;
        }
    }

    private updateTelemetryState(data: any) {
        const readingTime = data.reading_time_sec ?? 0;
        const stress = data.stress_level ?? data.scroll_activity ?? 0;
        const sleep = data.sleep_quality ?? data.articles_read ?? 0;

        const needsRest = stress > 70 || (sleep > 0 && sleep < 50);

        this.telemetry = {
            reading_time_sec: readingTime,
            stress_level: stress,
            sleep_quality: sleep,
            needs_rest: needsRest
        };

        this.cdr.detectChanges();
    }

    onSearchChange() {
        this.applyFilter();
    }

    applyFilter() {
        if (!this.searchQuery.trim()) {
            this.filteredItems = [...this.items];
        } else {
            const query = this.searchQuery.toLowerCase();
            this.filteredItems = this.items.filter(item =>
                item.title.toLowerCase().includes(query) ||
                item.tag.toLowerCase().includes(query)
            );
        }
        this.focusedIndex = 0;
    }

    openDetail(item: TvItem) {
        if (!item || !item.slug) return;
        this.router.navigate(['/tv', item.type, item.slug]);
    }

    private listenToRealtime() {
        const client = this.supabaseService.supabase;

        if (this.channel) {
            client.removeChannel(this.channel);
            this.channel = null;
        }

        this.channel = client
            .channel('tv-realtime-global')
            .on('postgres_changes', { event: '*', schema: 'public', table: 'news_articles' }, () => {
                this.ngZone.run(() => this.loadData());
            })
            .on('postgres_changes', { event: '*', schema: 'public', table: 'reviews' }, () => {
                this.ngZone.run(() => this.loadData());
            })
            .on('postgres_changes', { event: '*', schema: 'public', table: 'user_telemetry_metrics' }, (payload) => {
                this.ngZone.run(() => {
                    if (payload.new && Object.keys(payload.new).length > 0) {
                        this.updateTelemetryState(payload.new);
                    } else {
                        this.loadTelemetry();
                    }
                });
            })
            .subscribe((status) => {
                if (status === 'CLOSED' || status === 'CHANNEL_ERROR') {
                    setTimeout(() => this.listenToRealtime(), 3000);
                }
            });
    }

    private initSecurityListeners() {
        window.addEventListener('message', (event: MessageEvent) => {
            const allowedOrigins = [
                window.location.origin,
                'http://localhost:4200',
                'http://localhost:3000'
            ];

            if (allowedOrigins.length > 0 && !allowedOrigins.includes(event.origin)) {
                return;
            }

            if (event.data && event.data.type === 'SYNC_TELEMETRY') {
                this.ngZone.run(() => {
                    this.loadData();
                    this.loadTelemetry();
                });
            }
        });
    }

    @HostListener('window:keydown', ['$event'])
    handleKeyDown(event: KeyboardEvent) {
        const maxIndex = this.filteredItems.length - 1;

        if (this.focusedZone === 'search') {
            if (event.key === 'ArrowDown') {
                event.preventDefault();
                this.searchInput?.nativeElement.blur();
                this.focusedZone = 'grid';
                this.focusedIndex = 0;
            } else if (event.key === 'ArrowLeft') {
                event.preventDefault();
                this.searchInput?.nativeElement.blur();
                this.focusedZone = this.currentUser ? 'logout' : 'profile';
            }
            return;
        }

        if (this.focusedZone === 'profile') {
            if (event.key === 'ArrowDown') {
                event.preventDefault();
                this.focusedZone = 'grid';
                this.focusedIndex = 0;
            } else if (event.key === 'ArrowRight') {
                event.preventDefault();
                if (this.currentUser) {
                    this.focusedZone = 'logout';
                } else {
                    this.focusedZone = 'search';
                    setTimeout(() => this.searchInput?.nativeElement.focus(), 50);
                }
            } else if (event.key === 'Enter') {
                event.preventDefault();
                if (!this.currentUser) {
                    this.onLogin();
                }
            }
            return;
        }

        if (this.focusedZone === 'logout') {
            if (event.key === 'ArrowDown') {
                event.preventDefault();
                this.focusedZone = 'grid';
                this.focusedIndex = 0;
            } else if (event.key === 'ArrowLeft') {
                event.preventDefault();
                this.focusedZone = 'profile';
            } else if (event.key === 'ArrowRight') {
                event.preventDefault();
                this.focusedZone = 'search';
                setTimeout(() => this.searchInput?.nativeElement.focus(), 50);
            } else if (event.key === 'Enter') {
                event.preventDefault();
                this.onLogout();
            }
            return;
        }

        if (this.focusedZone === 'grid') {
            switch (event.key) {
                case 'ArrowRight':
                    if (this.focusedIndex % 2 !== 1 && this.focusedIndex + 1 <= maxIndex) {
                        this.focusedIndex += 1;
                    }
                    break;
                case 'ArrowLeft':
                    if (this.focusedIndex % 2 !== 0 && this.focusedIndex - 1 >= 0) {
                        this.focusedIndex -= 1;
                    }
                    break;
                case 'ArrowDown':
                    if (this.focusedIndex + 2 <= maxIndex) {
                        this.focusedIndex += 2;
                    }
                    break;
                case 'ArrowUp':
                    if (this.focusedIndex - 2 >= 0) {
                        this.focusedIndex -= 2;
                    } else {
                        if (this.focusedIndex === 0) {
                            this.focusedZone = 'profile';
                        } else {
                            this.focusedZone = this.currentUser ? 'logout' : 'search';
                            if (!this.currentUser) {
                                setTimeout(() => this.searchInput?.nativeElement.focus(), 50);
                            }
                        }
                    }
                    break;
                case 'Enter':
                    const selectedItem = this.filteredItems[this.focusedIndex];
                    if (selectedItem) {
                        this.openDetail(selectedItem);
                    }
                    break;
            }
        }
    }
}