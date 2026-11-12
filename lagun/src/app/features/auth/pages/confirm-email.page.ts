import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, ActivatedRoute } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-confirm-email',
  standalone: true,
  imports: [CommonModule, RouterModule],
  templateUrl: './confirm-email.page.html'
})
export class ConfirmEmailPage implements OnInit {
  email: string = '';
  loading: boolean = false;
  message: string = '';
  error: string = '';

  constructor(
    private route: ActivatedRoute,
    private auth: AuthService
  ) { }

  ngOnInit() {
    this.email = this.route.snapshot.queryParamMap.get('email') || 'tu correo';
    if (this.email !== 'tu correo') {
      console.log('Esperando confirmación para:', this.email);
    }
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
}