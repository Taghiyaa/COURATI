import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { User, Lock, Eye, EyeOff, Loader2, X } from 'lucide-react';
import { useAuthStore } from '../../stores/authStore';
import { toast } from 'sonner';
import Logo from '../../components/common/Logo';

export default function LoginPage() {
  const navigate = useNavigate();
  const { login, isLoading, error, clearError, isAuthenticated } = useAuthStore();
  
  const [formData, setFormData] = useState({
    username: '',
    password: '',
  });
  const [showPassword, setShowPassword] = useState(false);

  // Rediriger si déjà authentifié
  useEffect(() => {
    if (isAuthenticated) {
      navigate('/admin/dashboard');
    }
  }, [isAuthenticated, navigate]);

  // Nettoyer les erreurs au démontage
  useEffect(() => {
    return () => clearError();
  }, [clearError]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    e.stopPropagation();
    
    if (!formData.username || !formData.password) {
      toast.error('Veuillez remplir tous les champs');
      return;
    }

    try {
      await login(formData.username, formData.password);
      toast.success('Connexion réussie !');
      navigate('/admin/dashboard');
    } catch (err: any) {
      // Afficher le toast d'erreur avec durée plus longue
      const errorMsg = err.response?.data?.detail || 
                      err.response?.data?.message || 
                      err.response?.data?.error ||
                      error || 
                      'Identifiants incorrects';
      toast.error(errorMsg, {
        duration: 6000, // 6 secondes
      });
      console.error('Login error:', err);
      
      // Ne pas vider les champs en cas d'erreur
      // Les champs restent remplis pour que l'utilisateur puisse corriger
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData(prev => ({
      ...prev,
      [e.target.name]: e.target.value,
    }));
    // Ne pas effacer l'erreur automatiquement pour que l'utilisateur puisse la lire
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-primary-500 via-primary-600 to-secondary-600 px-4 py-12">
      {/* Overlay avec pattern */}
      <div className="absolute inset-0 bg-black/10 backdrop-blur-[1px]" />
      
      <div className="relative w-full max-w-md">
        {/* Logo et titre */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center mb-4">
            <Logo size="lg" className="shadow-xl" />
          </div>
          <h1 className="text-4xl font-bold text-white mb-2">
            Courati
          </h1>
          <p className="text-primary-100 text-lg">
            Plateforme Éducative Mauritanienne
          </p>
        </div>

        {/* Carte de connexion */}
        <div className="bg-white rounded-2xl shadow-2xl p-8">
          <div className="mb-6">
            <h2 className="text-2xl font-bold text-gray-900 mb-2">
              Connexion
            </h2>
            <p className="text-gray-600">
              Accédez à votre espace administrateur
            </p>
          </div>

          {/* Erreur globale */}
          {error && (
            <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg relative">
              <button
                onClick={clearError}
                className="absolute top-2 right-2 p-1 hover:bg-red-100 rounded transition-colors"
              >
                <X className="h-4 w-4 text-red-600" />
              </button>
              <p className="text-sm text-red-600 font-medium pr-6">
                {error}
              </p>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-5" autoComplete="off">
            {/* Champ Username */}
            <div>
              <label htmlFor="username" className="block text-sm font-medium text-gray-700 mb-2">
                Nom d'utilisateur ou Email
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <User className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  id="username"
                  name="username"
                  type="text"
                  autoComplete="off"
                  required
                  value={formData.username}
                  onChange={handleChange}
                  disabled={isLoading}
                  className="block w-full pl-10 pr-3 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-all disabled:bg-gray-50 disabled:cursor-not-allowed"
                  placeholder="admin@courati.mr"
                />
              </div>
            </div>

            {/* Champ Password */}
            <div>
              <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
                Mot de passe
              </label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                  <Lock className="h-5 w-5 text-gray-400" />
                </div>
                <input
                  id="password"
                  name="password"
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="new-password"
                  required
                  value={formData.password}
                  onChange={handleChange}
                  disabled={isLoading}
                  className="block w-full pl-10 pr-10 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-all disabled:bg-gray-50 disabled:cursor-not-allowed"
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  disabled={isLoading}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center hover:text-primary-600 transition-colors disabled:cursor-not-allowed"
                >
                  {showPassword ? (
                    <EyeOff className="h-5 w-5 text-gray-400" />
                  ) : (
                    <Eye className="h-5 w-5 text-gray-400" />
                  )}
                </button>
              </div>
            </div>

            {/* Bouton de connexion */}
            <button
              type="submit"
              disabled={isLoading}
              className="w-full flex items-center justify-center px-4 py-3 border border-transparent text-base font-medium rounded-lg text-white bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl"
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

          {/* Lien mot de passe oublié */}
          <div className="mt-6 text-center">
            <button
              type="button"
              className="text-sm text-primary-600 hover:text-primary-700 font-medium transition-colors"
            >
              Mot de passe oublié ?
            </button>
          </div>
        </div>

        {/* Footer */}
        <div className="mt-8 text-center">
          <p className="text-sm text-white/80">
            © 2025 Courati. Tous droits réservés.
          </p>
        </div>
      </div>
    </div>
  );
}
