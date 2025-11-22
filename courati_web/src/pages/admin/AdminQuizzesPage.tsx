import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { adminQuizzesAPI } from '../../api/adminQuizzes';
import { subjectsAPI } from '../../api/subjects';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { toast } from 'sonner';
import { Brain, ClipboardList, Eye, Pencil, ToggleLeft, ToggleRight, Trash2, Search, Plus } from 'lucide-react';

function getPassRateBadgeColor(passRate: number | null | undefined) {
  if (passRate == null) return 'bg-gray-100 text-gray-700 border-gray-300';
  if (passRate >= 70) return 'bg-green-100 text-green-700 border-green-300';
  if (passRate >= 50) return 'bg-orange-100 text-orange-700 border-orange-300';
  return 'bg-red-100 text-red-700 border-red-300';
}

export default function AdminQuizzesPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [searchParams, setSearchParams] = useSearchParams();

  // Filters + search
  const [subjectFilter, setSubjectFilter] = useState<string>(searchParams.get('subject') || '');
  const [statusFilter, setStatusFilter] = useState<string>(searchParams.get('is_active') || '');
  const [searchInput, setSearchInput] = useState<string>(searchParams.get('search') || '');
  const [debouncedSearch, setDebouncedSearch] = useState<string>(searchInput);

  // Client-side pagination
  const [page, setPage] = useState<number>(Number(searchParams.get('page')) || 1);
  const [pageSize, setPageSize] = useState<number>(Number(searchParams.get('page_size')) || 10);

  // Debounce search
  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(searchInput), 500);
    return () => clearTimeout(t);
  }, [searchInput]);

  // Sync URL
  useEffect(() => {
    const next: Record<string, string> = {};
    if (subjectFilter) next.subject = subjectFilter;
    if (statusFilter) next.is_active = statusFilter;
    if (debouncedSearch) next.search = debouncedSearch;
    if (page !== 1) next.page = String(page);
    if (pageSize !== 10) next.page_size = String(pageSize);
    setSearchParams(next);
  }, [subjectFilter, statusFilter, debouncedSearch, page, pageSize, setSearchParams]);

  // Load subjects for filter
  const { data: subjectsData } = useQuery({
    queryKey: ['admin_quiz_subjects'],
    queryFn: () => subjectsAPI.getAll(),
  });

  const subjectOptions: { id: number; name: string; code?: string }[] = useMemo(() => {
    const arr = Array.isArray(subjectsData) ? subjectsData : (subjectsData?.subjects || []);
    return arr.map((s: any) => ({ 
      id: Number(s.id), 
      name: String(s.name ?? ''), 
      code: String(s.code ?? s.subject_code ?? '') 
    }));
  }, [subjectsData]);

  // Fetch quizzes
  const { data: listResp, isLoading, isFetching, error } = useQuery({
    queryKey: ['admin_quizzes', subjectFilter, statusFilter, debouncedSearch],
    queryFn: () => adminQuizzesAPI.getAll({
      subject: subjectFilter ? Number(subjectFilter) : undefined,
      is_active: statusFilter ? statusFilter === 'true' : undefined,
      search: debouncedSearch || undefined,
    }),
    placeholderData: (prev) => prev as any,
  });

  const listData: any = listResp as any;
  const quizzes: any[] = listData?.quizzes || [];
  const totalQuizzes: number = listData?.total_quizzes ?? quizzes.length;

  // Client-side pagination
  const totalPages = Math.max(1, Math.ceil(quizzes.length / pageSize));
  const pageStart = (page - 1) * pageSize;
  const pageItems = quizzes.slice(pageStart, pageStart + pageSize);

  // ✅ STATISTIQUES CORRIGÉES
  const stats = useMemo(() => {
    const active = quizzes.filter((q) => q.is_active).length;
    const inactive = quizzes.filter((q) => !q.is_active).length;
    
    // Calculer le taux de réussite moyen (seulement pour les quiz avec pass_rate défini)
    const quizzesWithPassRate = quizzes.filter((q: any) => 
      q.pass_rate !== null && q.pass_rate !== undefined && typeof q.pass_rate === 'number'
    );
    
    let averagePassRate = null;
    if (quizzesWithPassRate.length > 0) {
      const totalPassRate = quizzesWithPassRate.reduce(
        (sum: number, q: any) => sum + q.pass_rate, 
        0
      );
      averagePassRate = Math.round((totalPassRate / quizzesWithPassRate.length) * 10) / 10;
    }

    return {
      total: totalQuizzes,
      active,
      inactive,
      averagePassRate
    };
  }, [quizzes, totalQuizzes]);

  // Mutations
  const toggleMutation = useMutation({
    mutationFn: (id: number) => adminQuizzesAPI.toggleActive(id),
    onSuccess: () => {
      toast.success('Statut modifié');
      queryClient.invalidateQueries({ queryKey: ['admin_quizzes'] });
    },
    onError: (e: any) => toast.error(e?.response?.data?.error || 'Erreur toggle'),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: number) => adminQuizzesAPI.delete(id),
    onSuccess: () => {
      toast.success('Quiz supprimé');
      queryClient.invalidateQueries({ queryKey: ['admin_quizzes'] });
      setPage(1);
    },
    onError: (error: any) => {
      const message = error?.response?.data?.error || 'Erreur lors de la suppression';
      const suggestion = error?.response?.data?.suggestion;
      if (suggestion) toast.error(`${message}\n${suggestion}`);
      else toast.error(message);
    },
  });

  if (!listResp && isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600">Erreur: {(error as Error).message}</div>;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 flex items-center gap-2">
            <ClipboardList className="w-6 h-6 text-primary-600" />
            Gestion des Quiz
          </h1>
          <p className="text-gray-600 mt-1">{stats.total} quiz au total</p>
        </div>
        <button 
          onClick={() => navigate('/admin/quizzes/new')} 
          className="flex items-center gap-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
        >
          <Plus className="w-5 h-5" />
          Créer un quiz
        </button>
      </div>

      {/* ✅ STATISTIQUES CORRIGÉES */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {/* Total */}
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-sm text-gray-600 mb-1">Total quiz</div>
          <div className="text-2xl font-bold text-gray-900">{stats.total}</div>
        </div>

        {/* Actifs */}
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-sm text-gray-600 mb-1">Quiz actifs</div>
          <div className="text-2xl font-bold text-green-600">{stats.active}</div>
        </div>

        {/* Inactifs */}
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-sm text-gray-600 mb-1">Quiz inactifs</div>
          <div className="text-2xl font-bold text-gray-600">{stats.inactive}</div>
        </div>

        {/* Taux de réussite moyen */}
        <div className="bg-white rounded-xl border border-gray-200 p-4">
          <div className="text-sm text-gray-600 mb-1">Taux de réussite moyen</div>
          <div className="text-2xl font-bold">
            {stats.averagePassRate !== null ? (
              <span className={`
                ${stats.averagePassRate >= 70 ? 'text-green-600' : 
                  stats.averagePassRate >= 50 ? 'text-orange-600' : 'text-red-600'}
              `}>
                {stats.averagePassRate}%
              </span>
            ) : (
              <span className="text-gray-400 text-base font-normal">
                Aucune donnée
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Filtres & Recherche */}
      <div className="bg-white rounded-xl p-4 border border-gray-200 space-y-3">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
          <input
            value={searchInput}
            onChange={(e) => { 
              setSearchInput(e.target.value); 
              setPage(1); 
            }}
            placeholder="Rechercher un quiz..."
            className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          />
          {(isFetching || searchInput !== debouncedSearch) && (
            <div className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 rounded-full border-2 border-gray-300 border-t-transparent animate-spin" />
          )}
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          <select 
            value={subjectFilter} 
            onChange={(e) => { 
              setSubjectFilter(e.target.value); 
              setPage(1); 
            }} 
            className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500"
          >
            <option value="">Toutes les matières</option>
            {subjectOptions.map((s) => (
              <option key={s.id} value={s.id}>
                {s.code ? `${s.code} - ${s.name}` : s.name}
              </option>
            ))}
          </select>
          <select 
            value={statusFilter} 
            onChange={(e) => { 
              setStatusFilter(e.target.value); 
              setPage(1); 
            }} 
            className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500"
          >
            <option value="">Tous les statuts</option>
            <option value="true">Actifs</option>
            <option value="false">Inactifs</option>
          </select>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-4 text-left text-sm font-medium text-gray-600">Titre</th>
                <th className="py-3 px-4 text-left text-sm font-medium text-gray-600">Matière</th>
                <th className="py-3 px-4 text-left text-sm font-medium text-gray-600">Professeur</th>
                <th className="py-3 px-4 text-center text-sm font-medium text-gray-600">Questions</th>
                <th className="py-3 px-4 text-center text-sm font-medium text-gray-600">Tentatives</th>
                <th className="py-3 px-4 text-center text-sm font-medium text-gray-600">Taux réussite</th>
                <th className="py-3 px-4 text-center text-sm font-medium text-gray-600">Durée</th>
                <th className="py-3 px-4 text-center text-sm font-medium text-gray-600">Statut</th>
                <th className="py-3 px-4 text-right text-sm font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {pageItems.length > 0 ? pageItems.map((q: any) => (
                <tr key={q.id} className="border-t border-gray-200 hover:bg-gray-50 transition-colors">
                  <td className="py-3 px-4">
                    <div className="font-medium text-gray-900">{q.title}</div>
                    {q.description && <div className="text-xs text-gray-500 mt-0.5">{q.description}</div>}
                  </td>
                  <td className="py-3 px-4">
                    <div className="text-sm text-gray-900">{q.subject_name || '-'}</div>
                    <div className="text-xs text-gray-500">{q.subject_code || ''}</div>
                  </td>
                  <td className="py-3 px-4 text-sm text-gray-700">{q.created_by_name || '-'}</td>
                  <td className="py-3 px-4 text-center text-sm text-gray-900">{q.question_count ?? 0}</td>
                  <td className="py-3 px-4 text-center text-sm text-gray-900">{q.total_attempts ?? 0}</td>
                  <td className="py-3 px-4 text-center">
                    {q.pass_rate !== null && q.pass_rate !== undefined ? (
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${getPassRateBadgeColor(q.pass_rate)}`}>
                        {q.pass_rate}%
                      </span>
                    ) : (
                      <span className="text-xs text-gray-400">
                        {q.total_attempts > 0 ? 'En cours' : 'Aucune'}
                      </span>
                    )}
                  </td>
                  <td className="py-3 px-4 text-center text-sm text-gray-700">{q.duration_minutes ?? '-'} min</td>
                  <td className="py-3 px-4 text-center">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${q.is_active ? 'bg-green-50 text-green-700 border-green-200' : 'bg-gray-50 text-gray-700 border-gray-200'}`}>
                      {q.is_active ? 'Actif' : 'Inactif'}
                    </span>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-1 justify-end">
                      <button 
                        onClick={() => navigate(`/admin/quizzes/${q.id}`)} 
                        className="p-1.5 rounded hover:bg-gray-100 transition-colors" 
                        title="Voir détails"
                      >
                        <Eye className="w-4 h-4 text-blue-600" />
                      </button>
                      <button 
                        onClick={() => navigate(`/admin/quizzes/${q.id}/edit`)} 
                        className="p-1.5 rounded hover:bg-gray-100 transition-colors" 
                        title="Modifier"
                      >
                        <Pencil className="w-4 h-4 text-gray-700" />
                      </button>
                      <button 
                        onClick={() => toggleMutation.mutate(q.id)} 
                        disabled={toggleMutation.isPending} 
                        className={`inline-flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${q.is_active ? 'border-amber-300 text-amber-700 hover:bg-amber-50' : 'border-green-300 text-green-700 hover:bg-green-50'} disabled:opacity-50`}
                        title={q.is_active ? 'Désactiver' : 'Activer'}
                      >
                        {q.is_active ? (
                          <>
                            <ToggleLeft className="w-4 h-4" />
                            <span className="hidden sm:inline">Désactiver</span>
                          </>
                        ) : (
                          <>
                            <ToggleRight className="w-4 h-4" />
                            <span className="hidden sm:inline">Activer</span>
                          </>
                        )}
                      </button>
                      <button 
                        onClick={() => { 
                          if (confirm(`Supprimer le quiz "${q.title}" ?`)) {
                            deleteMutation.mutate(q.id); 
                          }
                        }} 
                        disabled={deleteMutation.isPending} 
                        className="p-1.5 rounded hover:bg-gray-100 transition-colors disabled:opacity-50" 
                        title="Supprimer"
                      >
                        <Trash2 className="w-4 h-4 text-red-600" />
                      </button>
                    </div>
                  </td>
                </tr>
              )) : (
                <tr>
                  <td className="py-12 px-4 text-center text-gray-500" colSpan={9}>
                    <div className="flex flex-col items-center gap-3">
                      <Brain className="w-12 h-12 text-gray-400" />
                      <div>
                        <div className="font-medium text-gray-900 mb-1">Aucun quiz trouvé</div>
                        <div className="text-sm text-gray-500">
                          {debouncedSearch || subjectFilter || statusFilter 
                            ? 'Essayez de modifier vos filtres' 
                            : 'Créez votre premier quiz'}
                        </div>
                      </div>
                    </div>
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Pagination */}
      {quizzes.length > 0 && (
        <div className="flex items-center justify-between">
          <div className="text-sm text-gray-600">
            Page {page} / {totalPages} • {quizzes.length} résultat(s)
          </div>
          <div className="flex items-center gap-2">
            <button 
              onClick={() => setPage((p) => Math.max(1, p - 1))} 
              disabled={page <= 1} 
              className="px-3 py-1.5 border border-gray-300 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 transition-colors"
            >
              Précédent
            </button>
            <button 
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))} 
              disabled={page >= totalPages} 
              className="px-3 py-1.5 border border-gray-300 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 transition-colors"
            >
              Suivant
            </button>
            <select 
              value={pageSize} 
              onChange={(e) => { 
                setPageSize(Number(e.target.value)); 
                setPage(1); 
              }} 
              className="px-2 py-1.5 border border-gray-300 rounded-lg text-sm focus:ring-2 focus:ring-primary-500"
            >
              {[10, 20, 50].map((s) => (
                <option key={s} value={s}>{s}/page</option>
              ))}
            </select>
          </div>
        </div>
      )}
    </div>
  );
}