import { useState, useMemo } from 'react';
import { useParams, Link, useLocation } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { teacherAPI } from '../../api/teacher';
import { teacherDocumentsAPI } from '../../api/teacherDocuments';
import { teacherQuizzesAPI } from '../../api/teacherQuizzes';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { toast } from 'sonner';
import StatCard from '../../components/common/StatCard';
import { Eye, EyeOff, Download, CheckCircle2, TrendingUp, Pencil, Trash2, ToggleLeft, ToggleRight } from 'lucide-react';
import apiClient from '../../api/client';

export default function TeacherSubjectDetailPage() {
  const { id } = useParams();
  const subjectId = Number(id);
  const queryClient = useQueryClient();
  const location = useLocation() as any;

  // Tabs state
  const initialTab = (location?.state && typeof location.state.tab === 'number') ? location.state.tab : 0;
  const [currentTab, setCurrentTab] = useState<0 | 1 | 2 | 3>(initialTab);

  // Upload modal state
  const [isUploadOpen, setIsUploadOpen] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [dragActive, setDragActive] = useState(false);
  const [uploadForm, setUploadForm] = useState<{ title: string; description: string; document_type: string; file: File | null; is_active: boolean }>({
    title: '',
    description: '',
    document_type: 'COURS',
    file: null,
    is_active: true,
  });
  // Edit modal state
  const [isEditOpen, setIsEditOpen] = useState(false);
  const [selectedDoc, setSelectedDoc] = useState<any | null>(null);
  const [editForm, setEditForm] = useState<{ title: string; description: string; document_type: string; is_active: boolean }>({
    title: '', description: '', document_type: 'COURS', is_active: true
  });

  // Documents filters
  const [searchTerm, setSearchTerm] = useState('');
  const [typeFilter, setTypeFilter] = useState('');
  // Client-side pagination (documents)
  const [docPage, setDocPage] = useState<number>(1);
  const [docPageSize, setDocPageSize] = useState<number>(10);

  const { data: stats, isLoading, error } = useQuery({
    queryKey: ['teacher_subject_stats', subjectId],
    queryFn: () => teacherAPI.getSubjectStatistics(subjectId),
    enabled: Number.isFinite(subjectId) && subjectId > 0,
  });

  const { data: students } = useQuery({
    queryKey: ['teacher_subject_students', subjectId],
    queryFn: () => teacherAPI.getSubjectStudents(subjectId),
    enabled: Number.isFinite(subjectId) && subjectId > 0,
  });

  const { data: subjectData, isLoading: subjectLoading } = useQuery({
    queryKey: ['teacher-subject-detail', subjectId],
    queryFn: () => teacherAPI.getSubjectDetail(subjectId),
    enabled: Number.isFinite(subjectId) && subjectId > 0,
  });

  // Fetch all subjects to find current subject info for header
  // ✅ CORRECTION : Récupérer la liste des matières
const { data: mySubjects } = useQuery({
  queryKey: ['teacher_subjects'],
  queryFn: async () => {
    console.log('🔍 Chargement liste matières');
    const result = await teacherAPI.getMySubjects();
    console.log('✅ Résultat getMySubjects:', result);
    return result;
  },
});

// ✅ CORRECTION : Extraire le nom de la matière de manière robuste
  const subjectName = useMemo(() => {
    console.log('📊 Extraction nom - subjectData:', subjectData);
    console.log('📊 Extraction nom - mySubjects:', mySubjects);
    
    // Priorité 1 : Depuis subjectData (query detail)
    if (subjectData?.subject?.name) {
      console.log('✅ Nom depuis subjectData.subject.name:', subjectData.subject.name);
      return subjectData.subject.name;
    }
    if (subjectData?.name) {
      console.log('✅ Nom depuis subjectData.name:', subjectData.name);
      return subjectData.name;
    }
    
    // Priorité 2 : Depuis mySubjects
    // Cas A : mySubjects = { subjects: [{subject: {...}}, ...] }
    if (mySubjects?.subjects && Array.isArray(mySubjects.subjects)) {
      const found = mySubjects.subjects.find((item: any) => {
        const subj = item.subject || item;
        return subj.id === subjectId;
      });
      
      if (found) {
        const name = found.subject?.name || found.name;
        console.log('✅ Nom depuis mySubjects.subjects:', name);
        return name;
      }
    }
    
    // Cas B : mySubjects = [{subject: {...}}, ...]
    if (Array.isArray(mySubjects)) {
      const found = mySubjects.find((item: any) => {
        const subj = item.subject || item;
        return subj.id === subjectId;
      });
      
      if (found) {
        const name = found.subject?.name || found.name;
        console.log('✅ Nom depuis mySubjects (array):', name);
        return name;
      }
    }
    
    console.warn('⚠️ Nom non trouvé, fallback');
    return `Matière ${subjectId}`;
  }, [subjectData, mySubjects, subjectId]);

  const subjectCode = useMemo(() => {
    // Même logique pour le code
    if (subjectData?.subject?.code) return subjectData.subject.code;
    if (subjectData?.code) return subjectData.code;
    
    if (mySubjects?.subjects && Array.isArray(mySubjects.subjects)) {
      const found = mySubjects.subjects.find((item: any) => {
        const subj = item.subject || item;
        return subj.id === subjectId;
      });
      if (found) return found.subject?.code || found.code || '';
    }
    
    if (Array.isArray(mySubjects)) {
      const found = mySubjects.find((item: any) => {
        const subj = item.subject || item;
        return subj.id === subjectId;
      });
      if (found) return found.subject?.code || found.code || '';
    }
    
    return '';
  }, [subjectData, mySubjects, subjectId]);

  console.log('📌 NOM FINAL:', subjectName);
  console.log('📌 CODE FINAL:', subjectCode);

  // Documents list for subject (teacher endpoint)
  const { data: documents, isLoading: docsLoading } = useQuery({
    queryKey: ['teacher-subject-documents', subjectId, typeFilter, searchTerm],
    queryFn: () => teacherAPI.getSubjectDocuments(subjectId, {
      type: typeFilter || undefined,
      search: searchTerm || undefined,
    }),
    enabled: Number.isFinite(subjectId) && subjectId > 0 && currentTab === 0,
  });

  const { data: subjectQuizzes, isLoading: quizzesLoading } = useQuery({
    queryKey: ['subject-quizzes', subjectId],
    queryFn: () => teacherQuizzesAPI.getAll({ subject: subjectId }),
    enabled: Number.isFinite(subjectId) && subjectId > 0 && currentTab === 1,
  });

  const uploadMutation = useMutation({
    mutationFn: (fd: FormData) => teacherDocumentsAPI.upload(subjectId, fd, (p) => setUploadProgress(p)),
    onMutate: () => {
      setUploadProgress(0);
    },
    onSuccess: () => {
      toast.success('Document uploadé');
      queryClient.invalidateQueries({ queryKey: ['teacher-subject-documents', subjectId] });
      setIsUploadOpen(false);
      setUploadForm({ title: '', description: '', document_type: 'COURS', file: null, is_active: true });
    },
    onError: (err: any) => {
      const msg = err?.response?.data?.detail || err?.message || 'Erreur upload';
      toast.error(msg);
    },
    onSettled: () => {},
  });

  const editMutation = useMutation({
    mutationFn: (payload: { id: number; data: any }) => teacherDocumentsAPI.update(payload.id, payload.data),
    onSuccess: () => {
      toast.success('Document modifié');
      queryClient.invalidateQueries({ queryKey: ['teacher-subject-documents', subjectId] });
      setIsEditOpen(false);
      setSelectedDoc(null);
    },
    onError: (err: any) => {
      const msg = err?.response?.data?.detail || err?.message || 'Erreur modification';
      toast.error(msg);
    }
  });

  // Toggle active/inactive for a document
  const toggleActiveMutation = useMutation({
    mutationFn: (payload: { documentId: number; isActive: boolean }) =>
      teacherDocumentsAPI.update(payload.documentId, { is_active: payload.isActive }),
    onSuccess: () => {
      toast.success('Statut du document modifié');
      queryClient.invalidateQueries({ queryKey: ['teacher-subject-documents', subjectId] });
    },
    onError: (error: any) => {
      toast.error(error?.response?.data?.error || 'Erreur lors de la modification');
    }
  });

  const deleteDocMutation = useMutation({
    mutationFn: (documentId: number) => teacherDocumentsAPI.delete(documentId),
    onSuccess: () => {
      toast.success('Document supprimé');
      queryClient.invalidateQueries({ queryKey: ['teacher-subject-documents', subjectId] });
    },
    onError: (err: any) => {
      const msg = err?.response?.data?.detail || err?.message || 'Erreur suppression';
      toast.error(msg);
    },
  });

  if (!Number.isFinite(subjectId) || subjectId <= 0) {
    return <div className="text-red-600">Identifiant matière invalide</div>;
  }

  if (isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600">Erreur: {(error as Error).message}</div>;

  const validateAndSetFile = (file: File) => {
    const maxSize = 50 * 1024 * 1024; // 50MB
    const allowed = [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    ];
    if (file.size > maxSize) return toast.error('Fichier trop volumineux (max 50MB)');
    if (!allowed.includes(file.type)) return toast.error('Format non supporté. PDF/DOC/DOCX/PPT/PPTX');
    setUploadForm(prev => ({ ...prev, file }));
  };

  const handleToggleActive = (doc: any) => {
    const newStatus = !doc.is_active;
    const action = newStatus ? 'activer' : 'désactiver';
    const message = newStatus
      ? 'Le document sera visible pour les étudiants.'
      : 'Le document sera masqué pour les étudiants.';
    if (!confirm(`Voulez-vous ${action} "${doc.title}" ?\n\n${message}`)) return;
    toggleActiveMutation.mutate({ documentId: doc.id, isActive: newStatus });
  };

  const handleDrop = (e: React.DragEvent<HTMLDivElement>) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    const file = e.dataTransfer.files?.[0];
    if (file) validateAndSetFile(file);
  };

  const handleUploadSubmit = () => {
    if (uploadMutation.isPending) return;
    if (!uploadForm.file || !uploadForm.title) {
      toast.error('Veuillez remplir les champs obligatoires');
      return;
    }
    const fd = new FormData();
    fd.append('title', uploadForm.title);
    fd.append('description', uploadForm.description);
    fd.append('document_type', uploadForm.document_type);
    fd.append('is_active', String(uploadForm.is_active));
    fd.append('file', uploadForm.file);
    uploadMutation.mutate(fd);
  };

  const docsArray: any[] = Array.isArray(documents)
    ? documents
    : (documents?.results || documents?.documents || []);
  const docTotalPages = Math.max(1, Math.ceil(docsArray.length / docPageSize));
  const docStart = (docPage - 1) * docPageSize;
  const docPageItems = docsArray.slice(docStart, docStart + docPageSize);

  // Reset page on filters change
  if (docPage !== 1 && (searchTerm || typeFilter)) {
    // noop in render; rely on controlled handlers below
  }

  const handleDownload = async (doc: any) => {
    try {
      // Try backend download endpoint for tracking perms and counts
      const response = await apiClient.get(`/api/courses/documents/${doc.id}/download/`, { responseType: 'blob' });
      const blob = new Blob([response.data]);
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = doc.file_name || `${doc.title || 'document'}.pdf`;
      document.body.appendChild(link);
      link.click();
      link.remove();
      window.URL.revokeObjectURL(url);
      toast.success('Document téléchargé');
    } catch (e) {
      // Fallback to direct url if provided
      const direct = doc.download_url || doc.file_url || doc.file;
      if (direct) {
        window.open(direct, '_blank');
      } else {
        toast.error('Téléchargement indisponible');
      }
    }
  };

  return (
    <div className="space-y-6">
     {/* Header */}
    <div>
      <div className="mb-1 text-sm text-gray-600">
        <Link to="/teacher/subjects" className="text-primary-600 hover:underline">Mes Matières</Link>
        <span className="mx-2">/</span>
        <span>{subjectLoading ? 'Chargement...' : subjectName}</span>
      </div>
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{subjectLoading ? 'Chargement...' : subjectName}</h1>
          {subjectCode && (
            <p className="text-gray-600">Code: {subjectCode}</p>
          )}
        </div>
        <div>
          <Link to="/teacher/subjects" className="px-3 py-2 border rounded-lg text-gray-700 hover:bg-gray-50">Retour</Link>
        </div>
      </div>
      
      {/* Niveaux et filières (si disponibles) */}
      {(subjectData?.subject?.levels || subjectData?.levels) && (
        <div className="mt-2 flex flex-wrap gap-2">
          {((subjectData?.subject?.levels || subjectData?.levels) || []).map((l: any, idx: number) => (
            <span key={`l-${idx}`} className="px-2 py-1 rounded-full text-xs bg-primary-50 text-primary-700 border border-primary-200">
              {l?.name || l?.code || l}
            </span>
          ))}
          {((subjectData?.subject?.majors || subjectData?.majors) || []).map((m: any, idx: number) => (
            <span key={`m-${idx}`} className="px-2 py-1 rounded-full text-xs bg-purple-50 text-purple-700 border border-purple-200">
              {m?.name || m?.code || m}
            </span>
          ))}
        </div>
      )}
    </div>

      {/* Tabs */}
      <div className="bg-white rounded-xl border border-gray-200">
        <div className="flex border-b border-gray-200">
          {['Documents', 'Quiz', 'Étudiants', 'Statistiques'].map((label, idx) => (
            <button
              key={label}
              onClick={() => setCurrentTab(idx as any)}
              className={`px-4 py-3 text-sm font-medium border-b-2 ${currentTab === idx ? 'border-primary-500 text-primary-600' : 'border-transparent text-gray-600 hover:text-gray-800'}`}
            >
              {label}
            </button>
          ))}
        </div>

        {/* Documents Tab */}
        {currentTab === 0 && (
          <div className="p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold text-gray-900">Documents de la matière</h3>
              <button
                onClick={() => setIsUploadOpen(true)}
                className="px-3 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600"
              >
                Upload document
              </button>
            </div>

            {/* Filtres */}
            <div className="flex flex-wrap items-center gap-3">
              <input
                placeholder="Rechercher un document..."
                value={searchTerm}
                onChange={(e) => { setSearchTerm(e.target.value); setDocPage(1); }}
                className="flex-1 min-w-[240px] px-3 py-2 border rounded"
              />
              <select
                value={typeFilter}
                onChange={(e) => { setTypeFilter(e.target.value); setDocPage(1); }}
                className="px-3 py-2 border rounded min-w-[160px]"
              >
                <option value="">Tous les types</option>
                <option value="COURS">Cours</option>
                <option value="TD">TD</option>
                <option value="TP">TP</option>
                <option value="ARCHIVE">Archive</option>
              </select>
            </div>

            {/* Table documents */}
            <div className="overflow-x-auto border rounded-lg">
              <table className="w-full">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="text-left py-3 px-4 text-sm text-gray-600">Titre</th>
                    <th className="text-left py-3 px-4 text-sm text-gray-600">Type</th>
                    <th className="text-left py-3 px-4 text-sm text-gray-600">Taille</th>
                    <th className="text-center py-3 px-4 text-sm text-gray-600">Vues</th>
                    <th className="text-center py-3 px-4 text-sm text-gray-600">Téléchargements</th>
                    <th className="text-left py-3 px-4 text-sm text-gray-600">Créé par</th>
                    <th className="text-left py-3 px-4 text-sm text-gray-600">Ajouté le</th>
                    <th className="text-right py-3 px-4 text-sm text-gray-600">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {docsLoading ? (
                    <tr><td className="py-6 px-4" colSpan={8}>Chargement...</td></tr>
                  ) : docPageItems.length > 0 ? (
                    docPageItems.map((doc: any) => (
                      <tr key={doc.id} className={`border-t ${doc.is_active ? '' : 'opacity-50 bg-gray-50'}`}>
                        <td className="py-3 px-4">
                          <div className="flex items-start gap-2">
                            {!doc.is_active && (
                              <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs bg-gray-100 text-gray-700 border border-gray-200">Inactif</span>
                            )}
                            <div>
                              <div className="font-medium text-gray-900">{doc.title}</div>
                              {doc.description && (
                                <div className="text-xs text-gray-600">{doc.description}</div>
                              )}
                            </div>
                          </div>
                        </td>
                        <td className="py-3 px-4">
                          <span className="inline-flex items-center px-2 py-0.5 rounded text-xs bg-gray-100 text-gray-800 border border-gray-200">{(doc.document_type === 'COURS' ? 'Cours' : doc.document_type === 'TD' ? 'TD' : doc.document_type === 'TP' ? 'TP' : doc.document_type === 'ARCHIVE' ? 'Archive' : (doc.document_type || '-'))}</span>
                        </td>
                        <td className="py-3 px-4">{doc.file_size ? `${(doc.file_size/1024/1024).toFixed(2)} MB` : '-'}</td>
                        <td className="py-3 px-4 text-center">{doc.views_count ?? doc.views ?? 0}</td>
                        <td className="py-3 px-4 text-center">{doc.downloads_count ?? doc.downloads ?? 0}</td>
                        <td className="py-3 px-4">{doc.created_by_name || doc.created_by || '-'}</td>
                        <td className="py-3 px-4">{doc.created_at ? new Date(doc.created_at).toLocaleString() : '-'}</td>
                        <td className="py-3 px-4 text-right">
                          <div className="flex items-center justify-end gap-1">
                            <button
                              onClick={() => {
                                const viewUrl = doc.file_url || doc.file || doc.download_url;
                                if (viewUrl) window.open(viewUrl, '_blank');
                              }}
                              className="p-1 rounded hover:bg-gray-50"
                              title="Visualiser le document"
                            >
                              <Eye className="w-4 h-4 text-blue-600" />
                            </button>
                            
                            {doc.can_edit && (
                              <button
                                onClick={() => {
                                  setSelectedDoc(doc);
                                  setEditForm({
                                    title: doc.title || '',
                                    description: doc.description || '',
                                    document_type: doc.document_type || 'COURS',
                                    is_active: !!doc.is_active,
                                  });
                                  setIsEditOpen(true);
                                }}
                                className="p-1 rounded hover:bg-gray-50"
                                title="Modifier"
                              >
                                <Pencil className="w-4 h-4 text-gray-700" />
                              </button>
                            )}
                            {doc.can_edit && (
                              <button
                                onClick={() => handleToggleActive(doc)}
                                disabled={toggleActiveMutation.isPending}
                                className={`inline-flex items-center gap-1 px-2 py-1 border rounded text-xs min-w-[100px] justify-center ${doc.is_active ? 'border-amber-300 text-amber-700 hover:bg-amber-50' : 'border-green-300 text-green-700 hover:bg-green-50'}`}
                                title={doc.is_active ? 'Désactiver le document' : 'Activer le document'}
                              >
                                {doc.is_active ? (
                                  <>
                                    <ToggleLeft className="w-4 h-4" />
                                    Désactiver
                                  </>
                                ) : (
                                  <>
                                    <ToggleRight className="w-4 h-4" />
                                    Activer
                                  </>
                                )}
                              </button>
                            )}
                            {doc.can_delete && (
                              <button
                                onClick={() => {
                                  if (confirm('Supprimer ce document ?')) deleteDocMutation.mutate(doc.id);
                                }}
                                className="p-1 rounded hover:bg-gray-50"
                                title="Supprimer"
                              >
                                <Trash2 className="w-4 h-4 text-red-600" />
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr><td className="py-6 px-4 text-gray-600" colSpan={8}>Aucun document.</td></tr>
                  )}
                </tbody>
              </table>
            </div>

            {/* Pagination documents */}
            {docsArray.length > 0 && (
              <div className="flex items-center justify-between">
                <div className="text-sm text-gray-600">Page {docPage} / {docTotalPages} • {docsArray.length} document(s)</div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => setDocPage((p) => Math.max(1, p - 1))}
                    disabled={docPage <= 1}
                    className="px-3 py-1.5 border border-gray-300 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 transition-colors"
                  >
                    Précédent
                  </button>
                  <button
                    onClick={() => setDocPage((p) => Math.min(docTotalPages, p + 1))}
                    disabled={docPage >= docTotalPages}
                    className="px-3 py-1.5 border border-gray-300 rounded-lg disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 transition-colors"
                  >
                    Suivant
                  </button>
                  <select
                    value={docPageSize}
                    onChange={(e) => { setDocPageSize(Number(e.target.value)); setDocPage(1); }}
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
        )}

        {/* Quiz Tab */}
        {currentTab === 1 && (
          <div className="p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold text-gray-900">Quiz de la matière</h3>
              <Link to="/teacher/quizzes" className="px-3 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600">
                Créer un quiz
              </Link>
            </div>
            {quizzesLoading ? (
              <div className="text-gray-600">Chargement...</div>
            ) : Array.isArray(subjectQuizzes) && subjectQuizzes.length > 0 ? (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {subjectQuizzes.map((q: any) => (
                  <div key={q.id} className="border rounded-lg p-4 bg-white">
                    <div className="flex items-center justify-between mb-1">
                      <div className="font-semibold text-gray-900">{q.title}</div>
                      <span className={`text-xs px-2 py-0.5 rounded-full ${q.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'}`}>{q.is_active ? 'Actif' : 'Inactif'}</span>
                    </div>
                    <div className="text-sm text-gray-600 mb-2">{q.subject?.name || q.subject_name || '-'}</div>
                    <div className="flex items-center justify-between text-sm text-gray-700">
                      <span>{q.questions_count ?? (q.questions?.length ?? 0)} questions</span>
                      <span>{q.duration ?? q.duration_minutes ?? '-'} min</span>
                    </div>
                    <Link to={`/teacher/quizzes/${q.id}`} className="mt-3 inline-flex w-full justify-center px-3 py-2 border rounded-lg text-primary-600 hover:bg-primary-50">
                      Voir les détails
                    </Link>
                  </div>
                ))}
              </div>
            ) : (
              <div className="text-gray-600">Aucun quiz.</div>
            )}
          </div>
        )}

        {/* Étudiants Tab */}
        {currentTab === 2 && (
          <div className="p-6">
            <h3 className="text-lg font-semibold text-gray-900 mb-4">
              Étudiants ({Array.isArray(students) ? students.length : 0})
            </h3>
            
            {/* ✅ Version améliorée avec plus d'informations */}
            <div className="divide-y divide-gray-200">
              {Array.isArray(students) && students.length > 0 ? (
                students.map((s: any) => (
                  <div key={s.id || s.user_id} className="py-4 flex items-center justify-between hover:bg-gray-50 px-2 rounded">
                    <div className="flex items-center gap-3">
                      {/* Avatar */}
                      <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white font-semibold">
                        {(s.full_name || s.first_name || 'E').charAt(0).toUpperCase()}
                      </div>
                      
                      {/* Infos étudiant */}
                      <div>
                        <div className="font-medium text-gray-900">
                          {s.full_name || `${s.first_name || ''} ${s.last_name || ''}`.trim() || 'Nom inconnu'}
                        </div>
                        <div className="text-sm text-gray-500">{s.email}</div>
                      </div>
                    </div>
                    
                    {/* ✅ Infos niveau et filière (si disponibles) */}
                    <div className="flex gap-2">
                      {s.level_name && (
                        <span className="px-2 py-1 text-xs font-medium bg-blue-100 text-blue-800 rounded">
                          {s.level_name}
                        </span>
                      )}
                      {s.major_name && (
                        <span className="px-2 py-1 text-xs font-medium bg-purple-100 text-purple-800 rounded">
                          {s.major_name}
                        </span>
                      )}
                    </div>
                  </div>
                ))
              ) : (
                <div className="text-center py-12">
                  <div className="text-gray-400 text-lg mb-2">👥</div>
                  <div className="text-gray-600">Aucun étudiant inscrit à cette matière</div>
                </div>
              )}
            </div>
          </div>
        )}

        {/* Statistiques Tab */}
        {currentTab === 3 && (
          <div className="p-6 space-y-6">
            <h3 className="text-lg font-semibold text-gray-900">Statistiques</h3>
            {(() => { const s: any = (stats as any)?.statistics || stats || {}; return (
              <>
                {/* KPIs */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                  <StatCard title="Documents" value={s.total_documents || 0} icon={Download} color="blue" />
                  <StatCard title="Quiz" value={s.total_quizzes || 0} icon={CheckCircle2} color="purple" />
                  <StatCard title="Étudiants" value={s.total_students || 0} icon={Eye} color="green" />
                  <StatCard title="Vues totales" value={s.total_views || 0} icon={Eye} color="primary" />
                </div>

                {/* Documents par type */}
                {s.documents_by_type && typeof s.documents_by_type === 'object' && (
                  <div className="bg-white border rounded-xl p-4">
                    <h4 className="font-medium text-gray-900 mb-3">Documents par type</h4>
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3">
                      {Object.entries(s.documents_by_type).map(([type, count]: any) => (
                        <div key={type} className="text-center p-3 border rounded">
                          <div className="text-xl font-semibold text-primary-600">{count as any}</div>
                          <div className="text-xs text-gray-600">{type}</div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Activité récente (7 jours) */}
                <div className="bg-white border rounded-xl p-4">
                  <h4 className="font-medium text-gray-900 mb-3">Activité récente (7 derniers jours)</h4>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    <div className="text-center p-3 border rounded">
                      <div className="flex items-center justify-center mb-1"><Eye className="w-6 h-6 text-info-600" /></div>
                      <div className="text-2xl font-bold">{s.recent_views || 0}</div>
                      <div className="text-sm text-gray-600">Vues</div>
                    </div>
                    <div className="text-center p-3 border rounded">
                      <div className="flex items-center justify-center mb-1"><Download className="w-6 h-6 text-green-600" /></div>
                      <div className="text-2xl font-bold">{s.recent_downloads || 0}</div>
                      <div className="text-sm text-gray-600">Téléchargements</div>
                    </div>
                    <div className="text-center p-3 border rounded">
                      <div className="flex items-center justify-center mb-1"><CheckCircle2 className="w-6 h-6 text-yellow-600" /></div>
                      <div className="text-2xl font-bold">{s.recent_quiz_attempts || 0}</div>
                      <div className="text-sm text-gray-600">Tentatives de quiz</div>
                    </div>
                  </div>
                </div>

                {/* Performance des quiz */}
                {Array.isArray(s.quiz_performance) && s.quiz_performance.length > 0 && (
                  <div className="bg-white border rounded-xl p-4">
                    <h4 className="font-medium text-gray-900 mb-3">Performance des quiz</h4>
                    <div className="overflow-x-auto">
                      <table className="w-full">
                        <thead className="bg-gray-50">
                          <tr>
                            <th className="text-left py-2 px-3 text-sm text-gray-600">Quiz</th>
                            <th className="text-center py-2 px-3 text-sm text-gray-600">Tentatives</th>
                            <th className="text-center py-2 px-3 text-sm text-gray-600">Score moyen</th>
                            <th className="text-center py-2 px-3 text-sm text-gray-600">Taux de réussite</th>
                          </tr>
                        </thead>
                        <tbody>
                          {s.quiz_performance.map((qp: any) => (
                            <tr key={qp.quiz_id} className="border-t">
                              <td className="py-2 px-3">{qp.quiz_title}</td>
                              <td className="py-2 px-3 text-center">{qp.total_attempts}</td>
                              <td className="py-2 px-3 text-center">{qp.average_score}/20</td>
                              <td className="py-2 px-3 text-center">
                                <span className={`text-xs px-2 py-1 rounded-full border ${qp.pass_rate >= 70 ? 'bg-green-50 text-green-700 border-green-200' : qp.pass_rate >= 50 ? 'bg-yellow-50 text-yellow-700 border-yellow-200' : 'bg-red-50 text-red-700 border-red-200'}`}>{qp.pass_rate}%</span>
                              </td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
              </>
            ); })()}
          </div>
        )}
      </div>

      {/* Upload Modal */}
      {isUploadOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-xl w-full max-w-lg overflow-hidden">
            <div className="px-6 py-4 border-b flex items-center justify-between">
              <h3 className="font-semibold text-gray-900">Upload un document</h3>
              <button onClick={() => setIsUploadOpen(false)} className="text-gray-500 hover:text-gray-700">✕</button>
            </div>
            <div className="p-6 space-y-4">
              <div className="space-y-2">
                <label className="text-sm text-gray-700">Titre *</label>
                <input
                  className="w-full px-3 py-2 border rounded"
                  value={uploadForm.title}
                  onChange={(e) => setUploadForm(prev => ({ ...prev, title: e.target.value }))}
                  placeholder="Titre du document"
                />
              </div>

              <div className="space-y-2">
                <label className="text-sm text-gray-700">Description</label>
                <textarea
                  className="w-full px-3 py-2 border rounded"
                  rows={3}
                  value={uploadForm.description}
                  onChange={(e) => setUploadForm(prev => ({ ...prev, description: e.target.value }))}
                />
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="space-y-2">
                  <label className="text-sm text-gray-700">Type *</label>
                  <select
                    className="w-full px-3 py-2 border rounded"
                    value={uploadForm.document_type}
                    onChange={(e) => setUploadForm(prev => ({ ...prev, document_type: e.target.value }))}
                  >
                    <option value="COURS">Cours</option>
                    <option value="TD">TD</option>
                    <option value="TP">TP</option>
                    <option value="ARCHIVE">Archive</option>
                  </select>
                </div>
                <div className="flex items-end">
                  <label className="inline-flex items-center space-x-2 text-sm text-gray-700">
                    <input
                      type="checkbox"
                      checked={uploadForm.is_active}
                      onChange={(e) => setUploadForm(prev => ({ ...prev, is_active: e.target.checked }))}
                      className="h-4 w-4"
                    />
                    <span>Actif</span>
                  </label>
                </div>
              </div>

              {/* Drag & drop zone */}
              <div
                onDragEnter={(e) => { e.preventDefault(); e.stopPropagation(); setDragActive(true); }}
                onDragOver={(e) => { e.preventDefault(); e.stopPropagation(); }}
                onDragLeave={(e) => { e.preventDefault(); e.stopPropagation(); setDragActive(false); }}
                onDrop={handleDrop}
                className={`p-4 border-2 border-dashed rounded text-center cursor-pointer ${dragActive ? 'border-primary-400 bg-primary-50' : 'border-gray-300'}`}
                onClick={() => document.getElementById('teacher-file-input')?.click()}
              >
                <input
                  id="teacher-file-input"
                  type="file"
                  hidden
                  accept=".pdf,.doc,.docx,.ppt,.pptx"
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (f) validateAndSetFile(f);
                  }}
                />
                {uploadForm.file ? (
                  <div>
                    <div className="font-medium text-gray-900">{uploadForm.file.name}</div>
                    <div className="text-xs text-gray-600">{(uploadForm.file.size / 1024 / 1024).toFixed(2)} MB</div>
                  </div>
                ) : (
                  <div className="text-gray-600 text-sm">
                    Glissez un fichier ici ou cliquez pour parcourir (PDF, DOC, DOCX, PPT, PPTX • max 50MB)
                  </div>
                )}
              </div>

              {uploadProgress > 0 && (
                <div className="w-full bg-gray-100 rounded h-2">
                  <div className="bg-primary-500 h-2 rounded" style={{ width: `${uploadProgress}%` }} />
                </div>
              )}

              <div className="flex items-center justify-end gap-2 pt-2">
                <button onClick={() => setIsUploadOpen(false)} className="px-4 py-2 rounded border" disabled={uploadMutation.isPending}>Annuler</button>
                <button onClick={handleUploadSubmit} disabled={uploadMutation.isPending} className={`px-4 py-2 rounded text-white ${uploadMutation.isPending ? 'bg-primary-300' : 'bg-primary-500 hover:bg-primary-600'}`}>{uploadMutation.isPending ? `Upload… ${uploadProgress}%` : 'Upload'}</button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Edit Modal */}
      {isEditOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-xl w-full max-w-lg overflow-hidden">
            <div className="px-6 py-4 border-b flex items-center justify-between">
              <h3 className="font-semibold text-gray-900">Modifier le document</h3>
              <button onClick={() => { if (!editMutation.isPending) { setIsEditOpen(false); setSelectedDoc(null); } }} className="text-gray-500 hover:text-gray-700">✕</button>
            </div>
            <div className="p-6 space-y-4">
              <div className="space-y-2">
                <label className="text-sm text-gray-700">Titre *</label>
                <input
                  className="w-full px-3 py-2 border rounded"
                  value={editForm.title}
                  onChange={(e) => setEditForm(prev => ({ ...prev, title: e.target.value }))}
                  placeholder="Titre du document"
                />
              </div>
              <div className="space-y-2">
                <label className="text-sm text-gray-700">Description</label>
                <textarea
                  className="w-full px-3 py-2 border rounded"
                  rows={3}
                  value={editForm.description}
                  onChange={(e) => setEditForm(prev => ({ ...prev, description: e.target.value }))}
                />
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div className="space-y-2">
                  <label className="text-sm text-gray-700">Type *</label>
                  <select
                    className="w-full px-3 py-2 border rounded"
                    value={editForm.document_type}
                    onChange={(e) => setEditForm(prev => ({ ...prev, document_type: e.target.value }))}
                  >
                    <option value="COURS">Cours</option>
                    <option value="TD">TD</option>
                    <option value="TP">TP</option>
                    <option value="ARCHIVE">Archive</option>
                  </select>
                </div>
                <div className="flex items-end">
                  <label className="inline-flex items-center space-x-2 text-sm text-gray-700">
                    <input
                      type="checkbox"
                      checked={editForm.is_active}
                      onChange={(e) => setEditForm(prev => ({ ...prev, is_active: e.target.checked }))}
                      className="h-4 w-4"
                    />
                    <span>Actif</span>
                  </label>
                </div>
              </div>
            </div>
            <div className="px-6 py-4 border-t flex items-center justify-end gap-2">
              <button onClick={() => { if (!editMutation.isPending) { setIsEditOpen(false); setSelectedDoc(null); } }} className="px-4 py-2 rounded border" disabled={editMutation.isPending}>Annuler</button>
              <button
                onClick={() => {
                  if (!selectedDoc) return;
                  if (!editForm.title) { toast.error('Le titre est obligatoire'); return; }
                  editMutation.mutate({ id: selectedDoc.id, data: editForm });
                }}
                className={`px-4 py-2 rounded text-white ${editMutation.isPending ? 'bg-primary-300' : 'bg-primary-500 hover:bg-primary-600'}`}
                disabled={editMutation.isPending}
              >
                {editMutation.isPending ? 'Modification…' : 'Modifier'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
