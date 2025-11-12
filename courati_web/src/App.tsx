import { useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'sonner';
import { useAuthStore } from './stores/authStore';

// Pages
import LoginPage from './pages/auth/LoginPage';
import ProtectedRoute from './components/common/ProtectedRoute';
import AppLayout from './components/layout/AppLayout';
import DashboardPage from './pages/admin/DashboardPage';
import LevelsPage from './pages/admin/LevelsPage';
import MajorsPage from './pages/admin/MajorsPage';
import SubjectsPage from './pages/admin/SubjectsPage';
import TeachersPage from './pages/admin/TeachersPage';
import StudentsPage from './pages/admin/StudentsPage';

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
            <Route path="teachers" element={<TeachersPage />} />
            <Route path="students" element={<StudentsPage />} />
            <Route path="quizzes" element={<div className="p-6">Quiz (Étape 4+)</div>} />
            <Route path="profile" element={<div className="p-6">Mon Profil</div>} />
            <Route path="settings" element={<div className="p-6">Paramètres</div>} />
            <Route index element={<Navigate to="dashboard" replace />} />
          </Route>

          {/* Routes protégées - Enseignant */}
          <Route
            path="/teacher/*"
            element={
              <ProtectedRoute requiredRole="TEACHER">
                <div className="min-h-screen flex items-center justify-center bg-gray-50">
                  <div className="text-center">
                    <h1 className="text-4xl font-bold text-gray-900 mb-4">
                      Interface Enseignant
                    </h1>
                    <p className="text-gray-600">
                      Dashboard enseignant (Étape 8)
                    </p>
                  </div>
                </div>
              </ProtectedRoute>
            }
          />

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
