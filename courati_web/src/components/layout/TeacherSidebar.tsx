import { NavLink } from 'react-router-dom';
import { LayoutDashboard, Library, FileText, FileQuestion } from 'lucide-react';
import { cn } from '../../lib/utils';
import Logo from '../common/Logo';

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
}

const menuItems = [
  { name: 'Dashboard', path: '/teacher/dashboard', icon: LayoutDashboard },
  { name: 'Mes Matières', path: '/teacher/subjects', icon: Library },
  { name: 'Mes Documents', path: '/teacher/documents', icon: FileText },
  { name: 'Mes Quiz', path: '/teacher/quizzes', icon: FileQuestion },
];

export default function TeacherSidebar({ isOpen, onClose }: SidebarProps) {
  return (
    <aside
      className={cn(
        "fixed top-0 left-0 z-50 h-full w-72 bg-white border-r border-gray-200 transition-transform duration-300 lg:translate-x-0",
        isOpen ? "translate-x-0" : "-translate-x-full"
      )}
    >
      <div className="flex items-center justify-between h-20 px-6 border-b border-gray-200">
        <div className="flex items-center justify-center w-full">
          <Logo size="lg" />
        </div>
      </div>

      <nav className="flex-1 px-4 py-6 space-y-1 overflow-y-auto">
        {menuItems.map((item) => {
          const Icon = item.icon;
          return (
            <NavLink
              key={item.path}
              to={item.path}
              onClick={() => {
                if (window.innerWidth < 1024) onClose();
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

      <div className="p-4 border-t border-gray-200">
        <div className="text-xs text-gray-500 text-center">© 2025 Courati</div>
      </div>
    </aside>
  );
}
