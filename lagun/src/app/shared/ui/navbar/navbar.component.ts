import { Component, HostListener, inject, ChangeDetectorRef, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterModule, NavigationEnd } from '@angular/router';
import { combineLatest, map, startWith, shareReplay, filter, Subscription } from 'rxjs';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-navbar',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './navbar.component.html'
})
export class NavbarComponent implements OnInit, OnDestroy {
  private auth = inject(AuthService);
  private router = inject(Router);
  private cd = inject(ChangeDetectorRef);
  private routerSub?: Subscription;

  isScrolled = false;
  profileMenuOpen = false;
  isMobileOpen = false;

  private readonly initialVm = {
    ready: true,
    loggedIn: false,
    profile: null,
    initial: 'U',
    canSeeWriterPanel: false,
    canSeeAdminPanel: false
  };

  readonly vm$ = combineLatest({
    ready: this.auth.readyChanges().pipe(startWith(true)),
    loggedIn: this.auth.sessionChanges().pipe(map(s => !!s?.user?.id), startWith(false)),
    profile: this.auth.profileChanges().pipe(startWith(null)),
  }).pipe(
    map(({ loggedIn, profile }) => {
      const role = profile?.role ?? 'reader';
      return {
        ready: true,
        loggedIn,
        profile,
        initial: (profile?.full_name?.trim()?.[0] || 'U').toUpperCase(),
        canSeeWriterPanel: loggedIn && (role === 'writer' || role === 'admin'),
        canSeeAdminPanel: loggedIn && role === 'admin'
      };
    }),
    startWith(this.initialVm),
    shareReplay(1)
  );

  links = [
    { label: 'Noticias', path: '/news' },
    { label: 'Reseñas', path: '/reviews' }
  ];

  ngOnInit() {
    this.auth.refreshRole();

    this.routerSub = this.router.events.pipe(
      filter(event => event instanceof NavigationEnd)
    ).subscribe(() => {
      this.isMobileOpen = false;
      this.profileMenuOpen = false;
      setTimeout(() => {
        this.cd.markForCheck();
        this.cd.detectChanges();
      }, 0);
    });
  }

  ngOnDestroy() {
    this.routerSub?.unsubscribe();
  }

  @HostListener('window:scroll', [])
  onWindowScroll() {
    const scroll = window.scrollY > 20;
    if (this.isScrolled !== scroll) {
      this.isScrolled = scroll;
      this.cd.detectChanges();
    }
  }

  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent) {
    const target = event.target as HTMLElement;
    if (!target.closest('.relative')) {
      this.isMobileOpen = false;
      this.profileMenuOpen = false;
      this.cd.detectChanges();
    }
  }

  toggleMobile(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();
    this.isMobileOpen = !this.isMobileOpen;
    this.profileMenuOpen = false;
    this.cd.detectChanges();
  }

  toggleProfileMenu(event: MouseEvent) {
    event.preventDefault();
    event.stopPropagation();
    this.profileMenuOpen = !this.profileMenuOpen;
    this.isMobileOpen = false;
    this.cd.detectChanges();
  }

  navigate(path: string) {
    this.isMobileOpen = false;
    this.profileMenuOpen = false;
    this.router.navigate([path]);
    this.cd.detectChanges();
  }

  goLogin() {
    this.navigate('/login');
  }

  async logout() {
    await this.auth.signOut();
    this.isMobileOpen = false;
    this.profileMenuOpen = false;
    this.router.navigate(['/']);
    this.cd.detectChanges();
  }
}