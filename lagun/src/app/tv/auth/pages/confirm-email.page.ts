import { Component, OnInit, HostListener, ViewChild, ElementRef, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, ActivatedRoute, Router } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-confirm-email',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './confirm-email.page.html',
  styleUrl: './confirm-email.page.css'
})
export class ConfirmEmailPage implements OnInit {
  @ViewChild('resendBtn') resendBtn!: ElementRef<HTMLButtonElement>;
  @ViewChild('loginBtn') loginBtn!: ElementRef<HTMLAnchorElement>;

  private route = inject(ActivatedRoute);
  private router = inject(Router);
  private auth = inject(AuthService);

  email: string = '';
  loading: boolean = false;
  message: string = '';
  error: string = '';
  focusedInput: 'resend' | 'login' = 'resend';
  private returnUrl = '/tv';

  ngOnInit() {
    this.email = this.route.snapshot.queryParamMap.get('email') || 'tu correo';
    const queryReturnUrl = this.route.snapshot.queryParams['returnUrl'];

    if (queryReturnUrl) {
      this.returnUrl = queryReturnUrl;
    }

    setTimeout(() => {
      this.resendBtn?.nativeElement.focus();
    }, 100);
  }

  async resend() {
    if (!this.email || this.email === 'tu correo') {
      this.error = 'No se pudo detectar el correo para el reenvío.';
      return;
    }

    this.loading = true;
    this.message = '';
    this.error = '';

    try {
      await this.auth.resendConfirmationEmail(this.email);
      this.message = '¡Enviado! Revisa tu bandeja de entrada y spam.';
    } catch (e: any) {
      console.error('Error al reenviar:', e);
      this.error = e.message || 'Error al intentar reenviar el correo.';
    } finally {
      this.loading = false;
    }
  }

  @HostListener('window:keydown', ['$event'])
  handleKeyDown(event: KeyboardEvent) {
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      if (this.focusedInput === 'resend') {
        this.focusedInput = 'login';
        this.loginBtn?.nativeElement.focus();
      }
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      if (this.focusedInput === 'login') {
        this.focusedInput = 'resend';
        this.resendBtn?.nativeElement.focus();
      }
    } else if (event.key === 'Enter') {
      if (this.focusedInput === 'resend') {
        event.preventDefault();
        this.resend();
      } else if (this.focusedInput === 'login') {
        event.preventDefault();
        this.router.navigate(['/tv/login'], { queryParams: { returnUrl: this.returnUrl } });
      }
    }
  }
}