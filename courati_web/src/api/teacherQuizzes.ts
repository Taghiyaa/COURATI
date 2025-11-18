import apiClient from './client';

export const teacherQuizzesAPI = {
  getAll: async (params?: { subject?: number; is_active?: boolean; search?: string }) => {
    const response = await apiClient.get('/api/courses/teacher/quizzes/', { params });
    return response.data.quizzes || response.data;
  },
  getById: async (quizId: number) => {
    const response = await apiClient.get(`/api/courses/teacher/quizzes/${quizId}/`);
    return response.data.quiz || response.data;
  },
  getAttempts: async (quizId: number, params?: { status?: string; student?: number }) => {
    const response = await apiClient.get(`/api/courses/teacher/quizzes/${quizId}/attempts/`, { params });
    return response.data.attempts || response.data;
  },
  create: async (data: any) => {
    console.log('📝 Création quiz:', data);
    const response = await apiClient.post('/api/courses/teacher/quizzes/', data);
    console.log('✅ Quiz créé:', response.data);
    return response.data.quiz || response.data;
  },
  update: async (quizId: number, data: any) => {
    console.log(`✏️ Modification quiz ${quizId}:`, data);
    const response = await apiClient.patch(`/api/courses/teacher/quizzes/${quizId}/`, data);
    console.log('✅ Quiz modifié:', response.data);
    return response.data.quiz || response.data;
  },
  delete: async (quizId: number) => {
    console.log(`🗑️ Suppression quiz ${quizId}`);
    const response = await apiClient.delete(`/api/courses/teacher/quizzes/${quizId}/`);
    console.log('✅ Quiz supprimé:', response.data);
    return response.data;
  }
};

