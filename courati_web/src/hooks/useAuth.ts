import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { authAPI } from '../api/auth';
import { useAuthStore } from '../stores/authStore';
import { toast } from 'sonner';

export function useAuth() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const { user, isAuthenticated, logout: logoutStore } = useAuthStore();

  // Query pour récupérer l'utilisateur connecté (clé distincte pour éviter conflit avec la page Profil)
  const { data: profile, isLoading: isLoadingProfile } = useQuery({
    queryKey: ['auth_user'],
    queryFn: authAPI.getProfile,
    enabled: isAuthenticated && !!localStorage.getItem('access_token'),
    retry: false,
    staleTime: 5 * 60 * 1000, // 5 minutes
  });

  // Mutation pour la déconnexion
  const logoutMutation = useMutation({
    mutationFn: authAPI.logout,
    onSuccess: () => {
      logoutStore();
      queryClient.clear();
      navigate('/login');
      toast.success('Déconnexion réussie');
    },
    onError: (error) => {
      console.error('Logout error:', error);
      // Déconnecter quand même côté client
      logoutStore();
      queryClient.clear();
      navigate('/login');
    },
  });

  const logout = () => {
    logoutMutation.mutate();
  };

  return {
    user: profile || user,
    isAuthenticated,
    isLoading: isLoadingProfile,
    logout,
    isLoggingOut: logoutMutation.isPending,
  };
}

// Hook pour vérifier si l'utilisateur a un rôle spécifique
export function useHasRole(role: 'ADMIN' | 'TEACHER' | 'STUDENT') {
  const { user } = useAuth();
  return user?.role === role;
}

// Hook pour vérifier si l'utilisateur est admin
export function useIsAdmin() {
  return useHasRole('ADMIN');
}

// Hook pour vérifier si l'utilisateur est enseignant
export function useIsTeacher() {
  return useHasRole('TEACHER');
}
