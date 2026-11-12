import { Component, EventEmitter, Input, Output, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { SupabaseService } from '../../../../services/supabase.service';

@Component({
    selector: 'app-review-modal',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './review-modal.component.html'
})
export class ReviewModalComponent implements OnInit {
    @Input() item: any = null;
    @Output() close = new EventEmitter<void>();
    @Output() save = new EventEmitter<any>();

    private supa = inject(SupabaseService);
    private cd = inject(ChangeDetectorRef);

    uploading = false;
    genres: any[] = [];

    formData: any = {
        title: '',
        slug: '',
        excerpt: '',
        content: '',
        cover_image_url: '',
        status: 'draft',
        rating: 10,
        buy_link: '',
        genre_id: ''
    };

    async ngOnInit() {
        await this.loadGenres();
        if (this.item) {
            this.formData = { ...this.item };
        }
    }

    async loadGenres() {
        const { data } = await this.supa.supabase
            .from('game_genres')
            .select('*')
            .order('name', { ascending: true });

        if (data) {
            this.genres = data;
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
        const file = event.target.files?.[0] || event.dataTransfer?.files?.[0];
        if (!file) return;

        this.uploading = true;
        this.cd.detectChanges();

        const fileName = `${Date.now()}-${file.name}`;
        const filePath = `reviews/${fileName}`;

        try {
            const { error: uploadError } = await this.supa.supabase.storage
                .from('media')
                .upload(filePath, file);

            if (!uploadError) {
                const { data } = this.supa.supabase.storage.from('media').getPublicUrl(filePath);
                this.formData.cover_image_url = data.publicUrl;
            }
        } finally {
            this.uploading = false;
            this.cd.detectChanges();
        }
    }

    async removeImage() {
        this.formData.cover_image_url = '';
        this.cd.detectChanges();
    }

    generateSlug() {
        if (this.formData.title && !this.item?.id) {
            this.formData.slug = this.formData.title
                .toLowerCase()
                .normalize("NFD").replace(/[\u0300-\u036f]/g, "")
                .replace(/[^a-z0-9]+/g, '-')
                .replace(/(^-|-$)+/g, '');
        }
    }

    onSubmit() {
        if (!this.formData.slug) this.generateSlug();
        this.save.emit(this.formData);
    }
}