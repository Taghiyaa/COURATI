import apiClient from './client';
import type { LoginResponse, User } from '../types';

export const authAPI = {
  login: async (username: string, password: string): Promise<LoginResponse> => {
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
      // Nettoyer le localStorage même si la requête échoue
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      localStorage.removeItem('user');
    }
  },

  getProfile: async (): Promise<User> => {
    const response = await apiClient.get<User>('/api/auth/profile/');
    return response.data;
  },

  refreshToken: async (refreshToken: string): Promise<{ access: string }> => {
    const response = await apiClient.post<{ access: string }>('/api/auth/token/refresh/', {
      refresh: refreshToken,
    });
    return response.data;
  },
};
