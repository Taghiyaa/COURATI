import { useState, useMemo, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Search, Edit, Trash2, UserCheck, UserX, Users, Download } from 'lucide-react';
import { studentsAPI } from '../../api/students';
import { levelsAPI } from '../../api/levels';
import { majorsAPI } from '../../api/majors';
import { toast } from 'sonner';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import StudentModal from '../../components/students/StudentModal';
import type { Student } from '../../types';
import { Link } from 'react-router-dom';

export default function StudentsPage() {
  const queryClient = useQueryClient();
  const [searchTerm, setSearchTerm] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedStudent, setSelectedStudent] = useState<Student | null>(null);
  const [filterLevel, setFilterLevel] = useState<number | undefined>(undefined);
  const [filterMajor, setFilterMajor] = useState<number | undefined>(undefined);
  const [filterActive, setFilterActive] = useState<boolean | undefined>(undefined);
  const [selectedIds, setSelectedIds] = useState<number[]>([]);

  // Récupérer les étudiants
  const { 
    data: response, 
    isLoading, 
    isFetching,
    error
  } = useQuery({
    queryKey: ['students', debouncedSearch, filterLevel, filterMajor, filterActive],
    enabled: true,
    queryFn: async () => {
      try {
        const params = {
          search: debouncedSearch || undefined,
          level_id: filterLevel,
          major_id: filterMajor,
          is_active: filterActive,
        };
        
        console.log('🔍 Paramètres envoyés à l\'API:', params);
        
        const response = await studentsAPI.getAll(params);
        console.log('📦 Réponse API étudiants:', response);
        return response;
      } catch (error) {
        console.error('❌ Erreur récupération étudiants:', error);
        throw error;
      }
    },
    placeholderData: (prev) => prev as any,
  });

  // Debounce search
  useEffect(() => {
    const t = setTimeout(() => setDebouncedSearch(searchTerm), 500);
    return () => clearTimeout(t);
  }, [searchTerm]);

  // Extraire la liste des étudiants
  const students = useMemo(() => {
    if (!response) return [];
    if (Array.isArray(response)) return response;
    if (response?.students) return response.students;
    if (response?.results) return response.results;
    if (response?.data) return Array.isArray(response.data) ? response.data : [];
    console.warn('Format de réponse inattendu:', response);
    return [];
  }, [response]);

  // Charger niveaux et filières pour les filtres
  const { data: levels = [] } = useQuery({
    queryKey: ['levels'],
    queryFn: async () => {
      try {
        const response = await levelsAPI.getAll();
        console.log('📚 Niveaux récupérés:', response);
        return response;
      } catch (error) {
        console.error('❌ Erreur récupération niveaux:', error);
        throw error;
      }
    },
  });

  const { data: majors = [] } = useQuery({
    queryKey: ['majors'],
    queryFn: async () => {
      try {
        const response = await majorsAPI.getAll();
        console.log('🎓 Filières récupérées:', response);
        return response;
      } catch (error) {
        console.error('❌ Erreur récupération filières:', error);
        throw error;
      }
    },
  });

  // Utiliser directement les étudiants filtrés côté serveur
  const filteredStudents = students || [];

  // Mutation pour supprimer
  const deleteMutation = useMutation({
    mutationFn: studentsAPI.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['students'] });
      toast.success('Étudiant supprimé avec succès');
    },
    onError: (error: any) => {
      console.error('Erreur suppression:', error);
      
      if (error.response?.status === 404) {
        toast.error('Étudiant introuvable (déjà supprimé?)');
      } else {
        const errorMsg = error.response?.data?.message || 
                         error.response?.data?.error ||
                         error.response?.data?.detail ||
                         error.message ||
                         'Erreur lors de la suppression';
        toast.error(errorMsg);
      }
    },
  });

  // Mutation pour activer/désactiver
  const toggleActiveMutation = useMutation({
    mutationFn: studentsAPI.toggleActive,
    onSuccess: (data) => {
      console.log('✅ Toggle success, nouveau statut:', data);
      queryClient.invalidateQueries({ queryKey: ['students'] });
      const isActive = data.is_active ?? data.user?.is_active ?? true;
      toast.success(`Étudiant ${isActive ? 'activé' : 'désactivé'} avec succès`);
    },
    onError: (error: any) => {
      console.error('❌ Erreur toggle active:', error);
      
      if (error.response?.status === 404) {
        toast.error('Étudiant introuvable (déjà supprimé?)');
      } else {
        const errorMsg = error.response?.data?.message || 
                         error.response?.data?.error ||
                         error.response?.data?.detail ||
                         error.message ||
                         'Erreur lors de la modification du statut';
        toast.error(errorMsg);
      }
    },
  });

  // Mutation pour actions en masse
  const bulkActionMutation = useMutation({
    mutationFn: ({ action, ids }: { action: 'activate' | 'deactivate' | 'delete'; ids: number[] }) =>
      studentsAPI.bulkAction(action, ids),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['students'] });
      setSelectedIds([]);
      const actionText = variables.action === 'activate' ? 'activés' :
                        variables.action === 'deactivate' ? 'désactivés' : 'supprimés';
      toast.success(`${variables.ids.length} étudiant(s) ${actionText} avec succès`);
    },
    onError: (error: any) => {
      const errorMsg = error.response?.data?.message || 
                       error.response?.data?.error ||
                       'Erreur lors de l\'action en masse';
      toast.error(errorMsg);
    },
  });

  const handleDelete = (userId: number, name: string) => {
    if (confirm(`Voulez-vous vraiment supprimer l'étudiant "${name}" ?`)) {
      console.log('🗑️ Suppression étudiant user_id:', userId);
      deleteMutation.mutate(userId);
    }
  };

  const handleToggleActive = (student: Student) => {
    console.log('🔄 Toggle active pour étudiant id:', student.id);
    toggleActiveMutation.mutate(student.id);
  };

  const handleEdit = (student: Student) => {
    setSelectedStudent(student);
    setIsModalOpen(true);
  };

  const handleCreate = () => {
    setSelectedStudent(null);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setSelectedStudent(null);
  };

  const handleSelectAll = () => {
    if (selectedIds.length === filteredStudents.length) {
      setSelectedIds([]);
    } else {
      setSelectedIds(filteredStudents.map((s: Student) => s.id));
    }
  };

  const handleSelectOne = (userId: number) => {
    setSelectedIds(prev =>
      prev.includes(userId) ? prev.filter(id => id !== userId) : [...prev, userId]
    );
  };

  const handleBulkAction = (action: 'activate' | 'deactivate' | 'delete') => {
    if (selectedIds.length === 0) {
      toast.error('Aucun étudiant sélectionné');
      return;
    }

    const actionText = action === 'activate' ? 'activer' :
                      action === 'deactivate' ? 'désactiver' : 'supprimer';
    
    if (confirm(`Voulez-vous vraiment ${actionText} ${selectedIds.length} étudiant(s) ?`)) {
      bulkActionMutation.mutate({ action, ids: selectedIds });
    }
  };

  const handleExport = async () => {
    try {
      console.log('📥 Début export CSV avec filtres:', { filterLevel, filterMajor, filterActive });
      
      const blob = await studentsAPI.exportCSV({
        level_id: filterLevel,
        major_id: filterMajor,
        is_active: filterActive,
      });
      
      console.log('✅ Blob reçu:', blob);
      
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `etudiants_${new Date().toISOString().split('T')[0]}.csv`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
      
      toast.success('Export réussi');
    } catch (error: any) {
      console.error('❌ Erreur export:', error);
      const errorMsg = error.response?.data?.message || 
                       error.response?.data?.error ||
                       error.message ||
                       'Erreur lors de l\'export';
      toast.error(errorMsg);
    }
  };

  if (!response && isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600">Erreur: {(error as Error).message}</div>;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Gestion des Étudiants</h1>
          <p className="text-gray-600 mt-1">
            {filteredStudents.length} étudiant(s) {searchTerm && `(${students?.length || 0} au total)`}
          </p>
        </div>
        <div className="flex items-center space-x-3">
          <button
            onClick={handleExport}
            className="flex items-center space-x-2 px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors"
          >
            <Download className="h-5 w-5" />
            <span>Exporter</span>
          </button>
          <button
            onClick={handleCreate}
            className="flex items-center space-x-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
          >
            <Plus className="h-5 w-5" />
            <span>Nouvel étudiant</span>
          </button>
        </div>
      </div>

      {/* Filtres et recherche */}
      <div className="bg-white p-4 rounded-xl border border-gray-200 space-y-4">
        <div className="flex flex-wrap items-center gap-4">
          {/* Recherche */}
          <div className="flex-1 min-w-[300px]">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
              <input
                type="text"
                placeholder="Rechercher par nom, email..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-10 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
              {(isFetching || searchTerm !== debouncedSearch) && (
                <div className="absolute right-3 top-1/2 -translate-y-1/2 h-4 w-4 rounded-full border-2 border-gray-300 border-t-transparent animate-spin" />
              )}
            </div>
          </div>

          {/* Filtre Niveau */}
          <select
            value={filterLevel || ''}
            onChange={(e) => {
              const newValue = e.target.value ? Number(e.target.value) : undefined;
              console.log('🏫 Changement filtre niveau:', newValue);
              setFilterLevel(newValue);
            }}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500"
          >
            <option value="">Tous les niveaux</option>
            {levels.map((level: any) => (
              <option key={level.id} value={level.id}>{level.name}</option>
            ))}
          </select>

          {/* Filtre Filière */}
          <select
            value={filterMajor || ''}
            onChange={(e) => {
              const newValue = e.target.value ? Number(e.target.value) : undefined;
              console.log('🎓 Changement filtre filière:', newValue);
              setFilterMajor(newValue);
            }}
            className="px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500"
          >
            <option value="">Toutes les filières</option>
            {majors.map((major: any) => (
              <option key={major.id} value={major.id}>{major.name}</option>
            ))}
          </select>

          {/* Filtre Statut */}
          <div className="flex items-center space-x-2">
            <button
              onClick={() => setFilterActive(undefined)}
              className={`px-3 py-1 rounded-lg text-sm transition-colors ${
                filterActive === undefined
                  ? 'bg-primary-500 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              Tous
            </button>
            <button
              onClick={() => setFilterActive(true)}
              className={`px-3 py-1 rounded-lg text-sm transition-colors ${
                filterActive === true
                  ? 'bg-green-500 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              Actifs
            </button>
            <button
              onClick={() => setFilterActive(false)}
              className={`px-3 py-1 rounded-lg text-sm transition-colors ${
                filterActive === false
                  ? 'bg-red-500 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              Inactifs
            </button>
          </div>
        </div>

        {/* Actions en masse */}
        {selectedIds.length > 0 && (
          <div className="flex items-center justify-between p-3 bg-primary-50 rounded-lg border border-primary-200">
            <span className="text-sm font-medium text-primary-900">
              {selectedIds.length} étudiant(s) sélectionné(s)
            </span>
            <div className="flex items-center space-x-2">
              <button
                onClick={() => handleBulkAction('activate')}
                className="px-3 py-1 bg-green-500 text-white rounded-lg hover:bg-green-600 text-sm"
              >
                Activer
              </button>
              <button
                onClick={() => handleBulkAction('deactivate')}
                className="px-3 py-1 bg-orange-500 text-white rounded-lg hover:bg-orange-600 text-sm"
              >
                Désactiver
              </button>
              <button
                onClick={() => handleBulkAction('delete')}
                className="px-3 py-1 bg-red-500 text-white rounded-lg hover:bg-red-600 text-sm"
              >
                Supprimer
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Table */}
      {filteredStudents && filteredStudents.length > 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-4">
                  <input
                    type="checkbox"
                    checked={selectedIds.length === filteredStudents.length}
                    onChange={handleSelectAll}
                    className="h-4 w-4 text-primary-600 rounded"
                  />
                </th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Nom</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Email</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Niveau</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Filière</th>
                <th className="text-center py-3 px-4 text-sm font-medium text-gray-600">Statut</th>
                <th className="text-right py-3 px-4 text-sm font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredStudents.map((student: Student) => {
                const firstName = student.first_name || '';
                const lastName = student.last_name || '';
                const username = student.username || '';
                const email = student.email || '';
                const isActive = student.is_active ?? true;
                const levelName = student.level_name || student.level?.name || '-';
                const majorName = student.major_name || student.major?.name || '-';
                
                return (
                  <tr key={student.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                    <td className="py-3 px-4">
                      <input
                        type="checkbox"
                        checked={selectedIds.includes(student.id)}
                        onChange={() => handleSelectOne(student.id)}
                        className="h-4 w-4 text-primary-600 rounded"
                      />
                    </td>
                    <td className="py-3 px-4">
                      <div>
                        <Link to={`/admin/students/${student.id}`} className="font-medium text-primary-600 hover:underline">
                          {firstName} {lastName}
                        </Link>
                        <p className="text-sm text-gray-500">@{username}</p>
                      </div>
                    </td>
                    <td className="py-3 px-4 text-sm text-gray-600">{email}</td>
                    <td className="py-3 px-4 text-sm text-gray-600">
                      {levelName}
                    </td>
                    <td className="py-3 px-4 text-sm text-gray-600">
                      {majorName}
                    </td>
                    <td className="py-3 px-4 text-center">
                      <span
                        className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                          isActive
                            ? 'bg-green-100 text-green-800'
                            : 'bg-red-100 text-red-800'
                        }`}
                      >
                        {isActive ? 'Actif' : 'Inactif'}
                      </span>
                    </td>
                    <td className="py-3 px-4">
                      <div className="flex items-center justify-end space-x-2">
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleToggleActive(student);
                          }}
                          className={`p-2 rounded-lg transition-colors ${
                            isActive
                              ? 'text-orange-600 hover:bg-orange-50'
                              : 'text-green-600 hover:bg-green-50'
                          }`}
                          title={isActive ? 'Désactiver' : 'Activer'}
                        >
                          {isActive ? <UserX className="h-4 w-4" /> : <UserCheck className="h-4 w-4" />}
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleEdit(student);
                          }}
                          className="p-2 text-primary-600 hover:bg-primary-50 rounded-lg transition-colors"
                          title="Modifier"
                        >
                          <Edit className="h-4 w-4" />
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            handleDelete(student.id, `${firstName} ${lastName}`);
                          }}
                          disabled={deleteMutation.isPending}
                          className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-50"
                          title="Supprimer"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="bg-white rounded-xl p-12 border border-gray-200 text-center">
          <Users className="h-12 w-12 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            Aucun étudiant trouvé
          </h3>
          <p className="text-gray-600 mb-6">
            Commencez par créer votre premier étudiant
          </p>
          <button
            onClick={handleCreate}
            className="inline-flex items-center space-x-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
          >
            <Plus className="h-5 w-5" />
            <span>Créer un étudiant</span>
          </button>
        </div>
      )}

      {/* Modal Création/Édition */}
      {isModalOpen && (
        <StudentModal
          student={selectedStudent}
          onClose={handleCloseModal}
          onSuccess={() => {
            queryClient.invalidateQueries({ queryKey: ['students'] });
            handleCloseModal();
          }}
        />
      )}
    </div>
  );
}
