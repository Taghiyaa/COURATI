import apiClient from './client';
import type { DashboardData } from '../types';

export const dashboardAPI = {
  getStats: async (): Promise<DashboardData> => {
    const response = await apiClient.get<{ success: boolean; dashboard: DashboardData }>('/api/auth/admin/dashboard/');
    // Le backend renvoie { success: true, dashboard: {...} }
    // On retourne directement l'objet dashboard
    if (response.data && 'dashboard' in response.data && response.data.dashboard) {
      return response.data.dashboard;
    }
    // Fallback si la structure est différente (directement DashboardData)
    if (response.data && 'stats' in response.data) {
      return response.data as unknown as DashboardData;
    }
    throw new Error('Format de réponse invalide de l\'API dashboard');
  },
};
