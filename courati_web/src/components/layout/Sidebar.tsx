import { NavLink } from 'react-router-dom';
import { 
  LayoutDashboard, 
  GraduationCap, 
  BookOpen, 
  Library, 
  Users, 
  UserCheck, 
  FileQuestion,
  X
} from 'lucide-react';
import { cn } from '../../lib/utils';
import Logo from '../common/Logo';

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

const menuItems = [
  { 
    name: 'Dashboard', 
    path: '/admin/dashboard', 
    icon: LayoutDashboard 
  },
  { 
    name: 'Niveaux', 
    path: '/admin/levels', 
    icon: GraduationCap 
  },
  { 
    name: 'Filières', 
    path: '/admin/majors', 
    icon: BookOpen 
  },
  { 
    name: 'Matières', 
    path: '/admin/subjects', 
    icon: Library 
  },
  { 
    name: 'Enseignants', 
    path: '/admin/teachers', 
    icon: Users 
  },
  { 
    name: 'Étudiants', 
    path: '/admin/students', 
    icon: UserCheck 
  },
  { 
    name: 'Quiz', 
    path: '/admin/quizzes', 
    icon: FileQuestion 
  },
];

export default function Sidebar({ isOpen, onClose }: SidebarProps) {
  return (
    <>
      {/* Overlay mobile */}
      {isOpen && (
        <div 
          className="fixed inset-0 bg-black/50 z-40 lg:hidden"
          onClick={onClose}
        />
      )}

      {/* Sidebar */}
      <aside
        className={cn(
          "fixed top-0 left-0 z-50 h-full w-72 bg-white border-r border-gray-200 transition-transform duration-300 lg:translate-x-0",
          isOpen ? "translate-x-0" : "-translate-x-full"
        )}
      >
        {/* Header */}
        <div className="flex items-center justify-between h-20 px-6 border-b border-gray-200">
          <div className="flex items-center justify-center w-full">
            <Logo size="lg" />
          </div>
          
          {/* Bouton fermer (mobile) */}
          <button
            onClick={onClose}
            className="lg:hidden absolute top-4 right-4 p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="h-5 w-5 text-gray-500" />
          </button>
        </div>

        {/* Navigation */}
        <nav className="flex-1 px-4 py-6 space-y-1 overflow-y-auto">
          {menuItems.map((item) => {
            const Icon = item.icon;
            return (
              <NavLink
                key={item.path}
                to={item.path}
                onClick={() => {
                  // Fermer la sidebar sur mobile après clic
                  if (window.innerWidth < 1024) {
                    onClose();
                  }
                }}
                className={({ isActive }) =>
                  cn(
                    "flex items-center space-x-3 px-4 py-3 rounded-lg transition-all",
                    isActive
                      ? "bg-primary-50 text-primary-600 border-l-4 border-primary-600 font-medium"
                      : "text-gray-700 hover:bg-gray-50 hover:text-gray-900"
                  )
                }
              >
                <Icon className="h-5 w-5 flex-shrink-0" />
                <span>{item.name}</span>
              </NavLink>
            );
          })}
        </nav>

        {/* Footer */}
        <div className="p-4 border-t border-gray-200">
          <div className="text-xs text-gray-500 text-center">
            © 2025 Courati
          </div>
        </div>
      </aside>
    </>
  );
}
