import apiClient from './client';
import type { Teacher } from '../types';

export interface CreateTeacherDTO {
  username: string;
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  phone?: string;
  specialization?: string;
}

export interface UpdateTeacherDTO {
  email?: string;
  first_name?: string;
  last_name?: string;
  phone?: string;
  specialization?: string;
  is_active?: boolean;
}

export interface AssignmentPermissions {
  can_edit_content?: boolean;
  can_upload_documents?: boolean;
  can_delete_documents?: boolean;
  can_manage_students?: boolean;
  notes?: string;
}

export const teachersAPI = {
  // ✅ Liste tous les enseignants
  // GET /api/auth/admin/teachers/
  getAll: async (params?: { search?: string; is_active?: boolean }) => {
    try {
      console.log('🔍 Appel API teachers avec params:', params);
      const response = await apiClient.get('/api/auth/admin/teachers/', { params });
      console.log('✅ Réponse API teachers:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur API teachers:', error.response?.data || error.message);
      throw error;
    }
  },

  // ✅ Détail d'un enseignant
  // GET /api/auth/admin/teachers/{pk}/
  getById: async (teacherId: number): Promise<Teacher> => {
    try {
      console.log(`📖 Récupération enseignant ${teacherId}`);
      const response = await apiClient.get(`/api/auth/admin/teachers/${teacherId}/`);
      console.log('✅ Enseignant récupéré:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur récupération enseignant:', error.response?.data || error.message);
      throw error;
    }
  },

  // ✅ Créer un enseignant
  // POST /api/auth/admin/teachers/
  create: async (data: CreateTeacherDTO): Promise<Teacher> => {
    try {
      console.log('➕ Création enseignant:', data);
      const response = await apiClient.post('/api/auth/admin/teachers/', data);
      console.log('✅ Enseignant créé:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur création enseignant:', error.response?.data || error.message);
      throw error;
    }
  },

  // ✅ Modifier un enseignant
  // PUT /api/auth/admin/teachers/{pk}/
  update: async (teacherId: number, data: UpdateTeacherDTO): Promise<Teacher> => {
    try {
      console.log(`✏️ Modification enseignant ${teacherId}:`, data);
      const response = await apiClient.put(`/api/auth/admin/teachers/${teacherId}/`, data);
      console.log('✅ Enseignant modifié:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur modification enseignant:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        throw new Error('Enseignant introuvable (déjà supprimé?)');
      }
      throw error;
    }
  },

  // ✅ Supprimer un enseignant
  // DELETE /api/auth/admin/teachers/{pk}/
  delete: async (teacherId: number): Promise<void> => {
    try {
      console.log(`🗑️ Suppression enseignant ${teacherId}`);
      await apiClient.delete(`/api/auth/admin/teachers/${teacherId}/`);
      console.log('✅ Enseignant supprimé');
    } catch (error: any) {
      console.error('❌ Erreur suppression enseignant:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        throw new Error('Enseignant introuvable (déjà supprimé?)');
      }
      throw error;
    }
  },

  // ✅ Activer/Désactiver un enseignant
  // POST /api/auth/admin/teachers/{teacher_id}/toggle-active/
  toggleActive: async (teacherId: number): Promise<Teacher> => {
    try {
      console.log(`🔄 Toggle active enseignant ${teacherId}`);
      const response = await apiClient.post(`/api/auth/admin/teachers/${teacherId}/toggle-active/`);
      console.log('✅ Statut modifié:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur toggle active:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        throw new Error('Enseignant introuvable (déjà supprimé?)');
      }
      throw error;
    }
  },

  // ✅ Liste des assignations d'un enseignant
  // GET /api/auth/admin/teachers/{teacher_id}/assignments/
  getAssignments: async (teacherId: number) => {
    try {
      console.log(`📚 Récupération assignations enseignant ${teacherId}`);
      const response = await apiClient.get(`/api/auth/admin/teachers/${teacherId}/assignments/`);
      console.log('✅ Assignations récupérées:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur récupération assignations:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        console.warn('⚠️ Endpoint assignments non trouvé, retour tableau vide');
        return [];
      }
      throw error;
    }
  },

  // ✅ Créer une assignation pour un enseignant
  // POST /api/auth/admin/teachers/{teacher_id}/assignments/
  createAssignment: async (teacherId: number, data: AssignmentPermissions & { subject_id: number }) => {
    try {
      console.log(`📚 Créer assignation pour enseignant ${teacherId}:`, data);
      const response = await apiClient.post(`/api/auth/admin/teachers/${teacherId}/assignments/`, {
        subject_id: data.subject_id,
        can_edit_content: data.can_edit_content ?? true,
        can_upload_documents: data.can_upload_documents ?? true,
        can_delete_documents: data.can_delete_documents ?? true,
        can_manage_students: data.can_manage_students ?? false,
        notes: data.notes || '',
      });
      console.log('✅ Assignation créée:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur création assignation:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        throw new Error('Enseignant ou matière introuvable');
      }
      throw error;
    }
  },

  // ✅ Modifier une assignation
  // PUT /api/auth/admin/assignments/{assignment_id}/
  updateAssignment: async (assignmentId: number, data: Partial<AssignmentPermissions>) => {
    try {
      console.log(`✏️ Modification assignation ${assignmentId}:`, data);
      const response = await apiClient.put(`/api/auth/admin/assignments/${assignmentId}/`, data);
      console.log('✅ Assignation modifiée:', response.data);
      return response.data;
    } catch (error: any) {
      console.error('❌ Erreur modification assignation:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        throw new Error('Assignation introuvable');
      }
      throw error;
    }
  },

  // ✅ Supprimer une assignation
  // DELETE /api/auth/admin/assignments/{assignment_id}/
  deleteAssignment: async (assignmentId: number) => {
    try {
      console.log(`🗑️ Suppression assignation ${assignmentId}`);
      await apiClient.delete(`/api/auth/admin/assignments/${assignmentId}/`);
      console.log('✅ Assignation supprimée');
    } catch (error: any) {
      console.error('❌ Erreur suppression assignation:', error.response?.data || error.message);
      if (error.response?.status === 404) {
        throw new Error('Assignation introuvable (déjà supprimée?)');
      }
      throw error;
    }
  },
};
