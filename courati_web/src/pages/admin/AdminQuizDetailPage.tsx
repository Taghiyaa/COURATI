import { useMemo } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { adminQuizzesAPI } from '../../api/adminQuizzes';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { toast } from 'sonner';
import { Eye, Pencil, ToggleLeft, ToggleRight, Trash2 } from 'lucide-react';

function StatCard({ label, value, accent }: { label: string; value: string | number; accent?: string }) {
  return (
    <div className="bg-white rounded-xl border p-4">
      <div className="text-sm text-gray-600">{label}</div>
      <div className={`text-2xl font-semibold ${accent || ''}`}>{value}</div>
    </div>
  );
}

export default function AdminQuizDetailPage() {
  const { id } = useParams();
  const quizId = Number(id);
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ['admin_quiz_detail', quizId],
    queryFn: () => adminQuizzesAPI.getById(quizId),
    enabled: Number.isFinite(quizId) && quizId > 0,
  });

  const quiz: any = (data as any)?.quiz || data;

  const toggleMutation = useMutation({
    mutationFn: () => adminQuizzesAPI.toggleActive(quizId),
    onSuccess: (resp: any) => {
      toast.success('Statut modifié');
      queryClient.invalidateQueries({ queryKey: ['admin_quiz_detail', quizId] });
      queryClient.invalidateQueries({ queryKey: ['admin_quizzes'] });
    },
    onError: (e: any) => toast.error(e?.response?.data?.error || 'Erreur toggle'),
  });

  const deleteMutation = useMutation({
    mutationFn: () => adminQuizzesAPI.delete(quizId),
    onSuccess: () => {
      toast.success('Quiz supprimé');
      queryClient.invalidateQueries({ queryKey: ['admin_quizzes'] });
      navigate('/admin/quizzes');
    },
    onError: (error: any) => {
      const message = error?.response?.data?.error || 'Erreur lors de la suppression';
      const suggestion = error?.response?.data?.suggestion;
      if (suggestion) toast.error(`${message}\n${suggestion}`);
      else toast.error(message);
    },
  });

  const totalPoints = useMemo(() => {
    const arr = quiz?.questions || [];
    return arr.reduce((sum: number, q: any) => sum + (Number(q.points) || 0), 0);
  }, [quiz]);

  if (!Number.isFinite(quizId) || quizId <= 0) {
    return <div className="text-red-600 p-6">Identifiant invalide</div>;
  }

  if (isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600 p-6">Erreur: {(error as Error).message}</div>;
  if (!quiz) return <div className="p-6">Quiz introuvable</div>;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{quiz.title || 'Quiz'}</h1>
          <p className="text-gray-600 mt-1">{quiz.subject_name || '-'} • {quiz.subject_code || ''}</p>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => navigate(`/admin/quizzes/${quizId}/edit`)} className="px-3 py-2 border rounded-lg hover:bg-gray-50 inline-flex items-center gap-2"><Pencil className="w-4 h-4" /> Modifier</button>
          <button onClick={() => toggleMutation.mutate()} disabled={toggleMutation.isPending} className={`inline-flex items-center gap-2 px-3 py-2 border rounded-lg ${quiz.is_active ? 'border-amber-300 text-amber-700 hover:bg-amber-50' : 'border-green-300 text-green-700 hover:bg-green-50'}`}>
            {quiz.is_active ? <><ToggleLeft className="w-4 h-4" /> Désactiver</> : <><ToggleRight className="w-4 h-4" /> Activer</>}
          </button>
          <button onClick={() => { if (confirm('Supprimer ce quiz ?')) deleteMutation.mutate(); }} disabled={deleteMutation.isPending} className="px-3 py-2 border border-red-300 rounded-lg text-red-700 hover:bg-red-50 disabled:opacity-50 inline-flex items-center gap-2"><Trash2 className="w-4 h-4" /> Supprimer</button>
        </div>
      </div>

      {/* Info + Stats */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Infos */}
        <div className="lg:col-span-2 bg-white rounded-xl border p-6 space-y-3">
          <div className="text-sm"><span className="text-gray-600">Matière:</span> <span className="font-medium text-gray-900">{quiz.subject_name || '-'}</span></div>
          <div className="text-sm"><span className="text-gray-600">Code:</span> <span className="font-medium text-gray-900">{quiz.subject_code || '-'}</span></div>
          <div className="text-sm"><span className="text-gray-600">Créé par:</span> <span className="font-medium text-gray-900">{quiz.created_by_name || '-'}</span></div>
          <div className="text-sm"><span className="text-gray-600">Durée:</span> <span className="font-medium text-gray-900">{quiz.duration_minutes ?? '-'} min</span></div>
          <div className="text-sm"><span className="text-gray-600">Note de passage:</span> <span className="font-medium text-gray-900">{quiz.passing_percentage ?? '-'}%</span></div>
          <div className="text-sm"><span className="text-gray-600">Tentatives max:</span> <span className="font-medium text-gray-900">{quiz.max_attempts == null ? 'Illimité' : quiz.max_attempts}</span></div>
          <div className="text-sm"><span className="text-gray-600">Disponibilité:</span> <span className="font-medium text-gray-900">{quiz.available_from ? new Date(quiz.available_from).toLocaleString('fr-FR') : '-'} → {quiz.available_until ? new Date(quiz.available_until).toLocaleString('fr-FR') : '-'}</span></div>
          <div className="text-sm"><span className="text-gray-600">Créé le:</span> <span className="font-medium text-gray-900">{quiz.created_at ? new Date(quiz.created_at).toLocaleString('fr-FR') : '-'}</span></div>
          <div className="text-sm"><span className="text-gray-600">Modifié le:</span> <span className="font-medium text-gray-900">{quiz.updated_at ? new Date(quiz.updated_at).toLocaleString('fr-FR') : '-'}</span></div>
        </div>

        {/* Stats */}
        <div className="space-y-4">
          <StatCard label="Questions" value={quiz.question_count ?? (quiz.questions?.length ?? 0)} />
          <StatCard label="Total points" value={quiz.total_points ?? totalPoints} />
          <StatCard label="Tentatives" value={quiz.total_attempts ?? 0} />
          <StatCard label="Terminées" value={quiz.completed_attempts ?? 0} />
          <StatCard label="Score moyen (/20)" value={quiz.average_score ?? '-'} />
          <StatCard label="Taux de réussite (%)" value={quiz.pass_rate ?? '-'} />
        </div>
      </div>

      {/* Questions */}
      <div className="bg-white rounded-xl border p-6 space-y-4">
        <div className="text-lg font-semibold">Questions</div>
        {(quiz.questions || []).map((q: any, idx: number) => (
          <div key={q.id || idx} className="border rounded p-4 space-y-2">
            <div className="flex items-center justify-between">
              <div className="font-medium">Q{idx + 1} • {q.question_type} • {q.points} pts</div>
            </div>
            <div className="text-gray-800">{q.text || '-'}</div>
            {q.explanation && <div className="text-sm text-gray-600">Explication: {q.explanation}</div>}
            <div className="space-y-1">
              {(q.choices || []).map((c: any, i: number) => (
                <div key={c.id || i} className="text-sm">
                  <span className={`inline-block w-2 h-2 rounded-full mr-2 ${c.is_correct ? 'bg-green-500' : 'bg-gray-300'}`} />
                  {c.text || `Choix ${i + 1}`} {c.is_correct && <span className="text-green-700">(✓)</span>}
                </div>
              ))}
            </div>
          </div>
        ))}
        {(quiz.questions || []).length === 0 && (
          <div className="text-gray-600">Aucune question.</div>
        )}
      </div>

      {/* Actions */}
      <div className="flex items-center justify-end gap-2">
        <button onClick={() => navigate(`/admin/quizzes/${quizId}/edit`)} className="px-3 py-2 border rounded-lg hover:bg-gray-50 inline-flex items-center gap-2"><Pencil className="w-4 h-4" /> Modifier</button>
        <button onClick={() => toggleMutation.mutate()} disabled={toggleMutation.isPending} className={`inline-flex items-center gap-2 px-3 py-2 border rounded-lg ${quiz.is_active ? 'border-amber-300 text-amber-700 hover:bg-amber-50' : 'border-green-300 text-green-700 hover:bg-green-50'}`}>
          {quiz.is_active ? <><ToggleLeft className="w-4 h-4" /> Désactiver</> : <><ToggleRight className="w-4 h-4" /> Activer</>}
        </button>
        <button onClick={() => { if (confirm('Supprimer ce quiz ?')) deleteMutation.mutate(); }} disabled={deleteMutation.isPending} className="px-3 py-2 border border-red-300 rounded-lg text-red-700 hover:bg-red-50 disabled:opacity-50 inline-flex items-center gap-2"><Trash2 className="w-4 h-4" /> Supprimer</button>
      </div>
    </div>
  );
}
