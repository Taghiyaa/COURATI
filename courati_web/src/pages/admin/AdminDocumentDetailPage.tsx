import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { adminDocumentsAPI } from '../../api/adminDocuments';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { toast } from 'sonner';
import { Eye, Save, Trash2 } from 'lucide-react';

export default function AdminDocumentDetailPage() {
  const { id } = useParams();
  const docId = Number(id);
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const { data: document, isLoading, error } = useQuery({
    queryKey: ['admin_document', docId],
    queryFn: () => adminDocumentsAPI.getById(docId),
    enabled: Number.isFinite(docId) && docId > 0,
  });

  const [form, setForm] = useState<{ title: string; description: string; document_type: string; is_active: boolean; is_premium: boolean } | null>(null);

  useEffect(() => {
    if (!document) return;
    const d: any = (document as any).document || document;
    setForm({
      title: d.title || '',
      description: d.description || '',
      document_type: d.document_type || 'COURS',
      is_active: !!d.is_active,
      is_premium: !!d.is_premium,
    });
  }, [document]);

  const updateMutation = useMutation({
    mutationFn: (payload: any) => adminDocumentsAPI.update(docId, payload),
    onSuccess: () => {
      toast.success('Document modifié avec succès');
      queryClient.invalidateQueries({ queryKey: ['admin_documents'] });
      navigate('/admin/documents');
    },
    onError: (e: any) => toast.error(e?.response?.data?.error || 'Erreur lors de la sauvegarde'),
  });

  const deleteMutation = useMutation({
    mutationFn: () => adminDocumentsAPI.delete(docId),
    onSuccess: () => {
      toast.success('Document supprimé');
      queryClient.invalidateQueries({ queryKey: ['admin_documents'] });
      navigate('/admin/documents');
    },
    onError: (e: any) => toast.error(e?.response?.data?.error || 'Erreur lors de la suppression'),
  });

  if (!Number.isFinite(docId) || docId <= 0) {
    return <div className="text-red-600 p-6">Identifiant invalide</div>;
  }

  if (isLoading || !form) return <LoadingSpinner />;
  if (error) return <div className="text-red-600 p-6">Erreur: {(error as Error).message}</div>;

  const d: any = (document as any).document || document;
  const isImage = typeof d.file_url === 'string' && /\.(png|jpg|jpeg|gif|webp)$/i.test(d.file_url);

  const handleSave = () => {
    updateMutation.mutate({ ...form });
  };

  const handleDelete = () => {
    if (!confirm(`Supprimer le document "${d.title}" ?\n\nCette action est irréversible.`)) return;
    deleteMutation.mutate();
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{d.title || 'Document'}</h1>
          <p className="text-gray-600 mt-1">{d.subject_name || '-'} • {d.subject_code || ''}</p>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={handleSave} disabled={updateMutation.isPending} className="inline-flex items-center gap-2 px-3 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 disabled:opacity-50"><Save className="w-4 h-4" /> Enregistrer</button>
          <button onClick={handleDelete} disabled={deleteMutation.isPending} className="px-3 py-2 border border-red-300 rounded-lg text-red-700 hover:bg-red-50 disabled:opacity-50">{deleteMutation.isPending ? 'Suppression...' : 'Supprimer'}</button>
        </div>
      </div>

      {/* Form */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Infos éditables */}
        <div className="lg:col-span-2 bg-white rounded-xl border p-6 space-y-4">
          <div>
            <label className="text-sm text-gray-700">Titre</label>
            <input className="w-full px-3 py-2 border rounded" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div>
            <label className="text-sm text-gray-700">Description</label>
            <textarea rows={4} className="w-full px-3 py-2 border rounded" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="text-sm text-gray-700">Type</label>
              <select className="w-full px-3 py-2 border rounded" value={form.document_type} onChange={(e) => setForm({ ...form, document_type: e.target.value })}>
                <option value="COURS">Cours</option>
                <option value="TD">TD</option>
                <option value="TP">TP</option>
                <option value="ARCHIVE">Archive</option>
              </select>
            </div>
            <label className="inline-flex items-center gap-2 text-sm text-gray-700 mt-6"><input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} /> Actif</label>
            <label className="inline-flex items-center gap-2 text-sm text-gray-700 mt-6"><input type="checkbox" checked={form.is_premium} onChange={(e) => setForm({ ...form, is_premium: e.target.checked })} /> Premium</label>
          </div>
        </div>

        {/* Métadonnées */}
        <div className="bg-white rounded-xl border p-6 space-y-3">
          <div className="text-sm"><span className="text-gray-600">Matière:</span> <span className="font-medium text-gray-900">{d.subject_name || '-'}</span></div>
          <div className="text-sm"><span className="text-gray-600">Code:</span> <span className="font-medium text-gray-900">{d.subject_code || '-'}</span></div>
          <div className="text-sm"><span className="text-gray-600">Créé par:</span> <span className="font-medium text-gray-900">{d.created_by_name || '-'}</span></div>
          <div className="text-sm"><span className="text-gray-600">Créé le:</span> <span className="font-medium text-gray-900">{d.created_at ? new Date(d.created_at).toLocaleString('fr-FR') : '-'}</span></div>
          <div className="text-sm"><span className="text-gray-600">Taille:</span> <span className="font-medium text-gray-900">{d.file_size_mb != null ? `${d.file_size_mb.toFixed(2)} MB` : '-'}</span></div>
          <div className="text-sm"><span className="text-gray-600">Vues:</span> <span className="font-medium text-gray-900">{d.view_count ?? 0}</span></div>
          <div className="text-sm"><span className="text-gray-600">Téléchargements:</span> <span className="font-medium text-gray-900">{d.download_count ?? 0}</span></div>
        </div>
      </div>

      {/* Fichier */}
      <div className="bg-white rounded-xl border p-6">
        <h3 className="font-semibold text-gray-900 mb-4">Fichier</h3>
        <div className="flex items-center gap-3 mb-4">
          <button onClick={() => window.open(d.file_url, '_blank')} className="flex items-center gap-2 px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600"><Eye className="w-4 h-4" /> Visualiser</button>
        </div>
        {isImage && (
          <div className="mt-2">
            <img src={d.file_url} alt={d.title} className="max-h-80 rounded border" />
          </div>
        )}
      </div>

      {/* Danger zone */}
      <div className="bg-white rounded-xl border p-6">
        <h3 className="font-semibold text-red-700 mb-2">Danger</h3>
        <p className="text-sm text-gray-600 mb-3">Supprimer définitivement ce document.</p>
        <button onClick={handleDelete} disabled={deleteMutation.isPending} className="inline-flex items-center gap-2 px-3 py-2 border border-red-300 rounded-lg text-red-700 hover:bg-red-50 disabled:opacity-50"><Trash2 className="w-4 h-4" /> {deleteMutation.isPending ? 'Suppression...' : 'Supprimer'}</button>
      </div>
    </div>
  );
}
