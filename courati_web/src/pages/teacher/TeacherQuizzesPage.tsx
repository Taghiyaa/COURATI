import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { teacherQuizzesAPI } from '../../api/teacherQuizzes';
import { teacherAPI } from '../../api/teacher';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { Eye, BarChart2, Pencil, Trash2 } from 'lucide-react';
import { toast } from 'sonner';

export default function TeacherQuizzesPage() {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [subjectFilter, setSubjectFilter] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('');

  const { data: subjectsData } = useQuery({
    queryKey: ['teacher_subjects'],
    queryFn: teacherAPI.getMySubjects,
  });

  const subjectsArray: any[] = Array.isArray(subjectsData)
    ? subjectsData
    : (subjectsData?.subjects || []);

  const subjectOptions = subjectsArray.map((item: any) => {
    const s = item?.subject || item;
    return { id: s?.id, name: s?.name };
  }).filter((s: any) => s?.id);

  const { data: response, isLoading, error } = useQuery({
    queryKey: ['teacher_quizzes', search, subjectFilter, statusFilter],
    queryFn: () => teacherQuizzesAPI.getAll({
      search: search || undefined,
      subject: subjectFilter ? Number(subjectFilter) : undefined,
      is_active: statusFilter === 'active' ? true : statusFilter === 'inactive' ? false : undefined,
    }),
  });

  const queryClient = useQueryClient();
  const deleteMutation = useMutation({
    mutationFn: (quizId: number) => teacherQuizzesAPI.delete(quizId),
    onSuccess: () => {
      toast.success('Quiz supprimé avec succès');
      queryClient.invalidateQueries({ queryKey: ['teacher_quizzes'] });
    },
    onError: (error: any) => {
      toast.error(error?.response?.data?.error || 'Erreur lors de la suppression');
    },
  });

  const handleDelete = (quiz: any) => {
    if (!window.confirm(`Voulez-vous vraiment supprimer le quiz "${quiz.title}" ?\n\nCette action est irréversible.`)) return;
    deleteMutation.mutate(quiz.id);
  };

  const quizzes: any[] = Array.isArray(response)
    ? response
    : (response?.quizzes || []);

  if (isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600">Erreur: {(error as Error).message}</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Mes Quiz</h1>
        <button onClick={() => navigate('/teacher/quizzes/create')} className="px-3 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600">Créer un quiz</button>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-4 space-y-3">
        <div className="flex flex-wrap items-center gap-3">
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Rechercher un quiz..."
            className="flex-1 min-w-[240px] px-3 py-2 border rounded"
          />
          <select
            value={subjectFilter}
            onChange={(e) => setSubjectFilter(e.target.value)}
            className="px-3 py-2 border rounded min-w-[200px]"
          >
            <option value="">Toutes les matières</option>
            {subjectOptions.map((s: any) => (
              <option key={s.id} value={s.id}>{s.name}</option>
            ))}
          </select>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="px-3 py-2 border rounded min-w-[160px]"
          >
            <option value="">Tous les statuts</option>
            <option value="active">Actif</option>
            <option value="inactive">Inactif</option>
          </select>
          <span className="ml-auto text-sm text-gray-600">{quizzes.length} résultat(s)</span>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              <th className="text-left py-3 px-4 text-sm text-gray-600">Titre</th>
              <th className="text-left py-3 px-4 text-sm text-gray-600">Matière</th>
              <th className="text-center py-3 px-4 text-sm text-gray-600">Questions</th>
              <th className="text-center py-3 px-4 text-sm text-gray-600">Durée</th>
              <th className="text-center py-3 px-4 text-sm text-gray-600">Tentatives</th>
              <th className="text-center py-3 px-4 text-sm text-gray-600">Statut</th>
              <th className="text-right py-3 px-4 text-sm text-gray-600">Actions</th>
            </tr>
          </thead>
          <tbody>
            {quizzes.length > 0 ? quizzes.map((q: any) => (
              <tr key={q.id} className="border-t">
                <td className="py-3 px-4">
                  <div className="font-medium text-gray-900">{q.title}</div>
                  {q.description && <div className="text-xs text-gray-600">{q.description}</div>}
                </td>
                <td className="py-3 px-4">{q.subject?.name || q.subject_name || '-'}</td>
                <td className="py-3 px-4 text-center">{q.question_count ?? q.questions_count ?? (q.questions?.length ?? 0)}</td>
                <td className="py-3 px-4 text-center">{q.duration_minutes ?? q.duration ?? '-'} min</td>
                <td className="py-3 px-4 text-center">{q.total_attempts ?? 0}</td>
                <td className="py-3 px-4 text-center">
                  <span className={`text-xs px-2 py-1 rounded-full border ${q.is_active ? 'bg-green-50 text-green-700 border-green-200' : 'bg-gray-50 text-gray-700 border-gray-200'}`}>
                    {q.is_active ? 'Actif' : 'Inactif'}
                  </span>
                </td>
                <td className="py-3 px-4 text-right">
                  <div className="flex items-center gap-1 justify-end">
                    {/* ✅ Bouton Voir : ouvre l'onglet Informations */}
                    <button 
                      onClick={() => navigate(`/teacher/quizzes/${q.id}`, { state: { tab: 0 } })} 
                      className="p-1 rounded hover:bg-gray-50" 
                      title="Voir détails"
                    >
                      <Eye className="w-4 h-4 text-primary-600" />
                    </button>
                    
                    {/* ✅ Bouton Tentatives : ouvre l'onglet Tentatives */}
                    <button 
                      onClick={() => navigate(`/teacher/quizzes/${q.id}`, { state: { tab: 1 } })} 
                      className="p-1 rounded hover:bg-gray-50" 
                      title="Voir tentatives"
                    >
                      <BarChart2 className="w-4 h-4 text-gray-700" />
                    </button>
                    
                    <button onClick={() => navigate(`/teacher/quizzes/${q.id}/edit`)} className="p-1 rounded hover:bg-gray-50" title="Modifier">
                      <Pencil className="w-4 h-4 text-gray-700" />
                    </button>
                    <button onClick={() => handleDelete(q)} disabled={deleteMutation.isPending} className="p-1 rounded hover:bg-gray-50 disabled:opacity-50" title="Supprimer">
                      <Trash2 className="w-4 h-4 text-red-600" />
                    </button>
                  </div>
                </td>
              </tr>
            )) : (
              <tr>
                <td colSpan={7} className="py-6 text-center text-gray-600">
                  {search || subjectFilter || statusFilter ? 'Aucun quiz trouvé pour ces critères' : 'Aucun quiz.'}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}