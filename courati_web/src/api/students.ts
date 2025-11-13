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
  // GET /api/auth/admin/students/{student_id}/
  getById: async (studentId: number): Promise<Student> => {
    try {
      console.log(`📖 Récupération étudiant ${studentId}`);
      const response = await apiClient.get(`/api/auth/admin/students/${studentId}/`);
      console.log('✅ Réponse complète API:', response.data);
      
      // ✅ CORRECTION : Extraire 'student' de la réponse si présent
      const studentData = response.data.student || response.data;
      console.log('✅ Données étudiant extraites:', studentData);
      
      return studentData;
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
      
      // ✅ CORRECTION : Extraire 'student' de la réponse si présent
      return response.data.student || response.data;
    } catch (error: any) {
      console.error('❌ Erreur création étudiant:', error.response?.data || error.message);
      throw error;
    }
  },

  // ✅ Modifier un étudiant
  // PUT /api/auth/admin/students/{student_id}/
  update: async (studentId: number, data: UpdateStudentDTO): Promise<Student> => {
    try {
      console.log(`✏️ Modification étudiant ${studentId}:`, data);
      const response = await apiClient.put(`/api/auth/admin/students/${studentId}/`, data);
      console.log('✅ Étudiant modifié:', response.data);
      
      // ✅ CORRECTION : Extraire 'student' de la réponse si présent
      return response.data.student || response.data;
    } catch (error: any) {
      console.error('❌ Erreur modification étudiant:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        throw new Error('Étudiant introuvable (déjà supprimé?)');
      }
      throw error;
    }
  },

  // ✅ Supprimer un étudiant
  // DELETE /api/auth/admin/students/{student_id}/
  delete: async (studentId: number): Promise<void> => {
    try {
      console.log(`🗑️ Suppression étudiant ${studentId}`);
      await apiClient.delete(`/api/auth/admin/students/${studentId}/`);
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
  // POST /api/auth/admin/students/{student_id}/toggle-active/
  toggleActive: async (studentId: number): Promise<Student> => {
    try {
      console.log(`🔄 Toggle active étudiant ${studentId}`);
      const response = await apiClient.post(`/api/auth/admin/students/${studentId}/toggle-active/`);
      console.log('✅ Statut modifié:', response.data);
      
      // ✅ CORRECTION : Extraire 'student' de la réponse si présent
      return response.data.student || response.data;
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
  bulkAction: async (action: 'activate' | 'deactivate' | 'delete', studentIds: number[]) => {
    try {
      console.log(`📦 Action en masse ${action} pour ${studentIds.length} étudiants:`, studentIds);
      const response = await apiClient.post('/api/auth/admin/students/bulk-action/', {
        action,
        student_ids: studentIds,
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
      
      // Nettoyer les paramètres undefined
      const cleanParams = Object.fromEntries(
        Object.entries(params || {}).filter(([_, value]) => value !== undefined)
      );
      
      console.log('🧹 Paramètres nettoyés:', cleanParams);
      
      const response = await apiClient.get('/api/auth/admin/students/export/', {
        params: cleanParams,
        responseType: 'blob',
        headers: {
          'Accept': 'text/csv, application/csv, */*'
        }
      });
      
      console.log('✅ Export CSV réussi, taille:', response.data.size);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur export CSV:', {
        status: error.response?.status,
        statusText: error.response?.statusText,
        data: error.response?.data,
        message: error.message
      });
      throw error;
    }
  },
};