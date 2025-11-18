import { useQuery } from '@tanstack/react-query';
import { teacherAPI } from '../../api/teacher';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useNavigate } from 'react-router-dom';

export default function TeacherSubjectsPage() {
  const navigate = useNavigate();
  const { data, isLoading, error } = useQuery({
    queryKey: ['teacher_subjects'],
    queryFn: teacherAPI.getMySubjects,
  });
  const subjects = Array.isArray(data) ? data : (data?.subjects || []);

  console.log('📊 Données matières:', data);
  console.log('📊 Subjects:', subjects);

  if (isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600">Erreur: {(error as Error).message}</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Mes Matières</h1>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {Array.isArray(subjects) && subjects.length > 0 ? subjects.map((item: any) => {
          const subject = item?.subject || item;
          console.log('📋 Item matière:', item);
          const stats = item?.statistics || item?.stats || {};
          console.log('📊 Stats extraites:', stats);
          return (
          <div key={subject.id} className="bg-white border border-gray-200 rounded-xl p-6 hover:shadow-sm transition">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-lg font-semibold text-gray-900">{subject.name}</h3>
              <span className="text-sm text-gray-500">{subject.code}</span>
            </div>
            <div className="text-sm text-gray-600 mb-4">
              {(subject.levels || subject.level_list || []).map((l: any, idx: number) => (
                <span key={idx} className="inline-block mr-2 mb-2 px-2 py-1 rounded bg-gray-100 text-gray-700 text-xs">
                  {typeof l === 'string' ? l : (l?.name || l?.code || l)}
                </span>
              ))}
            </div>
            <div className="flex items-center justify-between text-sm text-gray-600 mb-4">
              <span><strong>{stats.total_documents ?? stats.document_count ?? subject.documents_count ?? 0}</strong> docs</span>
              <span><strong>{stats.total_quizzes ?? stats.quiz_count ?? subject.quizzes_count ?? 0}</strong> quiz</span>
              <span><strong>{stats.total_students ?? stats.student_count ?? subject.students_count ?? 0}</strong> étudiants</span>
            </div>
            <div className="flex items-center justify-end">
              <button
                onClick={() => navigate(`/teacher/subjects/${subject.id}`)}
                className="px-3 py-2 text-primary-600 hover:bg-primary-50 rounded-lg transition-colors"
              >
                Gérer matière
              </button>
            </div>
          </div>
          );
        }) : (
          <div className="bg-white rounded-xl border border-gray-200 p-12 text-center col-span-full">
            Aucune matière trouvée.
          </div>
        )}
      </div>
    </div>
  );
}

