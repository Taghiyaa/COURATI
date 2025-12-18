import apiClient from './client';
import type { LoginResponse, User } from '../types';

export const authAPI = {
  login: async (username: string, password: string): Promise<LoginResponse> => {
    // ✅ NE PAS utiliser try-catch ici, laisser l'erreur remonter
    const response = await apiClient.post<LoginResponse>('/api/auth/login/', {
      username,
      password,
    });
    return response.data;
  },

  logout: async (): Promise<void> => {
    try {
      await apiClient.post('/api/auth/logout/');
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      localStorage.removeItem('user');
    }
  },

  getProfile: async (): Promise<User> => {
    const response = await apiClient.get<any>('/api/auth/web/profile/');
    const u = response.data?.profile?.user || response.data;

    const user: User = {
      id: Number(u.id),
      username: String(u.username || ''),
      email: String(u.email || ''),
      first_name: String(u.first_name || ''),
      last_name: String(u.last_name || ''),
      role: (u.role as 'ADMIN' | 'TEACHER' | 'STUDENT') || 'ADMIN',
      is_active: Boolean(u.is_active ?? true),
      date_joined: String(u.date_joined || new Date().toISOString()),
    };

    return user;
  },

  refreshToken: async (refreshToken: string): Promise<{ access: string }> => {
    const response = await apiClient.post<{ access: string }>(
      '/api/auth/token/refresh/',
      { refresh: refreshToken }
    );
    return response.data;
  },
};