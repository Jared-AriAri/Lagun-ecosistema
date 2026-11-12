import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef, NgZone } from '@angular/core';
import { CommonModule } from '@angular/common';
import { SupabaseService } from '../../../services/supabase.service';
import { NewsModalComponent } from '../components/news-modal/news-modal.component';
import { ReviewModalComponent } from '../components/review-modal/review-modal.component';
import { RealtimeChannel } from '@supabase/supabase-js';

@Component({
    selector: 'app-writer',
    standalone: true,
    imports: [
        CommonModule,
        NewsModalComponent,
        ReviewModalComponent
    ],
    templateUrl: './writer.page.html'
})
export class WriterPage implements OnInit, OnDestroy {
    private supa = inject(SupabaseService);
    private cd = inject(ChangeDetectorRef);
    private zone = inject(NgZone);

    activeTab: 'news' | 'reviews' = 'news';
    items: any[] = [];
    loading = false;
    currentUserId: string | null = null;
    isAdmin = false;

    showNewsModal = false;
    showReviewModal = false;
    selectedItem: any = null;

    private channel?: RealtimeChannel;
    private newsCategoriesMap: Record<string, string> = {};
    private gameGenresMap: Record<string, string> = {};

    async ngOnInit() {
        const {
            data: { session }
        } = await this.supa.supabase.auth.getSession();

        if (session?.user) {
            this.currentUserId = session.user.id;

            const { data: profile } = await this.supa.supabase
                .from('profiles')
                .select('role')
                .eq('id', this.currentUserId)
                .maybeSingle();

            this.isAdmin = profile?.role === 'admin' || profile?.role === 'superadmin';
        }

        await this.loadReferenceData();
        await this.loadData(true);
        this.setupRealtime();
        this.cd.detectChanges();
    }

    ngOnDestroy() {
        if (this.channel) {
            this.supa.supabase.removeChannel(this.channel);
        }
    }

    async setTab(tab: 'news' | 'reviews') {
        if (this.activeTab === tab) return;
        this.activeTab = tab;
        await this.loadData(true);
    }

    async loadReferenceData() {
        const [{ data: categories }, { data: genres }] = await Promise.all([
            this.supa.supabase
                .from('news_categories')
                .select('id, name'),
            this.supa.supabase
                .from('game_genres')
                .select('id, name')
        ]);

        this.newsCategoriesMap = (categories || []).reduce((acc: Record<string, string>, item: any) => {
            acc[item.id] = item.name;
            return acc;
        }, {});

        this.gameGenresMap = (genres || []).reduce((acc: Record<string, string>, item: any) => {
            acc[item.id] = item.name;
            return acc;
        }, {});
    }

    async loadData(showSpinner = false) {
        if (showSpinner) {
            this.loading = true;
            this.cd.detectChanges();
        }

        const table = this.activeTab === 'news' ? 'news_articles' : 'reviews';

        const { data, error } = await this.supa.supabase
            .from(table as any)
            .select('*')
            .order('created_at', { ascending: false });

        this.zone.run(() => {
            if (!error && data) {
                this.items = (data as any[]).map((item) => ({
                    ...item,
                    category_name: this.activeTab === 'news'
                        ? (item.category_id ? this.newsCategoriesMap[item.category_id] || 'Sin categoría' : 'Sin categoría')
                        : null,
                    genre_name: this.activeTab === 'reviews'
                        ? (item.genre_id ? this.gameGenresMap[item.genre_id] || 'Sin género' : 'Sin género')
                        : null
                }));
            } else {
                console.error('Error cargando contenido:', error);
                this.items = [];
            }

            this.loading = false;
            this.cd.detectChanges();
        });
    }

    private setupRealtime() {
        this.channel = this.supa.supabase
            .channel('writer-realtime')
            .on(
                'postgres_changes',
                { event: '*', schema: 'public', table: 'news_articles' },
                async () => {
                    await this.loadReferenceData();
                    await this.loadData();
                }
            )
            .on(
                'postgres_changes',
                { event: '*', schema: 'public', table: 'reviews' },
                async () => {
                    await this.loadReferenceData();
                    await this.loadData();
                }
            )
            .on(
                'postgres_changes',
                { event: '*', schema: 'public', table: 'news_categories' },
                async () => {
                    await this.loadReferenceData();
                    await this.loadData();
                }
            )
            .on(
                'postgres_changes',
                { event: '*', schema: 'public', table: 'game_genres' },
                async () => {
                    await this.loadReferenceData();
                    await this.loadData();
                }
            )
            .subscribe();
    }

    canEdit(item: any) {
        if (!this.currentUserId) return false;
        return this.isAdmin || item.author_id === this.currentUserId;
    }

    getStatusLabel(status: string | null | undefined) {
        switch (status) {
            case 'published':
                return 'Publicado';
            case 'archived':
                return 'Archivado';
            case 'draft':
            default:
                return 'Borrador';
        }
    }

    getStatusClass(status: string | null | undefined) {
        switch (status) {
            case 'published':
                return 'bg-emerald-500/15 text-emerald-300 border border-emerald-400/20';
            case 'archived':
                return 'bg-amber-500/15 text-amber-300 border border-amber-400/20';
            case 'draft':
            default:
                return 'bg-white/10 text-white/70 border border-white/10';
        }
    }

    formatDate(date: string | null | undefined) {
        if (!date) return 'Sin fecha';

        return new Intl.DateTimeFormat('es-MX', {
            day: '2-digit',
            month: 'long',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }).format(new Date(date));
    }

    getDisplayDate(item: any) {
        if (this.activeTab === 'news') {
            return item.published_at || item.updated_at || item.created_at || null;
        }

        return item.updated_at || item.created_at || null;
    }

    openModal(item?: any) {
        if (item) {
            if (!this.canEdit(item)) return;
            this.selectedItem = JSON.parse(JSON.stringify(item));
        } else {
            this.selectedItem =
                this.activeTab === 'news'
                    ? {
                        title: '',
                        excerpt: '',
                        content: '',
                        cover_image_url: '',
                        status: 'draft',
                        category_id: null,
                        buy_link: ''
                    }
                    : {
                        title: '',
                        excerpt: '',
                        content: '',
                        cover_image_url: '',
                        status: 'draft',
                        rating: 10,
                        buy_link: '',
                        genre_id: ''
                    };
        }

        if (this.activeTab === 'news') {
            this.showNewsModal = true;
            this.showReviewModal = false;
        } else {
            this.showReviewModal = true;
            this.showNewsModal = false;
        }

        this.cd.detectChanges();
    }

    closeModals() {
        this.showNewsModal = false;
        this.showReviewModal = false;
        this.selectedItem = null;
        this.cd.detectChanges();
    }

    async handleSave(payload: any) {
        if (!this.currentUserId) return;

        const table = this.activeTab === 'news' ? 'news_articles' : 'reviews';
        const isUpdate = !!payload.id;

        if (isUpdate) {
            const existing = this.items.find((item) => item.id === payload.id);
            if (!existing || !this.canEdit(existing)) {
                alert('No puedes modificar contenido que no es tuyo.');
                return;
            }
        }

        const {
            id,
            category_name,
            genre_name,
            slug,
            ...data
        } = payload;

        const dataToSave: any = {
            ...data,
            last_edited_by: this.currentUserId,
            updated_at: new Date().toISOString()
        };

        if (this.activeTab === 'news') {
            if (dataToSave.status === 'published' && !dataToSave.published_at) {
                dataToSave.published_at = new Date().toISOString();
            }

            if (dataToSave.status !== 'published') {
                delete dataToSave.published_at;
            }
        }

        let error = null;

        if (isUpdate) {
            const response = await this.supa.supabase
                .from(table)
                .update(dataToSave)
                .eq('id', id);

            error = response.error;
        } else {
            const response = await this.supa.supabase
                .from(table)
                .insert([
                    {
                        ...dataToSave,
                        author_id: this.currentUserId
                    }
                ]);

            error = response.error;
        }

        if (error) {
            console.error('Error guardando contenido:', error);
            alert('No se pudo guardar el contenido.');
            return;
        }

        await this.loadReferenceData();
        this.closeModals();
        await this.loadData();
    }

    async deleteItem(item: any) {
        if (!this.canEdit(item)) {
            alert('No puedes borrar contenido que no es tuyo.');
            return;
        }

        const confirmed = confirm(
            this.activeTab === 'news'
                ? '¿Seguro que quieres borrar esta noticia?'
                : '¿Seguro que quieres borrar esta reseña?'
        );

        if (!confirmed) return;

        const table = this.activeTab === 'news' ? 'news_articles' : 'reviews';

        const { error } = await this.supa.supabase
            .from(table)
            .delete()
            .eq('id', item.id);

        if (error) {
            console.error('Error borrando contenido:', error);
            alert('No se pudo borrar el contenido.');
            return;
        }

        await this.loadReferenceData();
        await this.loadData();
    }
}