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

  if (isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600">Erreur: {(error as Error).message}</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Mes Matières</h1>
      </div>

      <div className="space-y-6">
        {Array.isArray(subjects) && subjects.length > 0 ? subjects.map((item: any) => {
          const subject = item?.subject || item;
          const stats = item?.statistics || item?.stats || {};

          return (
            <div
              key={subject.id}
              className="bg-white border border-gray-200 rounded-2xl p-5 shadow-sm hover:shadow-md transition-all"
            >
              {/* 🟦 Ligne supérieure : Icon + Nom + Code + Bouton */}
              <div className="flex items-center gap-5">
                
                {/* Icône */}
                <div className="w-16 h-16 rounded-xl flex-shrink-0 bg-gradient-to-br from-primary-500 to-primary-600 text-white flex items-center justify-center font-semibold shadow">
                  {(subject.code || 'S').slice(0, 2).toUpperCase()}
                </div>

                {/* Informations */}
                <div className="flex-1 min-w-0">
                  <div className="text-gray-900 font-semibold text-xl truncate">
                    {subject.name}
                  </div>
                  <div className="text-gray-600 text-sm">{subject.code}</div>

                  {/* Niveaux + Filières */}
                  <div className="mt-2 flex flex-wrap gap-2">
                    {(subject.levels || subject.level_list || []).map((l: any, idx: number) => (
                      <span
                        key={idx}
                        className="px-2 py-1 rounded-full text-xs bg-blue-50 text-blue-700 border border-blue-200"
                      >
                        {typeof l === 'string' ? l : (l?.name || l?.code || l)}
                      </span>
                    ))}

                    {(subject.majors || subject.major_list || []).map((m: any, idx: number) => (
                      <span
                        key={`m-${idx}`}
                        className="px-2 py-1 rounded-full text-xs bg-purple-50 text-purple-700 border border-purple-200"
                      >
                        {typeof m === 'string' ? m : (m?.name || m?.code || m)}
                      </span>
                    ))}
                  </div>
                </div>

                {/* Bouton */}
                <button
                  onClick={() => navigate(`/teacher/subjects/${subject.id}`)}
                  className="flex-shrink-0 inline-flex items-center gap-2 px-4 py-2 rounded-lg bg-primary-50 text-primary-700 hover:bg-primary-100 border border-primary-200 transition-colors"
                >
                  Gérer la matière
                </button>
              </div>

              {/* 🟧 Ligne inférieure : Stats alignés horizontalement */}
              <div className="mt-5 flex gap-4">
                {/* CARD STAT 1 */}
                <div className="flex-1 rounded-xl border border-gray-200 bg-gray-50 p-4 text-center">
                  <div className="text-gray-900 text-xl font-bold">
                    {stats.total_documents ?? stats.document_count ?? subject.documents_count ?? 0}
                  </div>
                  <div className="text-gray-600 text-xs mt-1">Documents</div>
                </div>

                {/* CARD STAT 2 */}
                <div className="flex-1 rounded-xl border border-gray-200 bg-gray-50 p-4 text-center">
                  <div className="text-gray-900 text-xl font-bold">
                    {stats.total_quizzes ?? stats.quiz_count ?? subject.quizzes_count ?? 0}
                  </div>
                  <div className="text-gray-600 text-xs mt-1">Quiz</div>
                </div>

                {/* CARD STAT 3 */}
                <div className="flex-1 rounded-xl border border-gray-200 bg-gray-50 p-4 text-center">
                  <div className="text-gray-900 text-xl font-bold">
                    {stats.total_students ?? stats.student_count ?? subject.students_count ?? 0}
                  </div>
                  <div className="text-gray-600 text-xs mt-1">Étudiants</div>
                </div>
              </div>
            </div>
          );
        }) : (
          <div className="bg-white rounded-xl border border-gray-200 p-12 text-center">
            Aucune matière trouvée.
          </div>
        )}
      </div>
    </div>
  );
}
