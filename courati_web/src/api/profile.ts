import apiClient from './client';

export interface UserData {
  id: number;
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  role: 'ADMIN' | 'TEACHER';
  role_display: string;
  date_joined: string;
}

export interface AdminProfileData {
  user: UserData;
  phone_number: string;
  department: string;
  created_at: string;
  updated_at: string;
}

export interface TeacherProfileData {
  user: UserData;
  phone_number: string;
  specialization: string;
  bio: string;
  office: string;
  office_hours: string;
  assigned_subjects_count: number;
  created_at: string;
  updated_at: string;
}

export type ProfileData = AdminProfileData | TeacherProfileData;

export interface ProfileResponse {
  success: boolean;
  profile: ProfileData;
}

export interface UpdateProfilePayload {
  first_name?: string;
  last_name?: string;
  phone_number?: string;
  department?: string;
  specialization?: string;
  bio?: string;
  office?: string;
  office_hours?: string;
}

export interface ChangePasswordPayload {
  old_password: string;
  new_password: string;
  confirm_password: string;
}

export interface StatsData {
  documents_count: number;
  quizzes_count: number;
  subjects_count: number;
  total_views: number;
  total_downloads: number;
}

export interface StatsResponse {
  success: boolean;
  stats: StatsData;
}

export const profileAPI = {
  getProfile: async (): Promise<ProfileResponse> => {
    const response = await apiClient.get('/api/auth/web/profile/');
    return response.data;
  },

  updateProfile: async (data: UpdateProfilePayload) => {
    const response = await apiClient.patch('/api/auth/web/profile/', data);
    return response.data;
  },

  changePassword: async (data: ChangePasswordPayload) => {
    const response = await apiClient.post('/api/auth/web/profile/change-password/', data);
    return response.data;
  },

  getStats: async (): Promise<StatsResponse> => {
    const response = await apiClient.get('/api/auth/web/profile/stats/');
    return response.data;
  },
};
