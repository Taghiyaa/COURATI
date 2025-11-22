import { useState, useRef, useEffect } from 'react';
import { useLocation, Link } from 'react-router-dom';
import { Menu, ChevronRight, User, LogOut } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import { getInitials } from '../../lib/utils';
import { cn } from '../../lib/utils';

interface HeaderProps {
  onMenuClick: () => void;
}

// Mapping des routes vers des noms lisibles
const routeNames: Record<string, string> = {
  dashboard: 'Dashboard',
  levels: 'Niveaux',
  majors: 'Filières',
  subjects: 'Matières',
  teachers: 'Enseignants',
  students: 'Étudiants',
  quizzes: 'Quiz',
};

export default function Header({ onMenuClick }: HeaderProps) {
  const location = useLocation();
  const { user, logout, isLoggingOut } = useAuth();
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Générer les breadcrumbs depuis l'URL
  const pathSegments = location.pathname.split('/').filter(Boolean);
  const breadcrumbs = pathSegments.map((segment, index) => ({
    name: routeNames[segment] || segment.charAt(0).toUpperCase() + segment.slice(1),
    path: '/' + pathSegments.slice(0, index + 1).join('/'),
    isLast: index === pathSegments.length - 1,
  }));

  // Fermer le dropdown si clic extérieur
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsDropdownOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleLogout = () => {
    setIsDropdownOpen(false);
    logout();
  };

  return (
    <header className="h-16 bg-white border-b border-gray-200 sticky top-0 z-30">
      <div className="h-full px-4 lg:px-6 flex items-center justify-between">
        {/* Left: Menu + Breadcrumbs */}
        <div className="flex items-center space-x-4">
          {/* Bouton menu (mobile) */}
          <button
            onClick={onMenuClick}
            className="lg:hidden p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <Menu className="h-6 w-6 text-gray-700" />
          </button>

          {/* Breadcrumbs */}
          <nav className="hidden md:flex items-center space-x-2 text-sm">
            {breadcrumbs.map((crumb, index) => (
              <div key={crumb.path} className="flex items-center">
                {index > 0 && (
                  <ChevronRight className="h-4 w-4 text-gray-400 mx-2" />
                )}
                {crumb.isLast ? (
                  <span className="font-medium text-gray-900">{crumb.name}</span>
                ) : (
                  <Link
                    to={crumb.path}
                    className="text-gray-600 hover:text-gray-900 transition-colors"
                  >
                    {crumb.name}
                  </Link>
                )}
              </div>
            ))}
          </nav>
        </div>

        {/* Right: User */}
        <div className="flex items-center space-x-3">
          {/* User Dropdown */}
          <div className="relative" ref={dropdownRef}>
            <button
              onClick={() => setIsDropdownOpen(!isDropdownOpen)}
              className="flex items-center space-x-3 p-2 hover:bg-gray-100 rounded-lg transition-colors"
            >
              {/* Avatar */}
              <div className="w-8 h-8 bg-primary-500 rounded-full flex items-center justify-center">
                <span className="text-sm font-semibold text-white">
                  {user ? getInitials(user.first_name, user.last_name) : 'U'}
                </span>
              </div>
              
              {/* Nom (desktop) */}
              <div className="hidden lg:block text-left">
                <p className="text-sm font-medium text-gray-900">
                  {user?.first_name} {user?.last_name}
                </p>
                <p className="text-xs text-gray-500">
                  {user?.role === 'ADMIN' ? 'Administrateur' : user?.role === 'TEACHER' ? 'Enseignant' : 'Utilisateur'}
                </p>
              </div>
            </button>

            {/* Dropdown Menu */}
            {isDropdownOpen && (
              <div className="absolute right-0 mt-2 w-56 bg-white rounded-lg shadow-lg border border-gray-200 py-1">
                {/* User Info */}
                <div className="px-4 py-3 border-b border-gray-100">
                  <p className="text-sm font-medium text-gray-900">
                    {user?.first_name} {user?.last_name}
                  </p>
                  <p className="text-xs text-gray-500">{user?.email}</p>
                </div>

                {/* Menu Items */}
                <Link
                  to={user?.role === 'TEACHER' ? '/teacher/profile' : '/admin/profile'}
                  onClick={() => setIsDropdownOpen(false)}
                  className="flex items-center space-x-3 px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                >
                  <User className="h-4 w-4" />
                  <span>Mon Profil</span>
                </Link>

                {/* Paramètres supprimés */}

                <div className="border-t border-gray-100 my-1"></div>

                {/* Logout */}
                <button
                  onClick={handleLogout}
                  disabled={isLoggingOut}
                  className={cn(
                    "w-full flex items-center space-x-3 px-4 py-2 text-sm text-red-600 hover:bg-red-50 transition-colors",
                    isLoggingOut && "opacity-50 cursor-not-allowed"
                  )}
                >
                  <LogOut className="h-4 w-4" />
                  <span>{isLoggingOut ? 'Déconnexion...' : 'Déconnexion'}</span>
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}
