import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../../core/auth/auth.service';
import { SupabaseService } from '../../../services/supabase.service';

@Component({
    selector: 'app-mi-cuenta-page',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './mi-cuenta.page.html',
})
export class MiCuentaPage implements OnInit {
    private auth = inject(AuthService);
    private supa = inject(SupabaseService);
    private cd = inject(ChangeDetectorRef);

    email = '';
    role = '';
    fullName = '';
    bio = '';
    avatarUrl = '';

    loading = false;
    successMsg = '';
    errorMsg = '';
    isDragging = false;
    uploadingImage = false;

    ngOnInit() {
        this.loadData();
    }

    loadData() {
        const session = this.auth.sessionSnapshot();
        this.email = session?.user?.email || '';
        const profile = this.auth.profileSnapshot();
        if (profile) {
            this.role = profile.role;
            this.fullName = profile.full_name || '';
            this.bio = profile.bio || '';
            this.avatarUrl = profile.avatar_url || '';
        }
        this.cd.detectChanges();
    }

    onDragOver(e: DragEvent) {
        e.preventDefault();
        this.isDragging = true;
    }

    onDragLeave(e: DragEvent) {
        e.preventDefault();
        this.isDragging = false;
    }

    onDrop(e: DragEvent) {
        e.preventDefault();
        this.isDragging = false;
        if (e.dataTransfer?.files.length) {
            this.handleFile(e.dataTransfer.files[0]);
        }
    }

    onFileSelected(e: Event) {
        const input = e.target as HTMLInputElement;
        if (input.files?.length) {
            this.handleFile(input.files[0]);
        }
    }

    async handleFile(file: File) {
        if (!file.type.startsWith('image/')) {
            this.errorMsg = 'Archivo no válido';
            return;
        }

        this.uploadingImage = true;
        this.errorMsg = '';
        this.successMsg = '';
        this.cd.detectChanges();

        try {
            const user = this.auth.sessionSnapshot()?.user;
            if (!user) throw new Error('No session');

            const fileExt = file.name.split('.').pop()?.toLowerCase();
            const fileName = `${user.id}.${fileExt}`;

            const { error: uploadError } = await this.supa.supabase.storage
                .from('avatars')
                .upload(fileName, file, {
                    upsert: true,
                    contentType: file.type
                });

            if (uploadError) throw uploadError;

            const { data } = this.supa.supabase.storage
                .from('avatars')
                .getPublicUrl(fileName);

            this.avatarUrl = `${data.publicUrl}?t=${Date.now()}`;
            this.successMsg = 'Imagen lista';
        } catch (e: any) {
            this.errorMsg = 'Error al subir imagen';
        } finally {
            this.uploadingImage = false;
            this.cd.detectChanges();
        }
    }

    async saveProfile() {
        if (this.loading || this.uploadingImage) return;

        this.loading = true;
        this.errorMsg = '';
        this.successMsg = '';
        this.cd.detectChanges();

        try {
            const user = this.auth.sessionSnapshot()?.user;
            if (!user) throw new Error('No session');

            const { error } = await this.supa.supabase
                .from('profiles')
                .update({
                    full_name: this.fullName,
                    bio: this.bio,
                    avatar_url: this.avatarUrl,
                    updated_at: new Date().toISOString()
                })
                .eq('id', user.id);

            if (error) throw error;

            await this.auth.refreshRole();
            this.successMsg = '¡Perfil actualizado!';
        } catch (e: any) {
            this.errorMsg = 'Error al guardar cambios';
        } finally {
            this.loading = false;
            this.cd.detectChanges();
        }
    }

    get initial(): string {
        return (this.fullName[0] || 'U').toUpperCase();
    }
}