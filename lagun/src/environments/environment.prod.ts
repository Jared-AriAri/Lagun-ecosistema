export interface Environment {
  production: boolean;
  supabaseUrl: string;
  supabaseAnonKey: string;
}

export const environment = {
  production: false,
  supabaseUrl: 'TU_SUPABASE_URL_AQUI',
  supabaseAnonKey: 'TU_ANON_KEY_AQUI'
};