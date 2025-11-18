import { useMemo, useState } from 'react';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { teacherQuizzesAPI } from '../../api/teacherQuizzes';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { toast } from 'sonner';

export default function TeacherQuizDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const location = useLocation() as any;
  const quizId = Number(id);

  // ✅ TOUS LES HOOKS EN PREMIER
  const initialTab = (location?.state && typeof location.state.tab === 'number') ? location.state.tab : 0;
  const [currentTab, setCurrentTab] = useState<0 | 1 | 2>(initialTab);
  const [statusFilter, setStatusFilter] = useState<string>('');
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [selectedAttempt, setSelectedAttempt] = useState<any | null>(null);

  const { data: quiz, isLoading, error } = useQuery({
    queryKey: ['teacher_quiz', quizId],
    queryFn: () => teacherQuizzesAPI.getById(quizId),
    enabled: Number.isFinite(quizId) && quizId > 0,
  });

  const { data: attempts, isLoading: attemptsLoading, error: attemptsError } = useQuery({
    queryKey: ['teacher_quiz_attempts', quizId, statusFilter],
    queryFn: () => teacherQuizzesAPI.getAttempts(quizId, { status: statusFilter || undefined }),
    enabled: Number.isFinite(quizId) && quizId > 0 && (currentTab === 1 || currentTab === 2),
  });

  const queryClient = useQueryClient();
  const deleteMutation = useMutation({
    mutationFn: () => teacherQuizzesAPI.delete(quizId),
    onSuccess: () => {
      toast.success('Quiz supprimé avec succès');
      queryClient.invalidateQueries({ queryKey: ['teacher_quizzes'] });
      navigate('/teacher/quizzes');
    },
    onError: (error: any) => {
      toast.error(error?.response?.data?.error || 'Erreur lors de la suppression');
    },
  });

  const handleDelete = () => {
    if (!quiz) return;
    if (!window.confirm(`Voulez-vous vraiment supprimer le quiz "${quiz.title}" ?\n\nCette action est irréversible.`)) return;
    deleteMutation.mutate();
  };

  // ✅ useMemo TOUJOURS appelé (même si quiz est null)
  const attemptsArray: any[] = useMemo(() => {
    if (!attempts) return [];
    if (Array.isArray(attempts)) return attempts;
    if (attempts.attempts) return attempts.attempts;
    if (attempts.results) return attempts.results;
    return [];
  }, [attempts]);

  const getQuestionCount = (q: any) => q?.questions_count ?? q?.question_count ?? q?.questions?.length ?? 0;
  const durationMinutes = quiz?.duration_minutes ?? quiz?.duration ?? 0;
  const passingPct = quiz?.passing_percentage ?? quiz?.passing_percent ?? 0;

  const normalizeAttempt = (a: any) => {
    const score = a?.score_percentage ?? a?.score ?? a?.final_score ?? a?.grade ?? null;
    const startedAt = a?.started_at ?? a?.created_at ?? null;
    const completedAt = a?.completed_at ?? a?.finished_at ?? null;
    const durationSec = a?.duration_seconds ?? a?.time_spent_seconds ?? (startedAt && completedAt ? Math.max(0, (new Date(completedAt).getTime() - new Date(startedAt).getTime()) / 1000) : null);
    const status = a?.status ?? (completedAt ? 'COMPLETED' : 'IN_PROGRESS');
    const name = a?.student_name || a?.student?.full_name || [a?.student?.first_name, a?.student?.last_name].filter(Boolean).join(' ') || a?.student_full_name || 'Étudiant';
    const email = a?.student_email || a?.student?.email || '';
    const passed = a?.passed ?? a?.is_passed ?? (score != null && passingPct ? Number(score) >= Number(passingPct) : null);
    
    return { 
      ...a, 
      _score: score, 
      _startedAt: startedAt, 
      _completedAt: completedAt, 
      _durationSec: durationSec, 
      _status: status, 
      _name: name, 
      _email: email, 
      _passed: passed 
    };
  };

  const normalized = useMemo(() => attemptsArray.map(normalizeAttempt), [attemptsArray, passingPct]);

  const filtered = useMemo(() => {
    return normalized.filter((a) => {
      const t = searchTerm.trim().toLowerCase();
      if (!t) return true;
      return a._name.toLowerCase().includes(t) || (a._email || '').toLowerCase().includes(t);
    });
  }, [normalized, searchTerm]);

  const totalAttempts = normalized.length;
  const completedCount = normalized.filter(a => a._status === 'COMPLETED').length;
  const avgScore = normalized.length 
    ? Math.round((normalized.map(a => Number(a._score ?? 0)).reduce((s, v) => s + v, 0) / normalized.length) * 10) / 10 
    : 0;
  const passCount = normalized.filter(a => a._passed === true).length;
  const passRate = totalAttempts ? Math.round((passCount / totalAttempts) * 100) : 0;
  const bestScore = normalized.length ? Math.max(...normalized.map(a => Number(a._score ?? 0))) : 0;
  const worstScore = normalized.length ? Math.min(...normalized.map(a => Number(a._score ?? 0))) : 0;

  const formatDate = (d?: string | null) => d ? new Date(d).toLocaleString('fr-FR') : '-';
  
  const formatDuration = (sec?: number | null) => {
    if (sec == null) return '-';
    const s = Math.floor(sec % 60);
    const m = Math.floor((sec / 60) % 60);
    const h = Math.floor(sec / 3600);
    return h > 0 ? `${h}h ${m}m ${s}s` : `${m}m ${s}s`;
  };

  // ✅ APRÈS tous les hooks, les conditions de rendu
  if (!Number.isFinite(quizId) || quizId <= 0) {
    return <div className="p-6 text-red-600">Identifiant quiz invalide</div>;
  }
  
  if (isLoading) {
    return <LoadingSpinner />;
  }
  
  if (error || !quiz) {
    return <div className="p-6 text-red-600">Erreur: {error ? (error as Error).message : 'Quiz introuvable'}</div>;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <div className="flex items-start justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{quiz?.title || 'Détail du Quiz'}</h1>
            <p className="text-gray-600">
              {(quiz?.subject_name || quiz?.subject?.name || '-')}
              {' • '}{getQuestionCount(quiz)} questions
              {' • '}{durationMinutes} min
            </p>
          </div>
          <div className="flex items-center gap-2">
            <span className={`text-xs px-2 py-1 rounded-full border ${quiz?.is_active ? 'bg-green-50 text-green-700 border-green-200' : 'bg-gray-50 text-gray-700 border-gray-200'}`}>
              {quiz?.is_active ? 'Actif' : 'Inactif'}
            </span>
            <button onClick={() => navigate(`/teacher/quizzes/${quizId}/edit`)} className="px-3 py-2 border rounded-lg text-gray-700 hover:bg-gray-50">Modifier</button>
            <button onClick={handleDelete} disabled={deleteMutation.isPending} className="px-3 py-2 border border-red-300 rounded-lg text-red-700 hover:bg-red-50 disabled:opacity-50">{deleteMutation.isPending ? 'Suppression...' : 'Supprimer'}</button>
          </div>
        </div>
        <div className="mt-2 flex flex-wrap gap-2 text-sm text-gray-700">
          <span className="px-2 py-1 rounded bg-primary-50 text-primary-700 border border-primary-200">
            Passage: {passingPct}%
          </span>
          {quiz?.max_attempts != null && (
            <span className="px-2 py-1 rounded bg-gray-50 text-gray-700 border">
              Max tentatives: {quiz.max_attempts}
            </span>
          )}
          {quiz?.total_points != null && (
            <span className="px-2 py-1 rounded bg-purple-50 text-purple-700 border border-purple-200">
              Points: {quiz.total_points}
            </span>
          )}
        </div>
      </div>

      {/* Tabs */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="flex border-b border-gray-200">
          {['Informations', 'Tentatives', 'Statistiques'].map((label, idx) => (
            <button 
              key={label} 
              onClick={() => setCurrentTab(idx as any)} 
              className={`px-4 py-3 text-sm font-medium border-b-2 ${
                currentTab === idx 
                  ? 'border-primary-500 text-primary-600' 
                  : 'border-transparent text-gray-600 hover:text-gray-800'
              }`}
            >
              {label}
            </button>
          ))}
        </div>

        {/* Onglet 0: Informations */}
        {currentTab === 0 && (
          <div className="p-6 space-y-4">
            <h3 className="text-lg font-semibold text-gray-900">Informations générales</h3>
            
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Durée</div>
                <div className="text-lg font-semibold">{durationMinutes} minutes</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Note de passage</div>
                <div className="text-lg font-semibold">{passingPct}%</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Nombre de questions</div>
                <div className="text-lg font-semibold">{getQuestionCount(quiz)}</div>
              </div>
            </div>

            {quiz?.questions && quiz.questions.length > 0 && (
              <div>
                <h4 className="font-medium text-gray-900 mb-3">Questions ({quiz.questions.length})</h4>
                <div className="space-y-3">
                  {quiz.questions.map((q: any, idx: number) => (
                    <div key={q.id || idx} className="p-4 border rounded-lg">
                      <div className="flex items-start justify-between mb-2">
                        <div className="font-medium text-gray-900">
                          Question {idx + 1} • {q.question_type || 'QCM'}
                        </div>
                        <span className="text-xs px-2 py-1 bg-primary-50 text-primary-700 rounded">
                          {q.points || 1} pts
                        </span>
                      </div>
                      <div className="text-gray-700 mb-2">{q.text || q.question_text}</div>
                      {q.choices && q.choices.length > 0 && (
                        <div className="ml-4 space-y-1">
                          {q.choices.map((choice: any, cIdx: number) => (
                            <div 
                              key={choice.id || cIdx} 
                              className={`text-sm ${choice.is_correct ? 'text-green-700 font-medium' : 'text-gray-600'}`}
                            >
                              {String.fromCharCode(65 + cIdx)}. {choice.text}
                              {choice.is_correct && ' ✓'}
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        )}

        {/* Onglet 1: Tentatives */}
        {currentTab === 1 && (
          <div className="p-6 space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Total tentatives</div>
                <div className="text-2xl font-bold">{totalAttempts}</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Terminées</div>
                <div className="text-2xl font-bold">{completedCount}</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Score moyen</div>
                <div className="text-2xl font-bold">{avgScore}%</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Taux de réussite</div>
                <div className="text-2xl font-bold">{passRate}%</div>
              </div>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <input 
                className="flex-1 min-w-[240px] px-3 py-2 border rounded" 
                placeholder="Rechercher étudiant..." 
                value={searchTerm} 
                onChange={(e) => setSearchTerm(e.target.value)} 
              />
              <select 
                className="px-3 py-2 border rounded min-w-[200px]" 
                value={statusFilter} 
                onChange={(e) => setStatusFilter(e.target.value)}
              >
                <option value="">Tous les statuts</option>
                <option value="COMPLETED">Terminée</option>
                <option value="IN_PROGRESS">En cours</option>
              </select>
            </div>

            <div className="overflow-x-auto border rounded-lg">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="text-left py-3 px-4 text-sm text-gray-600">Étudiant</th>
                    <th className="text-center py-3 px-4 text-sm text-gray-600">Statut</th>
                    <th className="text-center py-3 px-4 text-sm text-gray-600">Score</th>
                    <th className="text-center py-3 px-4 text-sm text-gray-600">Début</th>
                    <th className="text-center py-3 px-4 text-sm text-gray-600">Fin</th>
                    <th className="text-center py-3 px-4 text-sm text-gray-600">Durée</th>
                    <th className="text-right py-3 px-4 text-sm text-gray-600">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {attemptsLoading ? (
                    <tr><td className="py-6 px-4 text-center" colSpan={7}>Chargement...</td></tr>
                  ) : attemptsError ? (
                    <tr><td className="py-6 px-4 text-center text-red-600" colSpan={7}>Erreur lors du chargement</td></tr>
                  ) : filtered.length > 0 ? (
                    filtered.map((a: any) => (
                      <tr key={a.id} className="border-t hover:bg-gray-50">
                        <td className="py-3 px-4">
                          <div className="font-medium text-gray-900">{a._name}</div>
                          <div className="text-sm text-gray-600">{a._email || '-'}</div>
                        </td>
                        <td className="py-3 px-4 text-center">
                          <span className={`text-xs px-2 py-1 rounded-full border ${
                            a._status === 'COMPLETED' 
                              ? 'bg-green-50 text-green-700 border-green-200' 
                              : 'bg-gray-50 text-gray-700 border-gray-200'
                          }`}>
                            {a._status === 'COMPLETED' ? 'Complété' : a._status}
                          </span>
                        </td>
                        <td className="py-3 px-4 text-center font-semibold">
                          {a._score != null ? `${a._score}%` : '-'}
                        </td>
                        <td className="py-3 px-4 text-center text-sm">{formatDate(a._startedAt)}</td>
                        <td className="py-3 px-4 text-center text-sm">{formatDate(a._completedAt)}</td>
                        <td className="py-3 px-4 text-center text-sm">{formatDuration(a._durationSec)}</td>
                        <td className="py-3 px-4 text-right">
                          <button 
                            onClick={() => setSelectedAttempt(a)} 
                            className="px-3 py-1 text-sm text-primary-600 hover:bg-primary-50 rounded"
                          >
                            Détails
                          </button>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr><td className="py-6 px-4 text-center text-gray-600" colSpan={7}>Aucune tentative trouvée</td></tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        )}

        {/* Onglet 2: Statistiques */}
        {currentTab === 2 && (
          <div className="p-6 space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Score moyen</div>
                <div className="text-2xl font-bold">{avgScore}%</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Meilleur score</div>
                <div className="text-2xl font-bold text-green-600">{bestScore}%</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Score le plus faible</div>
                <div className="text-2xl font-bold text-red-600">{worstScore}%</div>
              </div>
              <div className="p-4 border rounded-lg">
                <div className="text-sm text-gray-600">Taux de réussite</div>
                <div className="text-2xl font-bold">{passRate}%</div>
              </div>
            </div>

            {normalized.length > 0 ? (
              <div className="space-y-3">
                <h4 className="text-sm font-medium text-gray-900">Distribution des scores</h4>
                {(() => {
                  const buckets = [
                    { label: '0-25%', min: 0, max: 25 },
                    { label: '25-50%', min: 25, max: 50 },
                    { label: '50-75%', min: 50, max: 75 },
                    { label: '75-100%', min: 75, max: 100 },
                  ];
                  const counts = buckets.map(b => 
                    normalized.filter(a => {
                      const score = Number(a._score ?? -1);
                      return score >= b.min && (score < b.max || (b.max === 100 && score <= 100));
                    }).length
                  );
                  const maxCount = Math.max(1, ...counts);
                  
                  return (
                    <div className="space-y-2">
                      {buckets.map((b, i) => (
                        <div key={b.label} className="flex items-center gap-3">
                          <div className="w-24 text-sm text-gray-600">{b.label}</div>
                          <div className="flex-1 h-8 bg-gray-100 rounded overflow-hidden">
                            <div 
                              className="h-8 bg-primary-500 flex items-center justify-end pr-2"
                              style={{ width: `${(counts[i] / maxCount) * 100}%` }}
                            >
                              {counts[i] > 0 && (
                                <span className="text-xs font-medium text-white">{counts[i]}</span>
                              )}
                            </div>
                          </div>
                          <div className="w-12 text-sm text-gray-700 text-right font-medium">{counts[i]}</div>
                        </div>
                      ))}
                    </div>
                  );
                })()}
              </div>
            ) : (
              <div className="text-center py-8 text-gray-600">
                Aucune donnée disponible pour afficher les statistiques
              </div>
            )}
          </div>
        )}
      </div>

      {/* Modal */}
      {selectedAttempt && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-xl w-full max-w-3xl overflow-hidden">
            <div className="px-6 py-4 border-b flex items-center justify-between">
              <h3 className="font-semibold text-gray-900">Détail de la tentative — {selectedAttempt._name}</h3>
              <button onClick={() => setSelectedAttempt(null)} className="text-gray-500 hover:text-gray-700 text-2xl">✕</button>
            </div>
            <div className="p-6 space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 border rounded-lg">
                  <div className="text-sm text-gray-600">Score</div>
                  <div className="text-2xl font-semibold">{selectedAttempt._score != null ? `${selectedAttempt._score}%` : '-'}</div>
                </div>
                <div className="p-4 border rounded-lg">
                  <div className="text-sm text-gray-600">Statut</div>
                  <div className="text-lg font-semibold">{selectedAttempt._status}</div>
                </div>
                <div className="p-4 border rounded-lg">
                  <div className="text-sm text-gray-600">Résultat</div>
                  <div className={`text-lg font-semibold ${selectedAttempt._passed ? 'text-green-600' : 'text-red-600'}`}>
                    {selectedAttempt._passed === true ? 'Réussi ✓' : selectedAttempt._passed === false ? 'Échoué ✗' : '-'}
                  </div>
                </div>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 border rounded-lg">
                  <div className="text-sm text-gray-600">Début</div>
                  <div className="text-sm">{formatDate(selectedAttempt._startedAt)}</div>
                </div>
                <div className="p-4 border rounded-lg">
                  <div className="text-sm text-gray-600">Fin</div>
                  <div className="text-sm">{formatDate(selectedAttempt._completedAt)}</div>
                </div>
                <div className="p-4 border rounded-lg">
                  <div className="text-sm text-gray-600">Durée</div>
                  <div className="text-sm">{formatDuration(selectedAttempt._durationSec)}</div>
                </div>
              </div>
            </div>
            <div className="px-6 py-4 border-t flex justify-end">
              <button onClick={() => setSelectedAttempt(null)} className="px-4 py-2 rounded border hover:bg-gray-50">Fermer</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}