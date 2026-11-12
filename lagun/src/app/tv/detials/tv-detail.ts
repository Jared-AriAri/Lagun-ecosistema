import { Component, OnInit, OnDestroy, HostListener, inject, ChangeDetectorRef, NgZone } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { SupabaseService } from '../../services/supabase.service';
import { Subscription } from 'rxjs';

@Component({
    selector: 'app-tv-detail',
    standalone: true,
    imports: [CommonModule],
    templateUrl: './tv-detail.html',
    styleUrl: './tv-detail.css'
})
export class TvDetailComponent implements OnInit, OnDestroy {
    private route = inject(ActivatedRoute);
    private supabaseService = inject(SupabaseService);
    private location = inject(Location);
    private cdr = inject(ChangeDetectorRef);
    private ngZone = inject(NgZone);

    item: any = null;
    loading = true;
    private visibilityListener: any;
    private focusListener: any;
    private paramSub: Subscription | null = null;
    private isResyncing = false;

    async ngOnInit() {
        this.paramSub = this.route.paramMap.subscribe(async (params) => {
            const type = params.get('type');
            const slug = params.get('slug');

            if (type && slug) {
                await this.loadDetail(type, slug);
            }
        });

        this.initResyncListeners();
    }

    ngOnDestroy() {
        if (this.paramSub) {
            this.paramSub.unsubscribe();
        }
        if (this.visibilityListener) {
            document.removeEventListener('visibilitychange', this.visibilityListener);
        }
        if (this.focusListener) {
            window.removeEventListener('focus', this.focusListener);
        }
    }

    private initResyncListeners() {
        const handleResync = async () => {
            if (this.isResyncing) return;
            this.isResyncing = true;

            const type = this.route.snapshot.paramMap.get('type');
            const slug = this.route.snapshot.paramMap.get('slug');

            if (type && slug) {
                this.ngZone.run(async () => {
                    try {
                        const client = this.supabaseService.supabase;
                        await client.auth.refreshSession();
                        await this.loadDetail(type, slug);
                    } catch (e) {
                        console.error('Error al resincronizar detalle:', e);
                    } finally {
                        this.isResyncing = false;
                    }
                });
            } else {
                this.isResyncing = false;
            }
        };

        this.visibilityListener = () => {
            if (document.visibilityState === 'visible') {
                handleResync();
            }
        };

        this.focusListener = () => {
            handleResync();
        };

        document.addEventListener('visibilitychange', this.visibilityListener);
        window.addEventListener('focus', this.focusListener);
    }

    async loadDetail(type: string, slug: string) {
        try {
            if (!this.item) {
                this.loading = true;
                this.cdr.detectChanges();
            }

            const client = this.supabaseService.supabase;
            const table = type === 'news' ? 'news_articles' : 'reviews';

            const { data, error } = await client
                .from(table)
                .select('*')
                .eq('slug', slug)
                .single();

            if (error) throw error;

            this.ngZone.run(() => {
                this.item = data;
                this.loading = false;
                this.cdr.detectChanges();
            });
        } catch (error) {
            console.error('Error al cargar detalle en TV:', error);
            this.ngZone.run(() => {
                this.loading = false;
                this.cdr.detectChanges();
            });
        }
    }

    goBack() {
        this.location.back();
    }

    @HostListener('window:keydown', ['$event'])
    handleKeyDown(event: KeyboardEvent) {
        if (event.key === 'Backspace' || event.key === 'Escape' || event.key === 'ArrowLeft') {
            this.goBack();
        }
    }
}