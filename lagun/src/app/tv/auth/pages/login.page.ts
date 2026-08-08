import { Component, inject, OnInit, HostListener, ViewChild, ElementRef } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule, ActivatedRoute } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-login-page',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './login.page.html',
  styleUrl: './login.page.css'
})
export class LoginPage implements OnInit {
  @ViewChild('emailInput') emailInput!: ElementRef<HTMLInputElement>;
  @ViewChild('passwordInput') passwordInput!: ElementRef<HTMLInputElement>;
  @ViewChild('submitBtn') submitBtn!: ElementRef<HTMLButtonElement>;
  @ViewChild('registerBtn') registerBtn!: ElementRef<HTMLAnchorElement>;
  @ViewChild('backBtn') backBtn!: ElementRef<HTMLButtonElement>;

  private auth = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private location = inject(Location);

  email = '';
  password = '';
  loading = false;
  errorMsg = '';
  focusedInput: 'email' | 'password' | 'submit' | 'register' | 'back' = 'email';
  private returnUrl = '/tv';

  ngOnInit() {
    const queryReturnUrl = this.route.snapshot.queryParams['returnUrl'];
    const storedReturnUrl = localStorage.getItem('redirectUrl');

    if (queryReturnUrl) {
      this.returnUrl = queryReturnUrl;
    } else if (storedReturnUrl && !storedReturnUrl.includes('/login')) {
      this.returnUrl = storedReturnUrl;
    }

    setTimeout(() => {
      this.emailInput?.nativeElement.focus();
    }, 100);
  }

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

  private async handlePostLogin(data: any) {
    if (data?.user?.email) {
      this.auth.notifyLogin(data.user.email);
    }

    await this.auth.refreshRole();
    localStorage.removeItem('redirectUrl');

    await this.router.navigateByUrl(this.returnUrl);
  }

  goBack() {
    if (window.history.length > 1) {
      this.location.back();
    } else {
      this.router.navigateByUrl(this.returnUrl);
    }
  }

  @HostListener('window:keydown', ['$event'])
  handleKeyDown(event: KeyboardEvent) {
    if (event.key === 'Backspace' || event.key === 'Escape' || event.key === 'GoBack') {
      event.preventDefault();
      this.goBack();
      return;
    }

    if (event.key === 'ArrowDown') {
      event.preventDefault();
      if (this.focusedInput === 'email') {
        this.focusedInput = 'password';
        this.passwordInput?.nativeElement.focus();
      } else if (this.focusedInput === 'password') {
        this.focusedInput = 'submit';
        this.submitBtn?.nativeElement.focus();
      } else if (this.focusedInput === 'submit') {
        this.focusedInput = 'register';
        this.registerBtn?.nativeElement.focus();
      } else if (this.focusedInput === 'register') {
        this.focusedInput = 'back';
        this.backBtn?.nativeElement.focus();
      }
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      if (this.focusedInput === 'back') {
        this.focusedInput = 'register';
        this.registerBtn?.nativeElement.focus();
      } else if (this.focusedInput === 'register') {
        this.focusedInput = 'submit';
        this.submitBtn?.nativeElement.focus();
      } else if (this.focusedInput === 'submit') {
        this.focusedInput = 'password';
        this.passwordInput?.nativeElement.focus();
      } else if (this.focusedInput === 'password') {
        this.focusedInput = 'email';
        this.emailInput?.nativeElement.focus();
      }
    } else if (event.key === 'ArrowRight' && this.focusedInput === 'register') {
      event.preventDefault();
      this.focusedInput = 'back';
      this.backBtn?.nativeElement.focus();
    } else if (event.key === 'ArrowLeft' && this.focusedInput === 'back') {
      event.preventDefault();
      this.focusedInput = 'register';
      this.registerBtn?.nativeElement.focus();
    } else if (event.key === 'Enter') {
      if (this.focusedInput === 'submit') {
        event.preventDefault();
        this.submit();
      } else if (this.focusedInput === 'register') {
        event.preventDefault();
        this.router.navigate(['/tv/register'], { queryParams: { returnUrl: this.returnUrl } });
      } else if (this.focusedInput === 'back') {
        event.preventDefault();
        this.goBack();
      }
    }
  }
}