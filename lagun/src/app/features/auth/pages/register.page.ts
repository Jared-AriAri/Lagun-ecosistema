import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-register-page',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './register.page.html',
})
export class RegisterPage {
  fullName = '';
  email = '';
  password = '';
  loading = false;
  errorMsg = '';
  successMsg = '';

  constructor(private auth: AuthService, private router: Router) { }

  async submit() {
    this.errorMsg = '';
    this.successMsg = '';
    this.loading = true;

    try {
      const response = await this.auth.signUp(
        this.email.trim(),
        this.password,
        this.fullName.trim()
      );

      if (response.user && !response.session) {
        this.router.navigate(['/confirm-email'], {
          queryParams: { email: this.email.trim() }
        });
      } else {
        this.successMsg = '¡Cuenta creada con éxito!';
        this.router.navigate(['/login']);
      }
    } catch (e: any) {
      this.errorMsg = e?.message ?? 'No se pudo crear la cuenta.';
    } finally {
      this.loading = false;
    }
  }
}