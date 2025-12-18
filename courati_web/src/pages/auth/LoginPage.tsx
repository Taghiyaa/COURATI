import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { User, Lock, Eye, EyeOff, Loader2, X } from 'lucide-react';
import { useAuthStore } from '../../stores/authStore';
import { toast } from 'sonner';
import Logo from '../../components/common/Logo';

export default function LoginPage() {
  const navigate = useNavigate();
  const { login, isLoading, error, clearError, isAuthenticated, user } = useAuthStore();
  
  const [formData, setFormData] = useState({
    username: '',
    password: '',
  });
  const [showPassword, setShowPassword] = useState(false);
  const [localError, setLocalError] = useState<string | null>(null);

  // ✅ Redirection uniquement quand authentifié ET user existe
  useEffect(() => {
    if (isAuthenticated && user) {
      console.log('🔄 Redirection basée sur le rôle:', user.role);
      
      // Redirection immédiate sans timeout
      if (user.role === 'ADMIN') {
        navigate('/admin/dashboard', { replace: true });
      } else if (user.role === 'TEACHER') {
        navigate('/teacher/dashboard', { replace: true });
      }
    }
  }, [isAuthenticated, user, navigate]);

  // Synchroniser erreur store → local
  useEffect(() => {
    if (error) {
      setLocalError(error);
    }
  }, [error]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    e.stopPropagation();

    // Réinitialiser les erreurs
    setLocalError(null);
    clearError();

    // Validation des champs
    if (!formData.username.trim() || !formData.password.trim()) {
      const msg = 'Veuillez remplir tous les champs';
      setLocalError(msg);
      toast.error(msg);
      return;
    }

    try {
      // ✅ Appeler login et attendre la résolution
      await login(formData.username, formData.password);
      
      // ✅ Si on arrive ici, le login a réussi
      console.log('✅ Login réussi, affichage toast');
      toast.success('Connexion réussie !', { duration: 2000 });
      
      // ✅ La redirection sera gérée par le useEffect ci-dessus
      
    } catch (err: any) {
      // ✅ Gérer l'erreur
      console.error('❌ Erreur login dans composant:', err);
      
      const errorMsg = err.message || 'Identifiants incorrects';
      
      setLocalError(errorMsg);
      toast.error(errorMsg, { duration: 4000 });
      
      // ✅ NE PAS vider les champs en cas d'erreur
      // Les champs restent remplis pour que l'utilisateur puisse corriger
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData(prev => ({
      ...prev,
      [e.target.name]: e.target.value,
    }));
    
    // Effacer l'erreur locale quand l'utilisateur commence à taper
    if (localError) {
      setLocalError(null);
      clearError();
    }
  };

  const handleCloseError = () => {
    setLocalError(null);
    clearError();
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-white px-4 py-12">
      <div className="relative w-full max-w-md">
        
        {/* Logo */}
        <div className="text-center mb-6">
          <div className="inline-flex items-center justify-center">
            <Logo size="xl" />
          </div>
        </div>

        {/* Carte */}
        <div className="bg-white rounded-2xl shadow-xl border border-gray-100 p-8">
          <div className="mb-6">
            <h2 className="text-2xl font-bold text-gray-900 mb-2">
              Connexion
            </h2>
            <p className="text-gray-600">Accédez à votre espace</p>
          </div>

          {/* Erreur */}
          {localError && (
            <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg relative">
              <button
                onClick={handleCloseError}
                className="absolute top-2 right-2 p-1 hover:bg-red-100 rounded transition-colors"
                aria-label="Fermer l'erreur"
              >
                <X className="h-4 w-4 text-red-600" />
              </button>
              <p className="text-sm text-red-600 font-medium pr-6">
                {localError}
              </p>
            </div>
          )}

          {/* Formulaire */}
          <form onSubmit={handleSubmit} className="space-y-5" autoComplete="on">

            {/* Username */}
            <div>
              <label htmlFor="username" className="block text-sm font-medium text-gray-700 mb-2">
                Nom d'utilisateur ou Email
              </label>
              <div className="relative">
                <User className="absolute left-3 top-3 h-5 w-5 text-gray-400 pointer-events-none" />
                <input
                  id="username"
                  name="username"
                  type="text"
                  autoComplete="username"
                  required
                  value={formData.username}
                  onChange={handleChange}
                  disabled={isLoading}
                  className="block w-full pl-10 pr-3 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 disabled:bg-gray-50 disabled:cursor-not-allowed transition-colors"
                  placeholder="admin@courati.mr"
                />
              </div>
            </div>

            {/* Password */}
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
                Mot de passe
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-3 h-5 w-5 text-gray-400 pointer-events-none" />
                <input
                  id="password"
                  name="password"
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="current-password"
                  required
                  value={formData.password}
                  onChange={handleChange}
                  disabled={isLoading}
                  className="block w-full pl-10 pr-10 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 disabled:bg-gray-50 disabled:cursor-not-allowed transition-colors"
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  disabled={isLoading}
                  className="absolute right-3 top-3 text-gray-400 hover:text-primary-600 transition-colors disabled:cursor-not-allowed"
                  aria-label={showPassword ? 'Masquer le mot de passe' : 'Afficher le mot de passe'}
                >
                  {showPassword ? <EyeOff className="h-5 w-5" /> : <Eye className="h-5 w-5" />}
                </button>
              </div>
            </div>

            {/* Bouton */}
            <button
              type="submit"
              disabled={isLoading}
              className="w-full flex items-center justify-center px-4 py-3 text-base font-medium rounded-lg text-white bg-primary-500 hover:bg-primary-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 disabled:opacity-50 disabled:cursor-not-allowed shadow-md transition-all"
            >
              {isLoading ? (
                <>
                  <Loader2 className="animate-spin -ml-1 mr-2 h-5 w-5" />
                  Connexion en cours...
                </>
              ) : (
                'Se connecter'
              )}
            </button>

          </form>
        </div>

        {/* Footer */}
        <div className="mt-8 text-center">
          <p className="text-sm text-gray-500">© 2025 Courati. Tous droits réservés.</p>
        </div>

      </div>
    </div>
  );
}
