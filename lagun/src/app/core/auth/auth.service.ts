import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';
import type {
  AuthChangeEvent,
  Session,
  User,
} from '@supabase/supabase-js';
import { SupabaseService } from '../../services/supabase.service';

export type AppRole = 'reader' | 'writer' | 'admin';

export type Profile = {
  id: string;
  full_name: string | null;
  avatar_url: string | null;
  bio: string | null;
  is_active: boolean;
  role: AppRole;
};

@Injectable({ providedIn: 'root' })
export class AuthService {
  private session$ = new BehaviorSubject<Session | null>(null);
  private role$ = new BehaviorSubject<AppRole>('reader');
  private profile$ = new BehaviorSubject<Profile | null>(null);
  private ready$ = new BehaviorSubject<boolean>(false);
  private initialized = false;

  constructor(private supa: SupabaseService) { }

  async init() {
    if (this.initialized) return;
    this.initialized = true;
    this.ready$.next(false);

    const { data, error } = await this.supa.supabase.auth.getSession();

    if (error) {
      this.session$.next(null);
      this.role$.next('reader');
      this.profile$.next(null);
      this.ready$.next(true);
      return;
    }

    const session = data.session;
    this.session$.next(session);
    await this.refreshFromSession(session);

    this.supa.supabase.auth.onAuthStateChange(
      async (_event: AuthChangeEvent, newSession: Session | null) => {
        this.session$.next(newSession);
        await this.refreshFromSession(newSession);
        this.ready$.next(true);
      }
    );

    this.ready$.next(true);
  }

  sessionSnapshot(): Session | null {
    return this.session$.value;
  }

  isLoggedInSnapshot(): boolean {
    return !!this.session$.value?.user?.id;
  }

  async isLoggedIn(): Promise<boolean> {
    const { data, error } = await this.supa.supabase.auth.getSession();
    if (error) return false;
    return !!data.session?.user?.id;
  }

  roleSnapshot(): AppRole {
    return this.role$.value;
  }

  profileSnapshot(): Profile | null {
    return this.profile$.value;
  }

  isReadySnapshot(): boolean {
    return this.ready$.value;
  }

  sessionChanges() {
    return this.session$.asObservable();
  }

  roleChanges() {
    return this.role$.asObservable();
  }

  profileChanges() {
    return this.profile$.asObservable();
  }

  readyChanges() {
    return this.ready$.asObservable();
  }

  async currentUser(): Promise<User | null> {
    const { data, error } = await this.supa.supabase.auth.getUser();
    if (error) return null;
    return data.user;
  }

  async signIn(email: string, password: string) {
    const { data, error } = await this.supa.supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      throw new Error(this.mapAuthError(error.message));
    }

    const { data: userData, error: userError } =
      await this.supa.supabase.auth.getUser();

    if (userError || !userData.user) {
      throw new Error('No se pudo validar la sesión.');
    }

    if (!userData.user.email_confirmed_at) {
      await this.supa.supabase.auth.signOut();
      throw new Error('Debes confirmar tu correo antes de iniciar sesión.');
    }

    this.session$.next(data.session ?? null);
    await this.refreshFromSession(data.session ?? null);
    return data;
  }

  async signInWithPasskey() {
    const { data, error } = await (this.supa.supabase.auth as any).signInWithPasskey();

    if (error) {
      throw new Error(this.mapAuthError(error.message));
    }

    this.session$.next(data.session ?? null);
    await this.refreshFromSession(data.session ?? null);
    return data;
  }

  async notifyLogin(email: string) {
    try {
      await this.supa.supabase.functions.invoke('send-login-notification', {
        body: { email }
      });
    } catch (e) {
      console.warn('Error enviando notificación de login:', e);
    }
  }

  async signUp(email: string, password: string, fullName: string) {
    const { data, error } = await this.supa.supabase.auth.signUp({
      email,
      password,
      options: {
        emailRedirectTo: 'https://lagun.vercel.app/login',
        data: {
          full_name: fullName,
        },
      },
    });

    if (error) {
      throw new Error(this.mapAuthError(error.message));
    }

    return data;
  }

  async signOut() {
    try {
      await this.supa.supabase.auth.signOut();
    } catch (e) {
      console.warn('Logout failed on server', e);
    } finally {
      this.session$.next(null);
      this.role$.next('reader');
      this.profile$.next(null);
    }
  }

  async refreshRole(): Promise<Profile | null> {
    // Simplificado: usamos la sesión que ya tenemos en memoria
    return await this.refreshFromSession(this.session$.value);
  }

  async resendConfirmationEmail(email: string) {
    const { error } = await this.supa.supabase.auth.resend({
      type: 'signup',
      email,
    });

    if (error) {
      throw new Error(error.message || 'Error al reenviar el correo.');
    }
  }

  public async refreshFromSession(session: Session | null): Promise<Profile | null> {
    const uid = session?.user?.id ?? null;
    if (!uid) {
      this.role$.next('reader');
      this.profile$.next(null);
      return null;
    }

    const { data, error } = await this.supa.supabase
      .from('profiles')
      .select('id, full_name, avatar_url, bio, is_active, role')
      .eq('id', uid)
      .maybeSingle();

    if (error || !data) {
      this.role$.next('reader');
      this.profile$.next(null);
      return null;
    }

    const profile = (data as unknown) as Profile;

    // Aquí está el truco: emitimos los nuevos valores a los BehaviorSubjects
    this.profile$.next(profile);
    this.role$.next(profile.role ?? 'reader');

    return profile;
  }

  private mapAuthError(message: string): string {
    const msg = (message || '').toLowerCase();
    if (msg.includes('email not confirmed')) return 'Confirma tu correo.';
    if (msg.includes('invalid login credentials') || msg.includes('invalid credentials')) return 'Correo o contraseña incorrectos.';
    if (msg.includes('user already registered') || msg.includes('already registered')) return 'Ese correo ya está registrado.';
    return message || 'Ocurrió un error de autenticación.';
  }
}