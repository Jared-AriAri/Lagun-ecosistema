import { Component, EventEmitter, Input, Output, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { SupabaseService } from '../../../../services/supabase.service';

@Component({
    selector: 'app-news-modal',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './news-modal.component.html'
})
export class NewsModalComponent implements OnInit {
    @Input() item: any = null;
    @Output() close = new EventEmitter<void>();
    @Output() save = new EventEmitter<any>();

    private supa = inject(SupabaseService);
    private cd = inject(ChangeDetectorRef);

    uploading = false;
    categories: any[] = [];

    formData: any = {
        id: null,
        title: '',
        excerpt: '',
        content: '',
        cover_image_url: '',
        status: 'draft',
        category_id: null,
        buy_link: ''
    };

    async ngOnInit() {
        await this.loadCategories();

        if (this.item) {
            this.formData = {
                id: this.item.id ?? null,
                title: this.item.title ?? '',
                excerpt: this.item.excerpt ?? '',
                content: this.item.content ?? '',
                cover_image_url: this.item.cover_image_url ?? '',
                status: this.item.status ?? 'draft',
                category_id: this.item.category_id ?? null,
                buy_link: this.item.buy_link ?? ''
            };
        }

        this.cd.detectChanges();
    }

    async loadCategories() {
        const { data, error } = await this.supa.supabase
            .from('news_categories')
            .select('id, name')
            .order('name', { ascending: true });

        if (!error && data) {
            this.categories = data;
            this.cd.detectChanges();
        }
    }

    closeModal(event?: Event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }
        this.close.emit();
    }

    async uploadImage(event: any) {
        const file = event.target?.files?.[0] || event.dataTransfer?.files?.[0];
        if (!file) return;

        this.uploading = true;
        this.cd.detectChanges();

        const fileName = `${Date.now()}-${file.name}`;
        const filePath = `news/${fileName}`;

        try {
            const { error: uploadError } = await this.supa.supabase.storage
                .from('media')
                .upload(filePath, file);

            if (!uploadError) {
                const { data } = this.supa.supabase.storage
                    .from('media')
                    .getPublicUrl(filePath);

                this.formData.cover_image_url = data.publicUrl;
            }
        } finally {
            this.uploading = false;
            this.cd.detectChanges();
        }
    }

    removeImage(event?: Event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }

        this.formData.cover_image_url = '';
        this.cd.detectChanges();
    }

    onSubmit() {
        const payload = {
            id: this.formData.id ?? undefined,
            title: (this.formData.title ?? '').trim(),
            excerpt: (this.formData.excerpt ?? '').trim(),
            content: (this.formData.content ?? '').trim(),
            cover_image_url: this.formData.cover_image_url ?? '',
            status: this.formData.status ?? 'draft',
            category_id: this.formData.category_id || null,
            buy_link: (this.formData.buy_link ?? '').trim()
        };

        this.save.emit(payload);
    }
}