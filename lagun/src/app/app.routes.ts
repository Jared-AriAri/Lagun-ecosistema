import { Routes } from '@angular/router';
import { PublicLayoutComponent } from './layouts/public-layout/public-layout.component';
import { AdminGuard } from './core/auth/admin.guard';
import { AuthGuard } from './core/auth/auth.guard';

export const routes: Routes = [
  {
    path: 'tv',
    loadComponent: () =>
      import('./tv').then((m) => m.TvComponent),
  },
  {
    path: 'tv/login',
    loadComponent: () =>
      import('./tv/auth/pages/login.page').then((m) => m.LoginPage),
  },
  {
    path: 'tv/register',
    loadComponent: () =>
      import('./tv/auth/pages/register.page').then((m) => m.RegisterPage),
  },
  {
    path: 'tv/:type/:slug',
    loadComponent: () =>
      import('./tv/detials/tv-detail').then((m) => m.TvDetailComponent),
  },
  {
    path: 'tv/confirm-email',
    loadComponent: () => import('./tv/auth/pages/confirm-email.page').then((m) => m.ConfirmEmailPage),
  },
  {
    path: '',
    component: PublicLayoutComponent,
    children: [
      {
        path: '',
        loadComponent: () =>
          import('./features/landing/pages/landing.page').then((m) => m.LandingPage),
      },
      {
        path: 'news',
        loadComponent: () =>
          import('./features/news/pages/news-list.page').then((m) => m.NewsListPage),
      },
      {
        path: 'news/:slug',
        loadComponent: () =>
          import('./features/news/pages/news-detail.page').then((m) => m.NewsDetailPage),
      },
      {
        path: 'reviews',
        loadComponent: () =>
          import('./features/reviews/pages/reviews-list.page').then((m) => m.ReviewsListPage),
      },
      {
        path: 'reviews/:slug',
        loadComponent: () =>
          import('./features/reviews/pages/review-detail.page').then((m) => m.ReviewDetailPage),
      },
      {
        path: 'terminos',
        loadComponent: () =>
          import('./features/legal/pages/terms.page').then((m) => m.TermsPage),
      },
      {
        path: 'privacidad',
        loadComponent: () =>
          import('./features/legal/pages/privacy.page').then((m) => m.PrivacyPage),
      },
      {
        path: 'login',
        loadComponent: () =>
          import('./features/auth/pages/login.page').then((m) => m.LoginPage),
      },
      {
        path: 'register',
        loadComponent: () =>
          import('./features/auth/pages/register.page').then((m) => m.RegisterPage),
      },
      {
        path: 'mi-cuenta',
        canActivate: [AuthGuard],
        loadComponent: () =>
          import('./features/profile/pages/mi-cuenta.page').then((m) => m.MiCuentaPage),
      },
      {
        path: 'writer',
        canActivate: [AuthGuard],
        loadComponent: () =>
          import('./features/writer/pages/writer.page').then((m) => m.WriterPage),
      },
      {
        path: 'admin',
        canActivate: [AuthGuard, AdminGuard],
        loadComponent: () =>
          import('./features/admin/pages/admin-users.page').then((m) => m.AdminUsersPage),
      }
    ],
  },
  { path: '**', redirectTo: '' },
];