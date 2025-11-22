import { useEffect, useMemo, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { adminDocumentsAPI } from '../../api/adminDocuments';
import { subjectsAPI } from '../../api/subjects';
import apiClient from '../../api/client';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { toast } from 'sonner';
import { Eye, Pencil, Trash2, ToggleLeft, ToggleRight, Search, FileText } from 'lucide-react';

export default function AdminDocumentsPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [searchParams, setSearchParams] = useSearchParams();

  // URL-synced filters/pagination
  const [page, setPage] = useState<number>(Number(searchParams.get('page')) || 1);
  const [pageSize, setPageSize] = useState<number>(Number(searchParams.get('page_size')) || 20);
  const [subjectFilter, setSubjectFilter] = useState<string>(searchParams.get('subject') || '');
  const [teacherFilter, setTeacherFilter] = useState<string>(searchParams.get('teacher') || '');
  const [typeFilter, setTypeFilter] = useState<string>(searchParams.get('type') || '');
  const [statusFilter, setStatusFilter] = useState<string>(searchParams.get('is_active') || '');
  const [searchInput, setSearchInput] = useState<string>(searchParams.get('search') || '');
  const [debouncedSearch, setDebouncedSearch] = useState<string>(searchInput);

  // Selection
  const [selectedIds, setSelectedIds] = useState<number[]>([]);

  // Debounce search 500ms
  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(searchInput), 500);
    return () => clearTimeout(t);
  }, [searchInput]);

  // Sync URL
  useEffect(() => {
    const current = searchParams.get('search') || '';
    if (debouncedSearch !== current) {
      const newParams = new URLSearchParams(searchParams);
      if (debouncedSearch) {
        newParams.set('search', debouncedSearch);
      } else {
        newParams.delete('search');
      }
      newParams.set('page', '1');
      setPage(1);
      setSearchParams(newParams);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [debouncedSearch]);

  // Keep URL in sync
  useEffect(() => {
    const sp: any = {};
    if (page && page !== 1) sp.page = String(page);
    if (pageSize && pageSize !== 20) sp.page_size = String(pageSize);
    if (subjectFilter) sp.subject = subjectFilter;
    if (teacherFilter) sp.teacher = teacherFilter;
    if (typeFilter) sp.type = typeFilter;
    if (statusFilter) sp.is_active = statusFilter;
    if (debouncedSearch) sp.search = debouncedSearch;
    setSearchParams(sp);
  }, [page, pageSize, subjectFilter, teacherFilter, typeFilter, statusFilter, debouncedSearch, setSearchParams]);

  // Load subjects for filter
  const { data: subjectsData } = useQuery({
    queryKey: ['admin_subjects_for_docs'],
    queryFn: () => subjectsAPI.getAll(),
  });

  // ✅ CORRECTION : Load teachers from documents creators
  const { data: teachersData } = useQuery({
    queryKey: ['admin_teachers_for_docs'],
    queryFn: async () => {
      try {
        // Récupérer tous les documents pour extraire les créateurs uniques
        const response = await apiClient.get('/api/courses/admin/documents/', {
          params: { page_size: 1000 }
        });
        
        const documents = response.data?.documents || [];
        
        // Créer une Map pour éviter les doublons
        const creatorsMap = new Map<number, { id: number; name: string; role: string }>();
        
        documents.forEach((doc: any) => {
          if (doc.created_by && doc.created_by_name) {
            creatorsMap.set(doc.created_by, {
              id: doc.created_by,
              name: doc.created_by_name,
              role: doc.created_by_role || 'TEACHER'
            });
          }
        });
        
        // Convertir en tableau et trier par nom
        const uniqueCreators = Array.from(creatorsMap.values()).sort((a, b) => 
          a.name.localeCompare(b.name)
        );
        
        console.log('👥 Créateurs de documents trouvés:', uniqueCreators);
        
        return uniqueCreators;
      } catch (error) {
        console.error('❌ Erreur chargement créateurs:', error);
        return [];
      }
    }
  });

  // ✅ Options pour les filtres
  const subjectOptions: { id: number; name: string }[] = useMemo(() => {
    const arr = Array.isArray(subjectsData) ? subjectsData : (subjectsData?.subjects || []);
    return arr.map((s: any) => ({ 
      id: Number(s.id), 
      name: String(s.name ?? '') 
    }));
  }, [subjectsData]);

  const teacherOptions: { id: number; name: string; role: string }[] = useMemo(() => {
    if (!teachersData || !Array.isArray(teachersData)) {
      return [];
    }
    
    return teachersData.map((teacher: any) => ({
      id: Number(teacher.id),
      name: teacher.name,
      role: teacher.role
    }));
  }, [teachersData]);

  // Fetch documents list
  const { data: listResp, isLoading, isFetching, error } = useQuery({
    queryKey: ['admin_documents', page, pageSize, subjectFilter, teacherFilter, typeFilter, statusFilter, debouncedSearch],
    queryFn: () => {
      const params = {
        page,
        page_size: pageSize,
        subject: subjectFilter || undefined,
        teacher: teacherFilter ? Number(teacherFilter) : undefined,
        type: typeFilter || undefined,
        is_active: statusFilter ? statusFilter === 'true' : undefined,
        search: debouncedSearch || undefined,
      };
      
      console.log('🔍 Requête documents avec filtres:', params);
      
      return adminDocumentsAPI.getAll(params);
    },
  });

  const listData: any = listResp as any;
  const documents: any[] = listData?.documents || listData?.results || [];
  const totalPages: number = listData?.total_pages || 1;
  const totalCount: number = listData?.total || documents.length;

  // Mutations
  const toggleMutation = useMutation({
    mutationFn: (id: number) => adminDocumentsAPI.toggleActive(id),
    onSuccess: () => {
      toast.success('Statut modifié');
      queryClient.invalidateQueries({ queryKey: ['admin_documents'] });
    },
    onError: (e: any) => toast.error(e?.response?.data?.error || 'Erreur toggle'),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: number) => adminDocumentsAPI.delete(id),
    onSuccess: () => {
      toast.success('Document supprimé');
      queryClient.invalidateQueries({ queryKey: ['admin_documents'] });
      queryClient.invalidateQueries({ queryKey: ['admin_teachers_for_docs'] }); // Rafraîchir la liste des profs
      setSelectedIds([]);
    },
    onError: (e: any) => toast.error(e?.response?.data?.error || 'Erreur suppression'),
  });

  const bulkMutation = useMutation({
    mutationFn: (payload: { action: 'activate' | 'deactivate' | 'delete'; document_ids: number[] }) => 
      adminDocumentsAPI.bulkAction(payload),
    onSuccess: () => {
      toast.success('Action en masse effectuée');
      queryClient.invalidateQueries({ queryKey: ['admin_documents'] });
      queryClient.invalidateQueries({ queryKey: ['admin_teachers_for_docs'] });
      setSelectedIds([]);
    },
    onError: (e: any) => toast.error(e?.response?.data?.error || 'Erreur action en masse'),
  });

  // Selection handlers
  const allSelectedOnPage = documents.length > 0 && documents.every((d) => selectedIds.includes(d.id));

  const toggleSelectAll = () => {
    if (allSelectedOnPage) {
      setSelectedIds((prev) => prev.filter((id) => !documents.some((d) => d.id === id)));
    } else {
      const pageIds = documents.map((d) => d.id);
      setSelectedIds((prev) => Array.from(new Set([...prev, ...pageIds])));
    }
  };

  const toggleSelectOne = (id: number) => {
    setSelectedIds((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));
  };

  const handleBulk = (action: 'activate' | 'deactivate' | 'delete') => {
    if (selectedIds.length === 0) return;
    if (action === 'delete') {
      if (!confirm(`Supprimer ${selectedIds.length} document(s) ?\n\nCette action est irréversible.`)) return;
    }
    bulkMutation.mutate({ action, document_ids: selectedIds });
  };

  if (isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600">Erreur: {(error as Error).message}</div>;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Gestion des Documents</h1>
          <p className="text-gray-600 mt-1">{totalCount} document(s) au total</p>
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
            placeholder="Rechercher un document..."
            className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          />
          {(isFetching || searchInput !== debouncedSearch) && (
            <div className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 rounded-full border-2 border-gray-300 border-t-transparent animate-spin" />
          )}
        </div>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-3">
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
              <option key={s.id} value={s.id}>{s.name}</option>
            ))}
          </select>
          
          <select 
            value={teacherFilter} 
            onChange={(e) => { 
              console.log('🎯 Filtre professeur sélectionné:', e.target.value);
              setTeacherFilter(e.target.value); 
              setPage(1); 
            }} 
            className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500"
          >
            <option value="">Tous les professeurs</option>
            {teacherOptions.map((t) => (
              <option key={t.id} value={t.id}>
                {t.name} {t.role === 'ADMIN' ? '(Admin)' : ''}
              </option>
            ))}
          </select>
          
          <select 
            value={typeFilter} 
            onChange={(e) => { 
              setTypeFilter(e.target.value); 
              setPage(1); 
            }} 
            className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500"
          >
            <option value="">Tous les types</option>
            <option value="COURS">Cours</option>
            <option value="TD">TD</option>
            <option value="TP">TP</option>
            <option value="ARCHIVE">Archive</option>
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

      {/* Actions en masse */}
      {selectedIds.length > 0 && (
        <div className="flex items-center gap-2 bg-blue-50 border border-blue-200 rounded-lg p-3">
          <span className="text-sm font-medium text-blue-900">
            {selectedIds.length} document(s) sélectionné(s)
          </span>
          <button 
            onClick={() => handleBulk('activate')} 
            className="px-3 py-1.5 border border-green-300 rounded-lg text-sm text-green-700 hover:bg-green-50 transition-colors"
          >
            Activer
          </button>
          <button 
            onClick={() => handleBulk('deactivate')} 
            className="px-3 py-1.5 border border-amber-300 rounded-lg text-sm text-amber-700 hover:bg-amber-50 transition-colors"
          >
            Désactiver
          </button>
          <button 
            onClick={() => handleBulk('delete')} 
            className="px-3 py-1.5 border border-red-300 rounded-lg text-sm text-red-700 hover:bg-red-50 transition-colors"
          >
            Supprimer
          </button>
          <button
            onClick={() => setSelectedIds([])}
            className="ml-auto px-3 py-1.5 text-sm text-gray-600 hover:text-gray-900"
          >
            Annuler
          </button>
        </div>
      )}

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-3 px-4 text-left">
                  <input 
                    type="checkbox" 
                    checked={allSelectedOnPage} 
                    onChange={toggleSelectAll}
                    className="rounded border-gray-300 text-primary-600 focus:ring-primary-500"
                  />
                </th>
                <th className="py-3 px-4 text-left text-sm font-medium text-gray-600">Titre</th>
                <th className="py-3 px-4 text-left text-sm font-medium text-gray-600">Matière</th>
                <th className="py-3 px-4 text-left text-sm font-medium text-gray-600">Créateur</th>
                <th className="py-3 px-4 text-left text-sm font-medium text-gray-600">Type</th>
                <th className="py-3 px-4 text-center text-sm font-medium text-gray-600">Taille</th>
                <th className="py-3 px-4 text-center text-sm font-medium text-gray-600">Vues/Téléch.</th>
                <th className="py-3 px-4 text-center text-sm font-medium text-gray-600">Statut</th>
                <th className="py-3 px-4 text-right text-sm font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {documents.length > 0 ? documents.map((d: any) => (
                <tr key={d.id} className="border-t border-gray-200 hover:bg-gray-50 transition-colors">
                  <td className="py-3 px-4">
                    <input 
                      type="checkbox" 
                      checked={selectedIds.includes(d.id)} 
                      onChange={() => toggleSelectOne(d.id)}
                      className="rounded border-gray-300 text-primary-600 focus:ring-primary-500"
                    />
                  </td>
                  <td className="py-3 px-4">
                    <div className="font-medium text-gray-900">{d.title}</div>
                    {d.description && (
                      <div className="text-xs text-gray-500 mt-0.5 line-clamp-1">
                        {d.description}
                      </div>
                    )}
                  </td>
                  <td className="py-3 px-4">
                    <div className="text-sm text-gray-900">{d.subject_name || '-'}</div>
                    {d.subject_code && (
                      <div className="text-xs text-gray-500">{d.subject_code}</div>
                    )}
                  </td>
                  <td className="py-3 px-4">
                    <div className="text-sm text-gray-900">{d.created_by_name || '-'}</div>
                    {d.created_by_role && (
                      <div className="text-xs text-gray-500">
                        {d.created_by_role === 'ADMIN' ? 'Admin' : 'Professeur'}
                      </div>
                    )}
                  </td>
                  <td className="py-3 px-4">
                    <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800 border border-gray-200">
                      {d.document_type_display || d.document_type}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-center text-sm text-gray-700">
                    {d.file_size_mb != null ? `${d.file_size_mb.toFixed(2)} MB` : '-'}
                  </td>
                  <td className="py-3 px-4 text-center text-sm text-gray-700">
                    <span className="text-blue-600">{d.view_count ?? 0}</span>
                    {' / '}
                    <span className="text-green-600">{d.download_count ?? 0}</span>
                  </td>
                  <td className="py-3 px-4 text-center">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border ${
                      d.is_active 
                        ? 'bg-green-50 text-green-700 border-green-200' 
                        : 'bg-gray-50 text-gray-700 border-gray-200'
                    }`}>
                      {d.is_active ? 'Actif' : 'Inactif'}
                    </span>
                  </td>
                  <td className="py-3 px-4">
                    <div className="flex items-center gap-1 justify-end">
                      <button 
                        onClick={() => window.open(d.file_url, '_blank')} 
                        className="p-1.5 rounded hover:bg-gray-100 transition-colors" 
                        title="Visualiser"
                      >
                        <Eye className="w-4 h-4 text-blue-600" />
                      </button>
                      <button 
                        onClick={() => navigate(`/admin/documents/${d.id}`)} 
                        className="p-1.5 rounded hover:bg-gray-100 transition-colors" 
                        title="Modifier"
                      >
                        <Pencil className="w-4 h-4 text-gray-700" />
                      </button>
                      <button 
                        onClick={() => toggleMutation.mutate(d.id)} 
                        disabled={toggleMutation.isPending} 
                        className={`inline-flex items-center gap-1 px-2 py-1 border rounded text-xs transition-colors ${
                          d.is_active 
                            ? 'border-amber-300 text-amber-700 hover:bg-amber-50' 
                            : 'border-green-300 text-green-700 hover:bg-green-50'
                        } disabled:opacity-50`}
                        title={d.is_active ? 'Désactiver' : 'Activer'}
                      >
                        {d.is_active ? (
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
                          if (confirm(`Supprimer le document "${d.title}" ?`)) {
                            deleteMutation.mutate(d.id); 
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
                      <FileText className="w-12 h-12 text-gray-400" />
                      <div>
                        <div className="font-medium text-gray-900 mb-1">Aucun document trouvé</div>
                        <div className="text-sm text-gray-500">
                          {debouncedSearch || subjectFilter || teacherFilter || typeFilter || statusFilter
                            ? 'Essayez de modifier vos filtres'
                            : 'Aucun document disponible'}
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
      {documents.length > 0 && (
        <div className="flex items-center justify-between">
          <div className="text-sm text-gray-600">
            Page {page} / {totalPages} • {totalCount} document(s)
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