import apiClient from './client';
import type { Major } from '../types';

export interface CreateMajorDTO {
  code: string;
  name: string;
  description?: string;
}

export type UpdateMajorDTO = Partial<CreateMajorDTO>;

export const majorsAPI = {
  getAll: async () => {
    const response = await apiClient.get('/api/auth/admin/majors/');
    return response.data.results || response.data || [];
  },
  
  getById: async (id: number): Promise<Major> => {
    const response = await apiClient.get(`/api/auth/admin/majors/${id}/`);
    return response.data;
  },
  
  create: async (data: CreateMajorDTO): Promise<Major> => {
    const response = await apiClient.post('/api/auth/admin/majors/', data);
    return response.data;
  },
  
  update: async (id: number, data: UpdateMajorDTO): Promise<Major> => {
    const response = await apiClient.put(`/api/auth/admin/majors/${id}/`, data);
    return response.data;
  },
  
  delete: async (id: number): Promise<void> => {
    await apiClient.delete(`/api/auth/admin/majors/${id}/`);
  },
};
