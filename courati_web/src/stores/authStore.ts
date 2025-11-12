import { create } from 'zustand';
import { authAPI } from '../api/auth';
import type { User } from '../types';

interface AuthState {
  user: User | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  error: string | null;
  
  // Actions
  login: (username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  setUser: (user: User) => void;
  clearError: () => void;
  initializeAuth: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  token: null,
  isAuthenticated: false,
  isLoading: false,
  error: null,

  login: async (username: string, password: string) => {
    set({ isLoading: true, error: null });
    try {
      const response = await authAPI.login(username, password);
      
      // Stocker les tokens et user dans localStorage
      localStorage.setItem('access_token', response.access);
      localStorage.setItem('refresh_token', response.refresh);
      localStorage.setItem('user', JSON.stringify(response.user));

      set({
        user: response.user,
        token: response.access,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      });
    } catch (error: any) {
      console.error('Login error:', error);
      console.error('Error response:', error.response);
      
      // Gérer différents formats d'erreur du backend
      let errorMessage = 'Identifiants incorrects';
      
      if (error.response?.data) {
        const data = error.response.data;
        // Essayer différents formats d'erreur
        errorMessage = data.message || 
                      data.detail || 
                      data.error ||
                      data.non_field_errors?.[0] ||
                      (typeof data === 'string' ? data : 'Identifiants incorrects');
      } else if (error.message) {
        errorMessage = error.message === 'Network Error' 
          ? 'Erreur de connexion au serveur' 
          : error.message;
      }
      
      set({
        user: null,
        token: null,
        isAuthenticated: false,
        isLoading: false,
        error: errorMessage,
      });
      throw error;
    }
  },

  logout: async () => {
    set({ isLoading: true });
    try {
      await authAPI.logout();
    } catch (error) {
      console.error('Logout error:', error);
    } finally {
      // Nettoyer le state et le localStorage
      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      localStorage.removeItem('user');
      
      set({
        user: null,
        token: null,
        isAuthenticated: false,
        isLoading: false,
        error: null,
      });
    }
  },

  setUser: (user: User) => {
    set({ user, isAuthenticated: true });
  },

  clearError: () => {
    set({ error: null });
  },

  initializeAuth: () => {
    const token = localStorage.getItem('access_token');
    const userStr = localStorage.getItem('user');
    
    if (token && userStr) {
      try {
        const user = JSON.parse(userStr);
        set({
          user,
          token,
          isAuthenticated: true,
        });
      } catch (error) {
        console.error('Failed to parse user from localStorage:', error);
        localStorage.removeItem('access_token');
        localStorage.removeItem('refresh_token');
        localStorage.removeItem('user');
      }
    }
  },
}));
