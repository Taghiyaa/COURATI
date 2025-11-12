import apiClient from './client';
import type { Level } from '../types';

export interface CreateLevelDTO {
  code: string;
  name: string;
  description?: string;
  order: number;
}

export type UpdateLevelDTO = Partial<CreateLevelDTO>;

export const levelsAPI = {
  getAll: async () => {
    const response = await apiClient.get('/api/auth/admin/levels/');
    return response.data.results || response.data || [];
  },
  
  getById: async (id: number): Promise<Level> => {
    const response = await apiClient.get(`/api/auth/admin/levels/${id}/`);
    return response.data;
  },
  
  create: async (data: CreateLevelDTO): Promise<Level> => {
    const response = await apiClient.post('/api/auth/admin/levels/', data);
    return response.data;
  },
  
  update: async (id: number, data: UpdateLevelDTO): Promise<Level> => {
    const response = await apiClient.put(`/api/auth/admin/levels/${id}/`, data);
    return response.data;
  },
  
  delete: async (id: number): Promise<void> => {
    await apiClient.delete(`/api/auth/admin/levels/${id}/`);
  },
};
