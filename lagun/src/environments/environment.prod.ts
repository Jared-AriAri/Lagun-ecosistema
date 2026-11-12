export interface Environment {
  production: boolean;
  supabaseUrl: string;
  supabaseAnonKey: string;
}

export const environment: Environment = {
  production: true,
  supabaseUrl: 'Tu_url',
  supabaseAnonKey: 'Tu_anonkey'
};