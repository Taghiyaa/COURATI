import apiClient from './client';
import type { Student, CreateStudentDTO, UpdateStudentDTO } from '../types';

export const studentsAPI = {
  // ✅ Liste tous les étudiants
  // GET /api/auth/admin/students/
  getAll: async (params?: { search?: string; level_id?: number; major_id?: number; is_active?: boolean }) => {
    try {
      console.log('🔍 Appel API students avec params:', params);
      const response = await apiClient.get('/api/auth/admin/students/', { params });
      console.log('✅ Réponse API students:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur API students:', error.response?.data || error.message);
      throw error;
    }
  },

  // ✅ Détail d'un étudiant
  // GET /api/auth/admin/students/{user_id}/
  getById: async (userId: number): Promise<Student> => {
    try {
      console.log(`📖 Récupération étudiant ${userId}`);
      const response = await apiClient.get(`/api/auth/admin/students/${userId}/`);
      console.log('✅ Étudiant récupéré:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur récupération étudiant:', error.response?.data || error.message);
      throw error;
    }
  },

  // ✅ Créer un étudiant
  // POST /api/auth/admin/students/
  create: async (data: CreateStudentDTO): Promise<Student> => {
    try {
      console.log('➕ Création étudiant:', data);
      const response = await apiClient.post('/api/auth/admin/students/', data);
      console.log('✅ Étudiant créé:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur création étudiant:', error.response?.data || error.message);
      throw error;
    }
  },

  // ✅ Modifier un étudiant
  // PUT /api/auth/admin/students/{user_id}/
  update: async (userId: number, data: UpdateStudentDTO): Promise<Student> => {
    try {
      console.log(`✏️ Modification étudiant ${userId}:`, data);
      const response = await apiClient.put(`/api/auth/admin/students/${userId}/`, data);
      console.log('✅ Étudiant modifié:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur modification étudiant:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        throw new Error('Étudiant introuvable (déjà supprimé?)');
      }
      throw error;
    }
  },

  // ✅ Supprimer un étudiant
  // DELETE /api/auth/admin/students/{user_id}/
  delete: async (userId: number): Promise<void> => {
    try {
      console.log(`🗑️ Suppression étudiant ${userId}`);
      await apiClient.delete(`/api/auth/admin/students/${userId}/`);
      console.log('✅ Étudiant supprimé');
    } catch (error: any) {
      console.error('❌ Erreur suppression étudiant:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        throw new Error('Étudiant introuvable (déjà supprimé?)');
      }
      throw error;
    }
  },

  // ✅ Activer/Désactiver un étudiant
  // POST /api/auth/admin/students/{user_id}/toggle-active/
  toggleActive: async (userId: number): Promise<Student> => {
    try {
      console.log(`🔄 Toggle active étudiant ${userId}`);
      const response = await apiClient.post(`/api/auth/admin/students/${userId}/toggle-active/`);
      console.log('✅ Statut modifié:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur toggle active:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        throw new Error('Étudiant introuvable (déjà supprimé?)');
      }
      throw error;
    }
  },

  // ✅ Actions en masse
  // POST /api/auth/admin/students/bulk-action/
  bulkAction: async (action: 'activate' | 'deactivate' | 'delete', userIds: number[]) => {
    try {
      console.log(`📦 Action en masse: ${action} pour ${userIds.length} étudiants`);
      const response = await apiClient.post('/api/auth/admin/students/bulk-action/', {
        action,
        user_ids: userIds,
      });
      console.log('✅ Action en masse réussie:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur action en masse:', error.response?.data || error.message);
      throw error;
    }
  },

  // ✅ Export CSV
  // GET /api/auth/admin/students/export/
  exportCSV: async (params?: { level_id?: number; major_id?: number; is_active?: boolean }) => {
    try {
      console.log('📥 Export CSV avec params:', params);
      const response = await apiClient.get('/api/auth/admin/students/export/', {
        params,
        responseType: 'blob',
      });
      console.log('✅ Export CSV réussi');
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur export CSV:', error.response?.data || error.message);
      throw error;
    }
  },
};
