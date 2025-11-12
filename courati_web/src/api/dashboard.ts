import apiClient from './client';
import type { DashboardStats } from '../types';

export const dashboardAPI = {
  getStats: async () => {
    const response = await apiClient.get('/api/auth/admin/dashboard/');
    // Le backend renvoie soit response.data.dashboard soit response.data directement
    return response.data.dashboard || response.data;
  },
};
