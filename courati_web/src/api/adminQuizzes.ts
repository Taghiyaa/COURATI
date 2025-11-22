import apiClient from './client';

export const adminQuizzesAPI = {
  // Liste avec filtres
  getAll: async (params?: {
    is_active?: boolean;
    subject?: number;
    search?: string;
  }) => {
    const response = await apiClient.get('/api/courses/admin/quizzes/', { params });
    return response.data;
  },

  // Détail d'un quiz
  getById: async (quizId: number) => {
    const response = await apiClient.get(`/api/courses/admin/quizzes/${quizId}/`);
    return response.data;
  },

  // Créer un quiz
  create: async (data: any) => {
    const response = await apiClient.post('/api/courses/admin/quizzes/', data);
    return response.data;
  },

  // Modifier un quiz
  update: async (quizId: number, data: any) => {
    const response = await apiClient.patch(`/api/courses/admin/quizzes/${quizId}/`, data);
    return response.data;
  },

  // Supprimer un quiz
  delete: async (quizId: number) => {
    const response = await apiClient.delete(`/api/courses/admin/quizzes/${quizId}/`);
    return response.data;
  },

  // Toggle actif/inactif
  toggleActive: async (quizId: number) => {
    const response = await apiClient.post(`/api/courses/admin/quizzes/${quizId}/toggle-active/`);
    return response.data;
  }
};
