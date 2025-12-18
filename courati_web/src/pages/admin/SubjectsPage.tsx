import { useEffect, useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Search, Edit, Trash2, BookOpen } from 'lucide-react';
import { subjectsAPI } from '../../api/subjects';
import { levelsAPI } from '../../api/levels';
import { majorsAPI } from '../../api/majors';
import { toast } from 'sonner';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import SubjectModal from '../../components/subjects/SubjectModal';
import type { Subject } from '../../types';

export default function SubjectsPage() {
  const queryClient = useQueryClient();
  const [searchTerm, setSearchTerm] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [filterLevel, setFilterLevel] = useState<string>('');
  const [filterMajor, setFilterMajor] = useState<string>('');
  const [selectedSubject, setSelectedSubject] = useState<Subject | null>(null);

  // Récupérer les matières
  const { data: subjects, isLoading, isFetching, error } = useQuery({
    queryKey: ['subjects', debouncedSearch, filterLevel, filterMajor],
    queryFn: async () => {
      try {
        const params: any = { search: debouncedSearch };
        if (filterLevel) params.level = filterLevel;
        if (filterMajor) params.major = filterMajor;
        const data = await subjectsAPI.getAll(params);
        console.log('Matières récupérées:', data);
        return data;
      } catch (err) {
        console.error('Erreur récupération matières:', err);
        throw err;
      }
    },
    placeholderData: (prev) => prev as any,
  });

  // Charger niveaux et filières pour filtres
  const { data: levelsResp } = useQuery({
    queryKey: ['levels'],
    queryFn: levelsAPI.getAll,
  });
  const { data: majorsResp } = useQuery({
    queryKey: ['majors'],
    queryFn: majorsAPI.getAll,
  });

  const levels = Array.isArray(levelsResp)
    ? levelsResp
    : (levelsResp as any)?.levels || (levelsResp as any)?.results || [];
  const majors = Array.isArray(majorsResp)
    ? majorsResp
    : (majorsResp as any)?.majors || (majorsResp as any)?.results || [];

  // Debounce search
  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(searchTerm), 500);
    return () => clearTimeout(t);
  }, [searchTerm]);

  // Afficher l'erreur si elle existe
  if (error) {
    console.error('Erreur Query:', error);
  }

  // Mutation pour supprimer
  const deleteMutation = useMutation({
    mutationFn: subjectsAPI.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subjects'] });
      toast.success('Matière supprimée avec succès');
    },
    onError: () => {
      toast.error('Erreur lors de la suppression');
    },
  });

  const handleDelete = (id: number, name: string) => {
    if (confirm(`Voulez-vous vraiment supprimer la matière "${name}" ?`)) {
      deleteMutation.mutate(id);
    }
  };

  const handleEdit = (subject: Subject) => {
    setSelectedSubject(subject);
    setIsModalOpen(true);
  };

  const handleCreate = () => {
    setSelectedSubject(null);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setSelectedSubject(null);
  };

  if (!subjects && isLoading) {
    return <LoadingSpinner size="lg" text="Chargement des matières..." />;
  }

  // Afficher l'erreur
  if (error) {
    return (
      <div className="space-y-6">
        <h1 className="text-2xl font-bold text-gray-900">Gestion des Matières</h1>
        <div className="bg-red-50 border border-red-200 rounded-xl p-6">
          <h3 className="text-lg font-medium text-red-900 mb-2">
            ❌ Erreur de chargement
          </h3>
          <p className="text-red-700 mb-4">
            Impossible de charger les matières. Vérifiez que le backend est démarré.
          </p>
          <pre className="bg-red-100 p-4 rounded text-sm text-red-800 overflow-auto">
            {JSON.stringify(error, null, 2)}
          </pre>
          <button
            onClick={() => window.location.reload()}
            className="mt-4 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
          >
            Réessayer
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Gestion des Matières</h1>
          <p className="text-gray-600 mt-1">
            {subjects?.length || 0} matière(s) au total
          </p>
        </div>
        <button
          onClick={handleCreate}
          className="flex items-center space-x-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
        >
          <Plus className="h-5 w-5" />
          <span>Nouvelle Matière</span>
        </button>
      </div>

      {/* Barre de recherche */}
      <div className="bg-white rounded-xl p-4 border border-gray-200">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
          <input
            type="text"
            placeholder="Rechercher une matière..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          />
          {(isFetching || searchTerm !== debouncedSearch) && (
            <div className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 rounded-full border-2 border-gray-300 border-t-transparent animate-spin" />
          )}
        </div>
        <div className="mt-3 grid grid-cols-1 sm:grid-cols-2 gap-3">
          <select
            value={filterLevel}
            onChange={(e) => setFilterLevel(e.target.value)}
            className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500"
          >
            <option value="">Tous les niveaux</option>
            {(levels as any[]).map((lvl: any) => (
              <option key={lvl.id} value={String(lvl.id)}>{lvl.name || lvl.code}</option>
            ))}
          </select>
          <select
            value={filterMajor}
            onChange={(e) => setFilterMajor(e.target.value)}
            className="px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500"
          >
            <option value="">Toutes les filières</option>
            {(majors as any[]).map((mj: any) => (
              <option key={mj.id} value={String(mj.id)}>{mj.name || mj.code}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Liste des matières */}
      {subjects && subjects.length > 0 ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {subjects.map((subject: Subject) => (
            <div
              key={subject.id}
              className="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-shadow"
            >
              {/* Header */}
              <div className="flex items-start justify-between mb-4">
                <div className="flex items-center space-x-3">
                  <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
                    <BookOpen className="h-6 w-6 text-purple-600" />
                  </div>
                  <div>
                    <h3 className="font-semibold text-gray-900">{subject.name}</h3>
                    <p className="text-sm text-gray-500">{subject.code}</p>
                  </div>
                </div>
              </div>

              {/* Infos */}
              <div className="space-y-3 mb-4">
                {/* Niveaux */}
                <div>
                  <span className="text-xs font-medium text-gray-500 uppercase">Niveaux</span>
                  <div className="flex flex-wrap gap-1 mt-1">
                    {(subject as any).level_names?.map((level: string, idx: number) => (
                      <span
                        key={idx}
                        className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-primary-100 text-primary-800"
                      >
                        {level}
                      </span>
                    )) || <span className="text-sm text-gray-400">Aucun</span>}
                  </div>
                </div>

                {/* Filières */}
                <div>
                  <span className="text-xs font-medium text-gray-500 uppercase">Filières</span>
                  <div className="flex flex-wrap gap-1 mt-1">
                    {(subject as any).major_names?.map((major: string, idx: number) => (
                      <span
                        key={idx}
                        className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800"
                      >
                        {major}
                      </span>
                    )) || <span className="text-sm text-gray-400">Aucune</span>}
                  </div>
                </div>

                {/* Crédits */}
                {(subject as any).credits && (
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-600">Crédits</span>
                    <span className="font-medium text-gray-900">{(subject as any).credits}</span>
                  </div>
                )}
              </div>

              {/* Description */}
              {subject.description && (
                <p className="text-sm text-gray-600 mb-4 line-clamp-2">
                  {subject.description}
                </p>
              )}

              {/* Actions */}
              <div className="flex items-center space-x-2 pt-4 border-t border-gray-100">
                <button
                  onClick={() => handleEdit(subject)}
                  className="flex-1 flex items-center justify-center space-x-2 px-3 py-2 bg-primary-50 text-primary-600 rounded-lg hover:bg-primary-100 transition-colors"
                >
                  <Edit className="h-4 w-4" />
                  <span className="text-sm font-medium">Modifier</span>
                </button>
                <button
                  onClick={() => handleDelete(subject.id, subject.name)}
                  disabled={deleteMutation.isPending}
                  className="flex-1 flex items-center justify-center space-x-2 px-3 py-2 bg-red-50 text-red-600 rounded-lg hover:bg-red-100 transition-colors disabled:opacity-50"
                >
                  <Trash2 className="h-4 w-4" />
                  <span className="text-sm font-medium">Supprimer</span>
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="bg-white rounded-xl p-12 border border-gray-200 text-center">
          <BookOpen className="h-12 w-12 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            Aucune matière trouvée
          </h3>
          <p className="text-gray-600 mb-6">
            Commencez par créer votre première matière
          </p>
          <button
            onClick={handleCreate}
            className="inline-flex items-center space-x-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
          >
            <Plus className="h-5 w-5" />
            <span>Créer une matière</span>
          </button>
        </div>
      )}

      {/* Modal */}
      {isModalOpen && (
        <SubjectModal
          subject={selectedSubject}
          onClose={handleCloseModal}
          onSuccess={() => {
            queryClient.invalidateQueries({ queryKey: ['subjects'] });
            handleCloseModal();
          }}
        />
      )}
    </div>
  );
}
