import { useQuery } from '@tanstack/react-query';
import { Users, GraduationCap, Library, FileText, TrendingUp, Activity, BookOpen, BarChart3, Zap, AlertCircle } from 'lucide-react';
import { dashboardAPI } from '../../api/dashboard';
import StatCard from '../../components/common/StatCard';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell, LineChart, Line, Legend } from 'recharts';
import type { DashboardData } from '../../types';

const COLORS = ['#005676', '#33A7C7', '#66BDD5', '#99D3E3', '#CCE9F1'];

export default function DashboardPage() {

  // Récupérer les statistiques
  const { data: dashboard, isLoading, error } = useQuery<DashboardData>({
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

  if (!dashboard) {
    return (
      <div className="bg-gray-50 border border-gray-200 rounded-xl p-6 text-center">
        <p className="text-gray-600">Aucune donnée disponible</p>
      </div>
    );
  }

  const { stats, students_by_major, students_by_level, top_subjects, recent_activities, activity_timeline, quiz_performance, system_health } = dashboard;

  return (
    <div className="space-y-6">
      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Étudiants"
          value={stats.total_students || 0}
          icon={Users}
          color="primary"
          trend={stats.active_students ? `${stats.active_students} actifs` : undefined}
        />
        <StatCard
          title="Enseignants"
          value={stats.total_teachers || 0}
          icon={GraduationCap}
          color="green"
          trend={stats.active_teachers ? `${stats.active_teachers} actifs` : undefined}
        />
        <StatCard
          title="Matières"
          value={stats.total_subjects || 0}
          icon={Library}
          color="purple"
          trend={stats.active_subjects ? `${stats.active_subjects} actives` : undefined}
        />
        <StatCard
          title="Documents"
          value={stats.total_documents || 0}
          icon={FileText}
          color="orange"
          trend={stats.new_documents_30d ? `+${stats.new_documents_30d} ce mois` : undefined}
        />
        <StatCard
          title="Quiz"
          value={stats.total_quizzes || 0}
          icon={BookOpen}
          color="indigo"
          trend={stats.active_quizzes ? `${stats.active_quizzes} actifs` : undefined}
        />
        <StatCard
          title="Nouveaux étudiants (30j)"
          value={stats.new_students_30d || 0}
          icon={Users}
          color="blue"
        />
        <StatCard
          title="Vues (30j)"
          value={stats.total_views_30d || 0}
          icon={BarChart3}
          color="teal"
        />
        <StatCard
          title="Tentatives quiz (30j)"
          value={stats.quiz_attempts_30d || 0}
          icon={Zap}
          color="yellow"
        />
      </div>

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Étudiants par Filière */}
        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Étudiants par Filière
          </h3>
          {students_by_major && students_by_major.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <PieChart>
                <Pie
                  data={students_by_major.map(item => ({
                    name: item.major_name,
                    value: item.student_count,
                    percentage: item.percentage
                  }))}
                  dataKey="value"
                  nameKey="name"
                  cx="50%"
                  cy="50%"
                  outerRadius={100}
                  label={(entry: any) => `${entry.name} (${entry.percentage?.toFixed(1) || 0}%)`}
                >
                  {students_by_major.map((_, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(value: number) => [`${value} étudiants`, '']} />
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
          {students_by_level && students_by_level.length > 0 ? (
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={students_by_level as any}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="level_name" />
                <YAxis />
                <Tooltip formatter={(value: number) => [`${value} étudiants`, '']} />
                <Bar dataKey="student_count" fill="#005676" />
              </BarChart>
            </ResponsiveContainer>
          ) : (
            <p className="text-gray-500 text-center py-8">Aucune donnée disponible</p>
          )}
        </div>
      </div>

      {/* Timeline d'activité */}
      {activity_timeline && activity_timeline.length > 0 && (
        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Activité sur les 7 derniers jours
          </h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={activity_timeline.map(item => ({
              ...item,
              date: new Date(item.date).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })
            }))}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="date" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="views" stroke="#005676" name="Vues" strokeWidth={2} />
              <Line type="monotone" dataKey="downloads" stroke="#33A7C7" name="Téléchargements" strokeWidth={2} />
              <Line type="monotone" dataKey="quiz_attempts" stroke="#66BDD5" name="Tentatives quiz" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      )}

      {/* Top Matières et Documents */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Top Matières */}
        {top_subjects && top_subjects.length > 0 && (
          <div className="bg-white rounded-xl p-6 border border-gray-200">
            <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
              <TrendingUp className="h-5 w-5 mr-2 text-primary-500" />
              Top Matières
            </h3>
            <div className="overflow-x-auto">
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-200">
                    <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Matière</th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-gray-600">Documents</th>
                    <th className="text-right py-3 px-4 text-sm font-medium text-gray-600">Vues</th>
                  </tr>
                </thead>
                <tbody>
                  {top_subjects.slice(0, 5).map((subject) => (
                    <tr key={subject.subject_id} className="border-b border-gray-100 hover:bg-gray-50">
                      <td className="py-3 px-4 text-sm text-gray-900">{subject.subject_name}</td>
                      <td className="py-3 px-4 text-sm text-gray-600 text-right">{subject.document_count}</td>
                      <td className="py-3 px-4 text-sm text-gray-600 text-right">{subject.view_count}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Performance des Quiz */}
        {quiz_performance && (
          <div className="bg-white rounded-xl p-6 border border-gray-200">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">
              Performance des Quiz
            </h3>
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Tentatives totales</span>
                <span className="text-lg font-semibold text-gray-900">{quiz_performance.total_attempts}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Tentatives complétées</span>
                <span className="text-lg font-semibold text-gray-900">{quiz_performance.completed_attempts}</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Score moyen</span>
                <span className="text-lg font-semibold text-gray-900">{quiz_performance.average_score.toFixed(2)}/20</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Taux de réussite</span>
                <span className="text-lg font-semibold text-gray-900">{quiz_performance.pass_rate.toFixed(1)}%</span>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Activités Récentes */}
      {recent_activities && recent_activities.length > 0 && (
        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
            <Activity className="h-5 w-5 mr-2 text-primary-500" />
            Activités Récentes
          </h3>
          <div className="space-y-3">
            {recent_activities.slice(0, 10).map((activity, index) => (
              <div key={index} className="flex items-start space-x-3 p-3 hover:bg-gray-50 rounded-lg transition-colors">
                <div className={`w-2 h-2 rounded-full mt-2 ${
                  activity.color === 'blue' ? 'bg-primary-500' :
                  activity.color === 'green' ? 'bg-green-500' :
                  activity.color === 'purple' ? 'bg-purple-500' :
                  'bg-gray-500'
                }`}></div>
                <div className="flex-1">
                  <p className="text-sm font-medium text-gray-900">{activity.title}</p>
                  <p className="text-sm text-gray-600">{activity.description}</p>
                  {activity.subject_name && (
                    <p className="text-xs text-gray-500 mt-1">Matière: {activity.subject_name}</p>
                  )}
                  <p className="text-xs text-gray-500 mt-1">
                    {new Date(activity.created_at).toLocaleString('fr-FR')}
                  </p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Santé du système */}
      {system_health && (
        <div className="bg-white rounded-xl p-6 border border-gray-200">
          <h3 className="text-lg font-semibold text-gray-900 mb-4 flex items-center">
            <AlertCircle className="h-5 w-5 mr-2 text-primary-500" />
            Santé du Système
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="p-4 bg-gray-50 rounded-lg">
              <p className="text-sm text-gray-600">Statut</p>
              <p className={`text-lg font-semibold mt-1 ${
                system_health.status === 'healthy' ? 'text-green-600' :
                system_health.status === 'warning' ? 'text-yellow-600' :
                'text-red-600'
              }`}>
                {system_health.status === 'healthy' ? 'Sain' :
                 system_health.status === 'warning' ? 'Avertissement' :
                 'Critique'}
              </p>
            </div>
            <div className="p-4 bg-gray-50 rounded-lg">
              <p className="text-sm text-gray-600">Stockage utilisé</p>
              <p className="text-lg font-semibold mt-1 text-gray-900">{system_health.total_storage_mb.toFixed(2)} MB</p>
            </div>
            <div className="p-4 bg-gray-50 rounded-lg">
              <p className="text-sm text-gray-600">Utilisateurs actifs aujourd'hui</p>
              <p className="text-lg font-semibold mt-1 text-gray-900">{system_health.active_users_today}</p>
            </div>
            <div className="p-4 bg-gray-50 rounded-lg">
              <p className="text-sm text-gray-600">Professeurs sans matière</p>
              <p className="text-lg font-semibold mt-1 text-gray-900">{system_health.pending_assignments}</p>
            </div>

            <div className="p-4 bg-gray-50 rounded-lg">
              <p className="text-sm text-gray-600">Professeurs inactifs</p>
              <p className="text-lg font-semibold mt-1 text-gray-900">{system_health.inactive_teachers}</p>
            </div>

            <div className="p-4 bg-gray-50 rounded-lg">
              <p className="text-sm text-gray-600">Matières sans contenu</p>
              <p className="text-lg font-semibold mt-1 text-gray-900">{system_health.subjects_without_content}</p>
            </div>


          </div>
        </div>
      )}
    </div>
  );
}
