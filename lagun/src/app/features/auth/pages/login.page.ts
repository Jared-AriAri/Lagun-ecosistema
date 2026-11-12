import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-login-page',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './login.page.html',
})
export class LoginPage {
  private auth = inject(AuthService);
  private router = inject(Router);

  email = '';
  password = '';
  loading = false;
  errorMsg = '';

  async submit() {
    if (this.loading) return;
    this.errorMsg = '';
    this.loading = true;

    try {
      const data = await this.auth.signIn(this.email.trim(), this.password);
      await this.handlePostLogin(data);
    } catch (e: any) {
      this.errorMsg = e?.message ?? 'No se pudo iniciar sesión.';
    } finally {
      this.loading = false;
    }
  }

  async loginWithBiometrics() {
    if (this.loading) return;
    this.errorMsg = '';
    this.loading = true;

    try {
      const data = await this.auth.signInWithPasskey();
      await this.handlePostLogin(data);
    } catch (e: any) {
      this.errorMsg = 'El inicio de sesión biométrico falló o no está configurado.';
    } finally {
      this.loading = false;
    }
  }

  private async handlePostLogin(data: any) {
    if (data?.user?.email) {
      this.auth.notifyLogin(data.user.email);
    }

    await this.auth.refreshRole();
    const role = this.auth.roleSnapshot();

    const redirectUrl = localStorage.getItem('redirectUrl');
    localStorage.removeItem('redirectUrl');

    if (redirectUrl && !redirectUrl.includes('/login')) {
      await this.router.navigateByUrl(redirectUrl);
    } else {
      const target = (role === 'admin' || role === 'writer') ? '/admin' : '/';
      await this.router.navigate([target]);
    }
  }
}