import apiClient from './client';

export type AdminDocumentsListParams = {
  page?: number;
  page_size?: number;
  subject?: number | string;
  teacher?: number | string;
  type?: string;
  is_active?: boolean;
  search?: string;
};

export const adminDocumentsAPI = {
  getAll: async (params: AdminDocumentsListParams = {}) => {
    const response = await apiClient.get('/api/courses/admin/documents/', { params });
    return response.data;
  },
  getById: async (id: number) => {
    const response = await apiClient.get(`/api/courses/admin/documents/${id}/`);
    return response.data.document || response.data;
  },
  update: async (id: number, data: Partial<{ title: string; description: string; document_type: string; is_active: boolean; is_premium: boolean }>) => {
    const response = await apiClient.patch(`/api/courses/admin/documents/${id}/`, data);
    return response.data.document || response.data;
  },
  delete: async (id: number) => {
    const response = await apiClient.delete(`/api/courses/admin/documents/${id}/`);
    return response.data;
  },
  toggleActive: async (id: number) => {
    const response = await apiClient.post(`/api/courses/admin/documents/${id}/toggle-active/`);
    return response.data.document || response.data;
  },
  bulkAction: async (payload: { action: 'activate' | 'deactivate' | 'delete'; document_ids: number[] }) => {
    const response = await apiClient.post('/api/courses/admin/documents/bulk-action/', payload);
    return response.data;
  },
  getBySubject: async (subjectId: number) => {
    const response = await apiClient.get(`/api/courses/admin/subjects/${subjectId}/documents/`);
    return response.data;
  }
};
