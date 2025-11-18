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
  const [localError, setLocalError] = useState<string | null>(null);
  const [hasError, setHasError] = useState(false); // Suivre si une erreur s'est produite

  // Rediriger si déjà authentifié
  useEffect(() => {
    if (isAuthenticated) {
      navigate('/admin/dashboard');
    }
  }, [isAuthenticated, navigate]);

  // Synchroniser l'erreur du store avec l'erreur locale
  useEffect(() => {
    if (error) {
      setLocalError(error);
      setHasError(true);
    }
  }, [error]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    e.stopPropagation();
    
    // Réinitialiser l'état d'erreur pour une nouvelle tentative
    setHasError(false);
    
    // Nettoyer l'erreur locale avant la soumission
    setLocalError(null);
    clearError();
    
    if (!formData.username || !formData.password) {
      const msg = 'Veuillez remplir tous les champs';
      setLocalError(msg);
      setHasError(true);
      toast.error(msg);
      return;
    }

    try {
      await login(formData.username, formData.password);
      
      // Succès : marquer qu'il n'y a pas d'erreur
      setHasError(false);
      setLocalError(null);
      clearError();
      toast.success('Connexion réussie !');
      
      // Laisser un délai avant la redirection pour que le navigateur détecte le succès
      // et propose d'enregistrer le mot de passe. Le délai de 1 seconde permet au navigateur
      // de détecter que le formulaire a été soumis avec succès (pas d'erreur, pas de rechargement)
      setTimeout(() => {
        navigate('/admin/dashboard');
      }, 1000);
    } catch (err: any) {
      // Extraire le message d'erreur
      const errorMsg = err.response?.data?.detail || 
                      err.response?.data?.message || 
                      err.response?.data?.error ||
                      err.response?.data?.non_field_errors?.[0] ||
                      'Identifiants incorrects';
      
      // Afficher l'erreur localement (persiste jusqu'à nouvelle tentative)
      setLocalError(errorMsg);
      setHasError(true);
      
      // Afficher aussi un toast avec durée longue
      toast.error(errorMsg, {
        duration: 8000, // 8 secondes
      });
      console.error('Login error:', err);
      
      // Les champs restent remplis pour que l'utilisateur puisse corriger
    }
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData(prev => ({
      ...prev,
      [e.target.name]: e.target.value,
    }));
    // Ne pas effacer l'erreur automatiquement quand l'utilisateur tape
  };

  const handleCloseError = () => {
    setLocalError(null);
    clearError();
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-white px-4 py-12">
      <div className="relative w-full max-w-md">
        {/* Logo centré - plus grand */}
        <div className="text-center mb-6">
          <div className="inline-flex items-center justify-center">
            <Logo size="xl" />
          </div>
        </div>

        {/* Carte de connexion */}
        <div className="bg-white rounded-2xl shadow-xl border border-gray-100 p-8">
          <div className="mb-6">
            <h2 className="text-2xl font-bold text-gray-900 mb-2">
              Connexion
            </h2>
            <p className="text-gray-600">
              Accédez à votre espace administrateur
            </p>
          </div>

          {/* Erreur globale - reste affichée jusqu'à fermeture ou nouvelle tentative */}
          {localError && (
            <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg relative animate-in fade-in duration-300">
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

          <form 
            onSubmit={handleSubmit} 
            className="space-y-5"
            autoComplete={hasError ? "off" : "on"}
            // Changer le nom du formulaire après une erreur pour que le navigateur
            // ne le reconnaisse pas comme un formulaire de connexion valide
            name={hasError ? "login-form-error" : "login-form"}
          >
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
                  autoComplete={hasError ? "off" : "username"}
                  required
                  value={formData.username}
                  onChange={handleChange}
                  disabled={isLoading}
                  className="block w-full pl-10 pr-3 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 transition-all disabled:bg-gray-50 disabled:cursor-not-allowed"
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
                  // Utiliser "new-password" en cas d'erreur pour empêcher l'enregistrement
                  // Utiliser "current-password" seulement quand il n'y a pas d'erreur
                  autoComplete={hasError ? "new-password" : "current-password"}
                  required
                  value={formData.password}
                  onChange={handleChange}
                  disabled={isLoading}
                  className="block w-full pl-10 pr-10 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500 transition-all disabled:bg-gray-50 disabled:cursor-not-allowed"
                  placeholder="••••••••"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  disabled={isLoading}
                  className="absolute inset-y-0 right-0 pr-3 flex items-center hover:text-primary-600 transition-colors disabled:cursor-not-allowed"
                  aria-label={showPassword ? 'Masquer le mot de passe' : 'Afficher le mot de passe'}
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
              className="w-full flex items-center justify-center px-4 py-3 border border-transparent text-base font-medium rounded-lg text-white bg-primary-500 hover:bg-primary-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-all disabled:opacity-50 disabled:cursor-not-allowed shadow-md hover:shadow-lg"
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
          <p className="text-sm text-gray-500">
            © 2025 Courati. Tous droits réservés.
          </p>
        </div>
      </div>
    </div>
  );
}
