import { useQuery } from '@tanstack/react-query';
import { useMemo } from 'react';
import { teacherAPI } from '../../api/teacher';
import StatCard from '../../components/common/StatCard';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { Users, Library, FileText, FileQuestion } from 'lucide-react';
import { Link } from 'react-router-dom';
import { ResponsiveContainer, LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend } from 'recharts';

export default function TeacherDashboardPage() {
  const { data: dashboard, isLoading, error } = useQuery({
    queryKey: ['teacher-dashboard'],
    queryFn: teacherAPI.getDashboard,
  });

  if (isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600">Erreur: {(error as Error).message}</div>;
  const stats = dashboard?.stats || {} as any;

  const WeekActivityChart = () => {
    const chartData = useMemo(() => {
      // ✅ CORRECTION : Chercher dans stats.weekly_activity
      const weekly: any[] = stats?.weekly_activity || dashboard?.stats?.weekly_activity || [];
      
      console.log('📊 Weekly activity trouvé:', weekly);
      
      if (!Array.isArray(weekly) || weekly.length === 0) {
        console.warn('⚠️ Aucune donnée weekly_activity');
        return [];
      }
      
      return weekly.map((day: any) => ({
        date: day?.date ? new Date(day.date).toLocaleDateString('fr-FR', { 
          weekday: 'short', 
          day: '2-digit', 
          month: '2-digit' 
        }) : '',
        vues: day?.views || 0,
        téléchargements: day?.downloads || 0,
        'tentatives quiz': day?.quiz_attempts || 0,
      }));
    }, [dashboard, stats]); // ✅ Ajouter stats dans les dépendances

    console.log('📈 ChartData final:', chartData);

    if (chartData.length === 0) {
      return <div className="text-sm text-gray-600">Aucune activité cette semaine.</div>;
    }

    return (
      <div className="w-full h-[300px]">
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="date" tick={{ fontSize: 12 }} />
            <YAxis />
            <Tooltip />
            <Legend />
            <Line type="monotone" dataKey="vues" stroke="#3b82f6" strokeWidth={2} dot={{ r: 3 }} activeDot={{ r: 5 }} />
            <Line type="monotone" dataKey="téléchargements" stroke="#10b981" strokeWidth={2} dot={{ r: 3 }} activeDot={{ r: 5 }} />
            <Line type="monotone" dataKey="tentatives quiz" stroke="#f59e0b" strokeWidth={2} dot={{ r: 3 }} activeDot={{ r: 5 }} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard title="Matières assignées" value={stats.total_subjects || 0} icon={Library} color="primary" />
        <StatCard title="Documents" value={stats.total_documents || 0} icon={FileText} color="blue" />
        <StatCard title="Quiz" value={stats.total_quizzes || 0} icon={FileQuestion} color="purple" />
        <StatCard title="Étudiants" value={stats.total_students || 0} icon={Users} color="green" />
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-2">Activité de la semaine</h3>
        <WeekActivityChart />
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Performance par matière</h3>
        {Array.isArray((dashboard as any)?.subject_performance) && (dashboard as any).subject_performance.length > 0 ? (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {(dashboard as any).subject_performance.map((s: any) => (
              <div key={s.subject_id} className="border rounded-lg p-4">
                <div className="flex items-center justify-between mb-1">
                  <div className="font-semibold text-gray-900">{s.subject_name}</div>
                  <span className="text-xs text-gray-500">{s.subject_code}</span>
                </div>
                <div className="text-sm space-y-1 text-gray-700">
                  <div className="flex items-center justify-between"><span>Documents</span><span className="font-semibold">{s.document_count}</span></div>
                  <div className="flex items-center justify-between"><span>Quiz</span><span className="font-semibold">{s.quiz_count}</span></div>
                  <div className="flex items-center justify-between"><span>Étudiants</span><span className="font-semibold">{s.student_count}</span></div>
                </div>
                <div className="border-t my-3" />
                <div className="text-sm space-y-1">
                  <div className="flex items-center justify-between"><span>Score moyen</span><span className="font-semibold text-primary-600">{s.average_quiz_score}/20</span></div>
                  <div className="flex items-center justify-between"><span>Taux réussite</span><span className="font-semibold text-green-600">{s.quiz_pass_rate}%</span></div>
                </div>
                <Link to={`/teacher/subjects/${s.subject_id}`} className="mt-3 inline-flex w-full justify-center px-3 py-2 border rounded-lg text-primary-600 hover:bg-primary-50">
                  Gérer la matière
                </Link>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-gray-600">Aucune donnée de performance disponible.</p>
        )}
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <h3 className="text-lg font-semibold text-gray-900 mb-4">Activités récentes</h3>
        {Array.isArray((dashboard as any)?.recent_activities) && (dashboard as any).recent_activities.length > 0 ? (
          <div className="space-y-3">
            {(dashboard as any).recent_activities.slice(0, 10).map((a: any, idx: number) => (
              <div key={idx} className="flex items-start gap-3">
                <div className={`w-2 h-2 rounded-full mt-2 ${a.color === 'blue' ? 'bg-primary-500' : a.color === 'green' ? 'bg-green-500' : a.color === 'purple' ? 'bg-purple-500' : 'bg-gray-400'}`} />
                <div>
                  <div className="font-medium text-gray-900">{a.title}</div>
                  <div className="text-sm text-gray-600">{a.description}{a.subject_name ? ` • ${a.subject_name}` : ''}</div>
                  <div className="text-xs text-gray-500">{a.created_at ? new Date(a.created_at).toLocaleString() : ''}</div>
                </div>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-gray-600">Aucune activité récente.</p>
        )}
      </div>
    </div>
  );
}
