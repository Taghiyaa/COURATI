// User types
export interface User {
  id: number;
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  role: 'ADMIN' | 'TEACHER' | 'STUDENT';
  is_active: boolean;
  date_joined: string;
}

export interface LoginResponse {
  access: string;
  refresh: string;
  user: User;
}

// Level and Major types
export interface Level {
  id: number;
  name: string;
  code: string;
  order: number;
  is_active: boolean;
}

export interface Major {
  id: number;
  name: string;
  code: string;
  description?: string;
  is_active: boolean;
}

// Subject types
export interface Subject {
  id: number;
  code: string;
  name: string;
  description?: string;
  levels: Level[];
  majors: Major[];
  credits: number;
  semester: number;
  order: number;
  icon?: string;
  color?: string;
  is_active: boolean;
  is_featured: boolean;
  total_documents: number;
  total_quizzes: number;
  view_count: number;
  download_count: number;
  created_at: string;
  updated_at: string;
}

export interface CreateSubjectDTO {
  code: string;
  name: string;
  description?: string;
  levels: number[];
  majors: number[];
  credits: number;
  semester: number;
  order?: number;
  icon?: string;
  color?: string;
  is_active?: boolean;
  is_featured?: boolean;
}

export interface SubjectFilters {
  is_active?: boolean;
  is_featured?: boolean;
  level?: number;
  major?: number;
  search?: string;
}

export interface SubjectStatistics {
  total_documents: number;
  total_quizzes: number;
  total_views: number;
  total_downloads: number;
  total_students: number;
  total_teachers: number;
  average_quiz_score: number;
  documents_by_type: Record<string, number>;
  activity_last_30_days: Array<{ date: string; views: number; downloads: number }>;
}

// Teacher types
export interface Teacher {
  id: number;              // ID du TeacherProfile
  user_id: number;         // ✅ ID du User (à utiliser pour les routes API)
  username?: string;
  email?: string;
  first_name?: string;
  last_name?: string;
  full_name?: string;
  phone?: string;
  phone_number?: string;
  specialization?: string;
  bio?: string;
  office?: string;
  office_hours?: string;
  is_active?: boolean;
  total_subjects?: number;
  total_assignments?: number;
  active_assignments?: number;
  subjects?: Subject[];
  assignments?: any[];
  created_at?: string;
  updated_at?: string;
  // Format backend avec user imbriqué
  user?: {
    id: number;
    username: string;
    email: string;
    first_name: string;
    last_name: string;
    is_active: boolean;
    role: string;
  };
}

export interface TeacherProfile {
  id: number;
  user: User;
  phone_number: string;
  photo?: string;
  total_assignments: number;
  active_assignments: number;
  subjects: Subject[];
}

export interface TeacherAssignment {
  id: number;
  subject: {
    id: number;
    name: string;
    code: string;
  };
  can_edit_content: boolean;
  can_upload_documents: boolean;
  can_delete_documents: boolean;
  can_manage_students: boolean;
  notes?: string;
  is_active: boolean;
  assigned_at: string;
}

export interface CreateTeacherDTO {
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  password: string;
  phone_number?: string;
  is_active?: boolean;
}

// Student types
export interface Student {
  id: number;              // ID du StudentProfile
  user_id: number;         // ✅ ID du User (à utiliser pour les routes API)
  username?: string;
  email?: string;
  first_name?: string;
  last_name?: string;
  full_name?: string;
  phone?: string;
  phone_number?: string;
  photo?: string;
  date_of_birth?: string;
  address?: string;
  is_active?: boolean;
  enrollment_date?: string;
  created_at?: string;
  updated_at?: string;
  // Relations
  level?: Level;
  level_id?: number;
  major?: Major;
  major_id?: number;
  // Format backend avec user imbriqué
  user?: {
    id: number;
    username: string;
    email: string;
    first_name: string;
    last_name: string;
    is_active: boolean;
    role: string;
  };
}

export interface CreateStudentDTO {
  username: string;
  email: string;
  password: string;
  first_name: string;
  last_name: string;
  phone_number?: string;
  date_of_birth?: string;
  address?: string;
  level_id?: number;
  major_id?: number;
}

export interface UpdateStudentDTO {
  username?: string;
  email?: string;
  first_name?: string;
  last_name?: string;
  phone_number?: string;
  date_of_birth?: string;
  address?: string;
  level_id?: number;
  major_id?: number;
  is_active?: boolean;
}

export interface StudentProfile {
  id: number;
  user: User;
  student_id: string;
  phone_number: string;
  date_of_birth?: string;
  level: Level;
  major: Major;
  photo?: string;
}

export interface CreateStudentDTO {
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  password: string;
  student_id: string;
  phone_number?: string;
  date_of_birth?: string;
  level: number;
  major: number;
  is_active?: boolean;
}

export interface StudentStatistics {
  total_views: number;
  total_downloads: number;
  total_quiz_attempts: number;
  average_quiz_score: number;
  quiz_pass_rate: number;
  performance_by_subject: SubjectPerformance[];
  recent_activities: Activity[];
}

export interface SubjectPerformance {
  subject: {
    id: number;
    name: string;
    code: string;
  };
  views: number;
  downloads: number;
  quiz_attempts: number;
  average_score: number;
  pass_rate: number;
}

export interface Activity {
  id: number;
  type: 'VIEW' | 'DOWNLOAD' | 'QUIZ_ATTEMPT';
  description: string;
  subject?: {
    id: number;
    name: string;
  };
  created_at: string;
}

// Document types
export interface Document {
  id: number;
  title: string;
  description?: string;
  file: string;
  file_size: number;
  file_type: string;
  document_type: 'COURSE' | 'TD' | 'TP' | 'EXAM' | 'OTHER';
  subject: {
    id: number;
    name: string;
    code: string;
  };
  uploaded_by: {
    id: number;
    first_name: string;
    last_name: string;
  };
  view_count: number;
  download_count: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

// Quiz types
export interface Quiz {
  id: number;
  title: string;
  description?: string;
  subject: {
    id: number;
    name: string;
    code: string;
  };
  duration: number;
  passing_score: number;
  instructions?: string;
  max_attempts: number;
  show_results_immediately: boolean;
  is_active: boolean;
  is_published: boolean;
  total_points: number;
  questions: Question[];
  created_by: {
    id: number;
    first_name: string;
    last_name: string;
  };
  created_at: string;
  updated_at: string;
}

export interface Question {
  id: number;
  question_text: string;
  question_type: 'MULTIPLE_CHOICE' | 'TRUE_FALSE' | 'SHORT_ANSWER';
  points: number;
  order: number;
  choices?: Choice[];
  correct_answer?: boolean;
  expected_answer?: string;
}

export interface Choice {
  id: number;
  choice_text: string;
  is_correct: boolean;
  order: number;
}

export interface QuizAttempt {
  id: number;
  user: {
    id: number;
    first_name: string;
    last_name: string;
    student_id?: string;
  };
  quiz: {
    id: number;
    title: string;
  };
  score: number;
  max_score: number;
  started_at: string;
  completed_at?: string;
  time_taken?: number;
  status: 'IN_PROGRESS' | 'COMPLETED';
  answers: Answer[];
}

export interface Answer {
  id: number;
  question: {
    id: number;
    question_text: string;
    question_type: string;
  };
  selected_choice?: number;
  answer_text?: string;
  is_correct: boolean;
  points_earned: number;
}

// Dashboard types
export interface DashboardStats {
  total_students: number;
  total_teachers: number;
  total_subjects: number;
  total_documents: number;
  total_quizzes: number;
  active_students: number;
  active_teachers: number;
  students_by_major: Array<{ major: string; count: number }>;
  students_by_level: Array<{ level: string; count: number }>;
  activity_timeline: Array<{ date: string; views: number; downloads: number; quiz_attempts: number }>;
  top_subjects: Array<{ subject: string; views: number; downloads: number }>;
  quiz_performance: {
    total_attempts: number;
    average_score: number;
    pass_rate: number;
  };
  recent_activities: Activity[];
}

// API Response types
export interface ApiResponse<T> {
  success: boolean;
  message?: string;
  data?: T;
}

export interface PaginatedResponse<T> {
  count: number;
  next?: string;
  previous?: string;
  results: T[];
}

// Bulk action types
export interface BulkActionPayload {
  action: 'activate' | 'deactivate' | 'change_level' | 'change_major' | 'delete';
  student_ids: number[];
  level?: number;
  major?: number;
}
