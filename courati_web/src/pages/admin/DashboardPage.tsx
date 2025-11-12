import { useQuery } from '@tanstack/react-query';
import { Users, GraduationCap, Library, FileText, TrendingUp, Activity } from 'lucide-react';
import { useAuth } from '../../hooks/useAuth';
import { dashboardAPI } from '../../api/dashboard';
import StatCard from '../../components/common/StatCard';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';

const COLORS = ['#3B82F6', '#10B981', '#8B5CF6', '#F59E0B', '#EF4444'];

export default function DashboardPage() {
  const { user } = useAuth();

  // Récupérer les statistiques
  const { data: stats, isLoading, error } = useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: dashboardAPI.getStats,
  });

  if (isLoading) {
    return <LoadingSpinner size="lg" text="Chargement des statistiques..." />;
  }

  if (error) {
    return (
      <div className="bg-red-50 border border-red-200 rounded-xl p-6 text-center">
        <p className="text-red-600">Erreur lors du chargement des statistiques</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Welcome Card */}
      <div className="bg-gradient-to-r from-primary-500 to-secondary-600 rounded-xl p-8 text-white">
        <h1 className="text-3xl font-bold mb-2">
          Bienvenue, {user?.first_name} ! 👋
        </h1>
        <p className="text-primary-100">
          Voici un aperçu de votre plateforme Courati
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Étudiants"
          value={stats?.stats.total_students || 0}
          icon={Users}
          color="blue"
        />
        <StatCard
          title="Enseignants"
          value={stats?.stats.total_teachers || 0}
          icon={GraduationCap}
          color="green"
        />
        <StatCard
          title="Matières"
          value={stats?.stats.total_subjects || 0}
          icon={Library}
          color="purple"
        />
        <StatCard
          title="Documents"
          value={stats?.stats.total_documents || 0}
          icon={FileText}
          color="orange"
        />
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Étudiants par Filière */}
        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Étudiants par Filière
          </h3>
          {stats?.students_by_major && stats.students_by_major.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={stats.students_by_major}
                  dataKey="count"
                  nameKey="major"
                  cx="50%"
                  cy="50%"
                  outerRadius={100}
                  label
                >
                  {stats.students_by_major.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          ) : (
            <p className="text-gray-500 text-center py-8">Aucune donnée disponible</p>
          )}
        </div>

        {/* Étudiants par Niveau */}
        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Étudiants par Niveau
          </h3>
          {stats?.students_by_level && stats.students_by_level.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={stats.students_by_level}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="level" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="count" fill="#3B82F6" />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <p className="text-gray-500 text-center py-8">Aucune donnée disponible</p>
          )}
        </div>
      </div>

      {/* Top Matières */}
      {stats?.top_subjects && stats.top_subjects.length > 0 && (
        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
            <TrendingUp className="h-5 w-5 mr-2 text-primary-500" />
            Top 5 Matières
          </h3>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-gray-200">
                  <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Matière</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-600">Vues</th>
                  <th className="text-right py-3 px-4 text-sm font-medium text-gray-600">Téléchargements</th>
                </tr>
              </thead>
              <tbody>
                {stats.top_subjects.map((subject, index) => (
                  <tr key={index} className="border-b border-gray-100 hover:bg-gray-50">
                    <td className="py-3 px-4 text-sm text-gray-900">{subject.subject}</td>
                    <td className="py-3 px-4 text-sm text-gray-600 text-right">{subject.views}</td>
                    <td className="py-3 px-4 text-sm text-gray-600 text-right">{subject.downloads}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* Activités Récentes */}
      {stats?.recent_activities && stats.recent_activities.length > 0 && (
        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
            <Activity className="h-5 w-5 mr-2 text-primary-500" />
            Activités Récentes
          </h3>
          <div className="space-y-3">
            {stats.recent_activities.slice(0, 10).map((activity) => (
              <div key={activity.id} className="flex items-start space-x-3 p-3 hover:bg-gray-50 rounded-lg transition-colors">
                <div className="w-2 h-2 bg-primary-500 rounded-full mt-2"></div>
                <div className="flex-1">
                  <p className="text-sm text-gray-900">{activity.description}</p>
                  <p className="text-xs text-gray-500 mt-1">
                    {new Date(activity.created_at).toLocaleString('fr-FR')}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
