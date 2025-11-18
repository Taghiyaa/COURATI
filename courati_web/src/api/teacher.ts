import apiClient from './client';

export const teacherAPI = {
  getDashboard: async () => {
    console.log('📊 Appel API dashboard professeur');
    const response = await apiClient.get('/api/courses/teacher/dashboard/');
    console.log('✅ Réponse API dashboard:', response.data);
    // Retourner strictement le champ dashboard
    return response.data.dashboard;
  },
  getMySubjects: async () => {
    const response = await apiClient.get('/api/courses/teacher/my-subjects/');
    return response.data.subjects || response.data;
  },
  getSubjectDetail: async (subjectId: number) => {
    const response = await apiClient.get(`/api/courses/teacher/subjects/${subjectId}/`);
    return response.data.subject || response.data;
  },
  getSubjectStatistics: async (subjectId: number) => {
    const response = await apiClient.get(`/api/courses/teacher/subjects/${subjectId}/statistics/`);
    return response.data.statistics || response.data;
  },
  getSubjectStudents: async (subjectId: number) => {
    const response = await apiClient.get(`/api/courses/teacher/subjects/${subjectId}/students/`);
    return response.data.students || response.data;
  },
  updateSubject: async (subjectId: number, data: any) => {
    const response = await apiClient.patch(`/api/courses/teacher/subjects/${subjectId}/update/`, data);
    return response.data.subject || response.data;
  },
  // ✅ Récupérer les documents d'une matière (enseignant)
  getSubjectDocuments: async (subjectId: number, params?: { type?: string; search?: string }) => {
    console.log(`📄 Récupération documents matière ${subjectId}`, params);
    const response = await apiClient.get(`/api/courses/teacher/subjects/${subjectId}/documents/`, { params });
    console.log('✅ Documents récupérés:', response.data);
    return response.data; // { success, documents, count }
  },
};

