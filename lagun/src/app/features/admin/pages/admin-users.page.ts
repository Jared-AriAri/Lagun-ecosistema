import { Component, OnInit, inject, ChangeDetectorRef, NgZone, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { SupabaseService } from '../../../services/supabase.service';

@Component({
    selector: 'app-admin-users',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './admin-users.page.html'
})
export class AdminUsersPage implements OnInit {
    private supa = inject(SupabaseService);
    private cd = inject(ChangeDetectorRef);
    private zone = inject(NgZone);

    users: any[] = [];
    loading = true;

    @HostListener('document:visibilitychange')
    onVisibilityChange() {
        if (document.visibilityState === 'visible') {
            this.fetchUsers();
        }
    }

    async ngOnInit() {
        await this.fetchUsers();
    }

    async fetchUsers() {
        this.zone.run(async () => {
            this.loading = true;
            this.cd.detectChanges();

            try {
                const { data, error } = await this.supa.supabase
                    .from('profiles')
                    .select('id, full_name, avatar_url, role, is_active')
                    .order('created_at', { ascending: false });

                if (error) throw error;
                this.users = data || [];
            } catch (error) {
                console.error(error);
            } finally {
                this.loading = false;
                this.cd.detectChanges();
            }
        });
    }

    async updateRole(user: any) {
        this.zone.run(async () => {
            const { error } = await this.supa.supabase
                .from('profiles')
                .update({ role: user.role })
                .eq('id', user.id);

            if (error) console.error(error);
            this.cd.detectChanges();
        });
    }

    async toggleActive(user: any) {
        this.zone.run(async () => {
            const newStatus = !user.is_active;
            const { error } = await this.supa.supabase
                .from('profiles')
                .update({ is_active: newStatus })
                .eq('id', user.id);

            if (!error) {
                user.is_active = newStatus;
            }
            this.cd.detectChanges();
        });
    }
}