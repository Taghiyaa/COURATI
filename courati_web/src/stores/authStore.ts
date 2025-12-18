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

      // ✅ Mettre à jour le state AVANT de résoudre la promesse
      set({
        user: response.user,
        token: response.access,
        isAuthenticated: true,
        isLoading: false,
        error: null,
      });

      // ✅ La promesse se résout avec succès
    } catch (error: any) {
      console.error('❌ Login error:', error);
      console.error('❌ Error response:', error.response);
      console.error('❌ Error response data:', error.response?.data);
      
      // ✅ CORRECTION : Gérer le format Django avec non_field_errors
      let errorMessage = 'Identifiants incorrects';
      
      if (error.response?.data) {
        const data = error.response.data;
        console.log('📦 Data reçue du backend:', data);
        
        // ✅ PRIORITÉ 1: non_field_errors (format Django standard)
        if (data.non_field_errors && Array.isArray(data.non_field_errors)) {
          errorMessage = data.non_field_errors[0];
        }
        // Autres formats d'erreur possibles
        else if (data.detail) {
          errorMessage = data.detail;
        }
        else if (data.message) {
          errorMessage = data.message;
        }
        else if (data.error) {
          errorMessage = data.error;
        }
        else if (typeof data === 'string') {
          errorMessage = data;
        }
      } else if (error.message) {
        errorMessage = error.message === 'Network Error' 
          ? 'Erreur de connexion au serveur' 
          : error.message;
      }
      
      console.log('💬 Message d\'erreur final:', errorMessage);
      
      // ✅ Mettre à jour le state avec l'erreur
      set({
        user: null,
        token: null,
        isAuthenticated: false,
        isLoading: false,
        error: errorMessage,
      });
      
      // ✅ IMPORTANT : Rejeter la promesse pour que le composant puisse catch l'erreur
      throw new Error(errorMessage);
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