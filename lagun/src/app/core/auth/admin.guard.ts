import { inject } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from './auth.service';

export const AdminGuard = () => {
  const auth = inject(AuthService);
  const router = inject(Router);

  if (auth.roleSnapshot() === 'admin') {
    return true;
  }

  router.navigate(['/']);
  return false;
};