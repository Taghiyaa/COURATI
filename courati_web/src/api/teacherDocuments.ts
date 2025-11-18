import apiClient from './client';
import type { AxiosProgressEvent } from 'axios';

export const teacherDocumentsAPI = {
  getForSubject: async (subjectId: number, params?: { search?: string; type?: string }) => {
    const response = await apiClient.get(`/api/courses/subjects/${subjectId}/documents/`, { params });
    return response.data.documents || response.data;
  },
  upload: async (subjectId: number, formData: FormData, onProgress?: (progress: number) => void) => {
    const response = await apiClient.post(
      `/api/courses/teacher/subjects/${subjectId}/upload/`,
      formData,
      {
        headers: { 'Content-Type': 'multipart/form-data' },
        onUploadProgress: (progressEvent: AxiosProgressEvent) => {
          if (progressEvent.total) {
            const percentCompleted = Math.round(((progressEvent.loaded || 0) * 100) / progressEvent.total);
            onProgress?.(percentCompleted);
          }
        }
      }
    );
    return (response.data && (response.data.document || response.data)) as any;
  },
  update: async (documentId: number, data: any) => {
    const response = await apiClient.patch(`/api/courses/teacher/documents/${documentId}/update/`, data);
    return response.data.document || response.data;
  },
  delete: async (documentId: number) => {
    await apiClient.delete(`/api/courses/teacher/documents/${documentId}/delete/`);
  }
};
