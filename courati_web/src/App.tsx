import { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'sonner';
import { useAuthStore } from './stores/authStore';

// Pages
import LoginPage from './pages/auth/LoginPage';
import ProtectedRoute from './components/common/ProtectedRoute';
import AppLayout from './components/layout/AppLayout';
import TeacherLayout from './components/layout/TeacherLayout';
import DashboardPage from './pages/admin/DashboardPage';
import LevelsPage from './pages/admin/LevelsPage';
import MajorsPage from './pages/admin/MajorsPage';
import SubjectsPage from './pages/admin/SubjectsPage';
import TeachersPage from './pages/admin/TeachersPage';
import StudentsPage from './pages/admin/StudentsPage';
import StudentDetailPage from './pages/admin/StudentDetailPage';
import TeacherDashboardPage from './pages/teacher/TeacherDashboardPage';
import TeacherSubjectsPage from './pages/teacher/TeacherSubjectsPage';
import TeacherSubjectDetailPage from './pages/teacher/TeacherSubjectDetailPage';
import TeacherDocumentsPage from './pages/teacher/TeacherDocumentsPage';
import TeacherQuizzesPage from './pages/teacher/TeacherQuizzesPage';
import TeacherQuizDetailPage from './pages/teacher/TeacherQuizDetailPage';
import QuizFormPage from './pages/teacher/QuizFormPage';
import AdminDocumentsPage from './pages/admin/AdminDocumentsPage';
import AdminDocumentDetailPage from './pages/admin/AdminDocumentDetailPage';
import AdminQuizzesPage from './pages/admin/AdminQuizzesPage';
import AdminQuizFormPage from './pages/admin/AdminQuizFormPage';
import AdminQuizDetailPage from './pages/admin/AdminQuizDetailPage';
import ProfilePage from './pages/admin/ProfilePage';

// Créer le client React Query
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
      staleTime: 5 * 60 * 1000, // 5 minutes
    },
  },
});

function App() {
  const { initializeAuth } = useAuthStore();

  // Initialiser l'authentification au chargement
  useEffect(() => {
    initializeAuth();
  }, [initializeAuth]);

  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          {/* Route publique */}
          <Route path="/login" element={<LoginPage />} />

          {/* Routes protégées - Admin */}
          <Route
            path="/admin"
            element={
              <ProtectedRoute requiredRole="ADMIN">
                <AppLayout />
              </ProtectedRoute>
            }
          >
            <Route path="dashboard" element={<DashboardPage />} />
            <Route path="levels" element={<LevelsPage />} />
            <Route path="majors" element={<MajorsPage />} />
            <Route path="subjects" element={<SubjectsPage />} />
            <Route path="documents" element={<AdminDocumentsPage />} />
            <Route path="documents/:id" element={<AdminDocumentDetailPage />} />
            <Route path="teachers" element={<TeachersPage />} />
            <Route path="students" element={<StudentsPage />} />
            <Route path="students/:id" element={<StudentDetailPage />} />
            <Route path="quizzes" element={<AdminQuizzesPage />} />
            <Route path="quizzes/new" element={<AdminQuizFormPage />} />
            <Route path="quizzes/:id" element={<AdminQuizDetailPage />} />
            <Route path="quizzes/:id/edit" element={<AdminQuizFormPage />} />
            <Route path="profile" element={<ProfilePage />} />
            <Route path="settings" element={<div className="p-6">Paramètres</div>} />
            <Route index element={<Navigate to="dashboard" replace />} />
          </Route>

          {/* Routes protégées - Enseignant */}
          <Route
            path="/teacher"
            element={
              <ProtectedRoute requiredRole="TEACHER">
                <TeacherLayout />
              </ProtectedRoute>
            }
          >
            <Route path="dashboard" element={<TeacherDashboardPage />} />
            <Route path="subjects" element={<TeacherSubjectsPage />} />
            <Route path="subjects/:id" element={<TeacherSubjectDetailPage />} />
            <Route path="documents" element={<TeacherDocumentsPage />} />
            <Route path="quizzes" element={<TeacherQuizzesPage />} />
            <Route path="quizzes/:id" element={<TeacherQuizDetailPage />} />
            <Route path="quizzes/create" element={<QuizFormPage />} />
            <Route path="quizzes/:id/edit" element={<QuizFormPage />} />
            <Route path="profile" element={<ProfilePage />} />
            <Route index element={<Navigate to="dashboard" replace />} />
          </Route>

          {/* Redirection par défaut */}
          <Route path="/" element={<Navigate to="/login" replace />} />
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>

        {/* Toaster pour les notifications */}
        <Toaster 
          position="top-right" 
          richColors 
          closeButton
          duration={4000}
        />
      </BrowserRouter>
    </QueryClientProvider>
  );
}

export default App;
