import apiClient from './client';
import type { Subject, CreateSubjectDTO } from '../types';

type UpdateSubjectData = Partial<CreateSubjectDTO>;

export const subjectsAPI = {
  // Liste des matières avec filtres
  getAll: async (params?: { search?: string; level?: string; major?: string }) => {
    try {
      console.log('🔍 Appel API subjects avec params:', params);
      const response = await apiClient.get('/api/courses/admin/subjects/', { params });
      console.log('✅ Réponse API subjects:', response.data);
      
      // Le backend renvoie { subjects: [...] }
      const data = response.data.subjects || response.data.results || response.data || [];
      console.log('📦 Données finales:', data);
      return data;
    } catch (error: any) {
      console.error('❌ Erreur API subjects:', error.response?.data || error.message);
      throw error;
    }
  },

  // Détails d'une matière
  getById: async (id: number): Promise<Subject> => {
    const response = await apiClient.get(`/api/courses/admin/subjects/${id}/`);
    return response.data;
  },

  // Créer une matière
  create: async (data: CreateSubjectDTO): Promise<Subject> => {
    const response = await apiClient.post('/api/courses/admin/subjects/', data);
    return response.data;
  },

  // Modifier une matière
  update: async (id: number, data: UpdateSubjectData): Promise<Subject> => {
    const response = await apiClient.put(`/api/courses/admin/subjects/${id}/`, data);
    return response.data;
  },

  // Supprimer une matière
  delete: async (id: number): Promise<void> => {
    await apiClient.delete(`/api/courses/admin/subjects/${id}/`);
  },

  // Assigner un enseignant
  assignTeacher: async (subjectId: number, teacherId: number) => {
    try {
      console.log(`📚 Assigner enseignant ${teacherId} à matière ${subjectId}`);
      const response = await apiClient.post(`/api/courses/admin/subjects/${subjectId}/assign-teacher/`, {
        teacher_id: teacherId,
      });
      console.log('✅ Enseignant assigné:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur assignation enseignant:', error.response?.data || error.message);
      console.error('URL:', `/api/courses/admin/subjects/${subjectId}/assign-teacher/`);
      console.error('Body:', { teacher_id: teacherId });
      throw error;
    }
  },

  // Retirer un enseignant
  removeTeacher: async (subjectId: number, teacherId: number) => {
    try {
      console.log(`🗑️ Retirer enseignant ${teacherId} de matière ${subjectId}`);
      const response = await apiClient.post(`/api/courses/admin/subjects/${subjectId}/remove-teacher/`, {
        teacher_id: teacherId,
      });
      console.log('✅ Enseignant retiré:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur retrait enseignant:', error.response?.data || error.message);
      throw error;
    }
  },
};
