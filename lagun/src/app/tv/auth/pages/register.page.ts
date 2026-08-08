import { Component, inject, OnInit, HostListener, ViewChild, ElementRef } from '@angular/core';
import { CommonModule, Location } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterModule, ActivatedRoute } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-register-page',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterModule],
  templateUrl: './register.page.html',
  styleUrl: './register.page.css'
})
export class RegisterPage implements OnInit {
  @ViewChild('nameInput') nameInput!: ElementRef<HTMLInputElement>;
  @ViewChild('emailInput') emailInput!: ElementRef<HTMLInputElement>;
  @ViewChild('passwordInput') passwordInput!: ElementRef<HTMLInputElement>;
  @ViewChild('submitBtn') submitBtn!: ElementRef<HTMLButtonElement>;
  @ViewChild('loginBtn') loginBtn!: ElementRef<HTMLAnchorElement>;
  @ViewChild('backBtn') backBtn!: ElementRef<HTMLButtonElement>;

  private auth = inject(AuthService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);
  private location = inject(Location);

  fullName = '';
  email = '';
  password = '';
  loading = false;
  errorMsg = '';
  successMsg = '';
  focusedInput: 'name' | 'email' | 'password' | 'submit' | 'login' | 'back' = 'name';
  private returnUrl = '/tv';

  ngOnInit() {
    const queryReturnUrl = this.route.snapshot.queryParams['returnUrl'];
    const storedReturnUrl = localStorage.getItem('redirectUrl');

    if (queryReturnUrl) {
      this.returnUrl = queryReturnUrl;
    } else if (storedReturnUrl && !storedReturnUrl.includes('/register')) {
      this.returnUrl = storedReturnUrl;
    }

    setTimeout(() => {
      this.nameInput?.nativeElement.focus();
    }, 100);
  }

  async submit() {
    if (this.loading) return;
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
        this.router.navigate(['/tv/confirm-email'], {
          queryParams: { email: this.email.trim(), returnUrl: this.returnUrl }
        });
      } else {
        this.successMsg = '¡Cuenta creada con éxito!';
        this.router.navigate(['/tv/login'], { queryParams: { returnUrl: this.returnUrl } });
      }
    } catch (e: any) {
      this.errorMsg = e?.message ?? 'No se pudo crear la cuenta.';
    } finally {
      this.loading = false;
    }
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
      if (this.focusedInput === 'name') {
        this.focusedInput = 'email';
        this.emailInput?.nativeElement.focus();
      } else if (this.focusedInput === 'email') {
        this.focusedInput = 'password';
        this.passwordInput?.nativeElement.focus();
      } else if (this.focusedInput === 'password') {
        this.focusedInput = 'submit';
        this.submitBtn?.nativeElement.focus();
      } else if (this.focusedInput === 'submit') {
        this.focusedInput = 'login';
        this.loginBtn?.nativeElement.focus();
      } else if (this.focusedInput === 'login') {
        this.focusedInput = 'back';
        this.backBtn?.nativeElement.focus();
      }
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      if (this.focusedInput === 'back') {
        this.focusedInput = 'login';
        this.loginBtn?.nativeElement.focus();
      } else if (this.focusedInput === 'login') {
        this.focusedInput = 'submit';
        this.submitBtn?.nativeElement.focus();
      } else if (this.focusedInput === 'submit') {
        this.focusedInput = 'password';
        this.passwordInput?.nativeElement.focus();
      } else if (this.focusedInput === 'password') {
        this.focusedInput = 'email';
        this.emailInput?.nativeElement.focus();
      } else if (this.focusedInput === 'email') {
        this.focusedInput = 'name';
        this.nameInput?.nativeElement.focus();
      }
    } else if (event.key === 'ArrowRight' && this.focusedInput === 'login') {
      event.preventDefault();
      this.focusedInput = 'back';
      this.backBtn?.nativeElement.focus();
    } else if (event.key === 'ArrowLeft' && this.focusedInput === 'back') {
      event.preventDefault();
      this.focusedInput = 'login';
      this.loginBtn?.nativeElement.focus();
    } else if (event.key === 'Enter') {
      if (this.focusedInput === 'submit') {
        event.preventDefault();
        this.submit();
      } else if (this.focusedInput === 'login') {
        event.preventDefault();
        this.router.navigate(['/tv/login'], { queryParams: { returnUrl: this.returnUrl } });
      } else if (this.focusedInput === 'back') {
        event.preventDefault();
        this.goBack();
      }
    }
  }
}