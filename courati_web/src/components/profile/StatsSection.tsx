import { useQuery } from '@tanstack/react-query';
import { profileAPI } from '../../api/profile';
import { BookOpen, ClipboardList, Download, Eye, FileText } from 'lucide-react';

function StatCard({ label, value, Icon, color }: { label: string; value: number; Icon: any; color: string }) {
  return (
    <div className="border border-gray-200 rounded-xl bg-white shadow-sm p-4 hover:shadow-md transition-shadow">
      <div className="flex items-center gap-3">
        <div className={`p-2 rounded-lg ${color}`}>
          <Icon className="w-5 h-5" />
        </div>
        <div>
          <div className="text-xs text-gray-500">{label}</div>
          <div className="text-xl font-semibold text-gray-900">{value}</div>
        </div>
      </div>
    </div>
  );
}

export default function StatsSection() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['profile-stats'],
    queryFn: profileAPI.getStats,
    staleTime: 2 * 60 * 1000,
  });

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} className="border border-gray-200 rounded-xl bg-white p-4 animate-pulse">
            <div className="h-5 w-24 bg-gray-200 rounded mb-2" />
            <div className="h-7 w-16 bg-gray-300 rounded" />
          </div>
        ))}
      </div>
    );
  }

  if (error || !data?.success) {
    return null;
  }

  const s = data.stats;
  return (
    <div className="grid grid-cols-1 md:grid-cols-3 lg:grid-cols-5 gap-4">
      <StatCard label="Documents" value={s.documents_count} Icon={FileText} color="bg-blue-50 text-blue-600" />
      <StatCard label="Quiz" value={s.quizzes_count} Icon={ClipboardList} color="bg-purple-50 text-purple-600" />
      <StatCard label="Matières" value={s.subjects_count} Icon={BookOpen} color="bg-amber-50 text-amber-600" />
      <StatCard label="Vues" value={s.total_views} Icon={Eye} color="bg-green-50 text-green-600" />
      <StatCard label="Téléchargements" value={s.total_downloads} Icon={Download} color="bg-pink-50 text-pink-600" />
    </div>
  );
}
