import { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Search, Edit, Trash2, UserCheck, UserX, Users, BookOpen } from 'lucide-react';
import { teachersAPI } from '../../api/teachers';
import { toast } from 'sonner';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import TeacherModal from '../../components/teachers/TeacherModal';
import AssignSubjectsModal from '../../components/teachers/AssignSubjectsModal';
import type { Teacher } from '../../types';

export default function TeachersPage() {
  const queryClient = useQueryClient();
  const [searchTerm, setSearchTerm] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isAssignModalOpen, setIsAssignModalOpen] = useState(false);
  const [selectedTeacher, setSelectedTeacher] = useState<Teacher | null>(null);
  const [filterActive, setFilterActive] = useState<boolean | undefined>(undefined);

  // Récupérer les enseignants (sans filtre de recherche côté API)
  const { data: teachers, isLoading, error } = useQuery({
    queryKey: ['teachers', filterActive],
    queryFn: async () => {
      try {
        const response = await teachersAPI.getAll({ 
          is_active: filterActive 
        });
        console.log('📦 Réponse brute API:', response);
        
        // Extraire le tableau d'enseignants selon le format de réponse
        let teachersList = [];
        if (Array.isArray(response)) {
          teachersList = response;
        } else if (response?.teachers) {
          teachersList = response.teachers;
        } else if (response?.results) {
          teachersList = response.results;
        } else if (response?.data) {
          teachersList = Array.isArray(response.data) ? response.data : [];
        }
        
        console.log('👥 Liste enseignants extraite:', teachersList);
        console.log('📊 Nombre d\'enseignants:', teachersList.length);
        
        return teachersList;
      } catch (err) {
        console.error('❌ Erreur récupération enseignants:', err);
        throw err;
      }
    },
  });

  // Filtrer côté client
  const filteredTeachers = useMemo(() => {
    if (!teachers) return [];
    if (!searchTerm) return teachers;
    
    const search = searchTerm.toLowerCase();
    return teachers.filter((teacher: Teacher) => {
      // Gérer le cas où teacher a un objet user
      const firstName = teacher.first_name || teacher.user?.first_name || '';
      const lastName = teacher.last_name || teacher.user?.last_name || '';
      const username = teacher.username || teacher.user?.username || '';
      const email = teacher.email || teacher.user?.email || '';
      
      return firstName.toLowerCase().includes(search) ||
             lastName.toLowerCase().includes(search) ||
             username.toLowerCase().includes(search) ||
             email.toLowerCase().includes(search);
    });
  }, [teachers, searchTerm]);

  // Mutation pour supprimer
  const deleteMutation = useMutation({
    mutationFn: teachersAPI.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['teachers'] });
      toast.success('Enseignant supprimé avec succès');
    },
    onError: (error: any) => {
      console.error('Erreur suppression:', error);
      
      if (error.response?.status === 404) {
        toast.error('Enseignant introuvable (déjà supprimé?)');
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
    mutationFn: teachersAPI.toggleActive,
    onSuccess: (data) => {
      console.log('✅ Toggle success, nouveau statut:', data);
      queryClient.invalidateQueries({ queryKey: ['teachers'] });
      const isActive = data.is_active ?? data.user?.is_active ?? true;
      toast.success(`Enseignant ${isActive ? 'activé' : 'désactivé'} avec succès`);
    },
    onError: (error: any) => {
      console.error('❌ Erreur toggle active:', error);
      
      if (error.response?.status === 404) {
        toast.error('Enseignant introuvable (déjà supprimé?)');
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

  const handleDelete = (userId: number, name: string) => {
    if (confirm(`Voulez-vous vraiment supprimer l'enseignant "${name}" ?`)) {
      console.log('🗑️ Suppression enseignant user_id:', userId);
      deleteMutation.mutate(userId);
    }
  };

  const handleToggleActive = (teacher: Teacher) => {
    console.log('🔄 Toggle active pour enseignant user_id:', teacher.user_id);
    toggleActiveMutation.mutate(teacher.user_id);
  };

  const handleEdit = (teacher: Teacher) => {
    setSelectedTeacher(teacher);
    setIsModalOpen(true);
  };

  const handleCreate = () => {
    setSelectedTeacher(null);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setSelectedTeacher(null);
  };

  const handleAssignSubjects = (teacher: Teacher) => {
    setSelectedTeacher(teacher);
    setIsAssignModalOpen(true);
  };

  const handleCloseAssignModal = () => {
    setIsAssignModalOpen(false);
    setSelectedTeacher(null);
  };

  if (isLoading) {
    return <LoadingSpinner size="lg" text="Chargement des enseignants..." />;
  }

  if (error) {
    return (
      <div className="space-y-6">
        <h1 className="text-2xl font-bold text-gray-900">Gestion des Enseignants</h1>
        <div className="bg-red-50 border border-red-200 rounded-xl p-6">
          <h3 className="text-lg font-medium text-red-900 mb-2">
            ❌ Erreur de chargement
          </h3>
          <p className="text-red-700">
            Impossible de charger les enseignants. Vérifiez que le backend est démarré.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Gestion des Enseignants</h1>
          <p className="text-gray-600 mt-1">
            {filteredTeachers.length} enseignant(s) {searchTerm && `(${teachers?.length || 0} au total)`}
          </p>
        </div>
        <button
          onClick={handleCreate}
          className="flex items-center space-x-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
        >
          <Plus className="h-5 w-5" />
          <span>Nouvel enseignant</span>
        </button>
      </div>

      {/* Filtres */}
      <div className="bg-white rounded-xl p-4 border border-gray-200 space-y-4">
        {/* Recherche */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
          <input
            type="text"
            placeholder="Rechercher un enseignant..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          />
        </div>

        {/* Filtres statut */}
        <div className="flex items-center space-x-2">
          <span className="text-sm font-medium text-gray-700">Statut :</span>
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

      {/* Table */}
      {filteredTeachers && filteredTeachers.length > 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Nom</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Email</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Téléphone</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Spécialisation</th>
                <th className="text-center py-3 px-4 text-sm font-medium text-gray-600">Matières</th>
                <th className="text-center py-3 px-4 text-sm font-medium text-gray-600">Statut</th>
                <th className="text-right py-3 px-4 text-sm font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredTeachers.map((teacher: Teacher) => {
                // Gérer le cas où les données sont dans teacher.user
                const firstName = teacher.first_name || teacher.user?.first_name || '';
                const lastName = teacher.last_name || teacher.user?.last_name || '';
                const username = teacher.username || teacher.user?.username || '';
                const email = teacher.email || teacher.user?.email || '';
                const isActive = teacher.is_active ?? teacher.user?.is_active ?? true;
                const phone = teacher.phone || teacher.phone_number || '-';
                
                return (
                  <tr key={teacher.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                    <td className="py-3 px-4">
                      <div>
                        <p className="font-medium text-gray-900">
                          {firstName} {lastName}
                        </p>
                        <p className="text-sm text-gray-500">@{username}</p>
                      </div>
                    </td>
                    <td className="py-3 px-4 text-sm text-gray-600">{email}</td>
                    <td className="py-3 px-4 text-sm text-gray-600">{phone}</td>
                    <td className="py-3 px-4 text-sm text-gray-600">{teacher.specialization || '-'}</td>
                    <td className="py-3 px-4 text-center">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleAssignSubjects(teacher);
                        }}
                        className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800 hover:bg-purple-200 transition-colors cursor-pointer"
                        title="Cliquez pour voir/gérer les matières"
                      >
                        📚 {teacher.total_assignments || teacher.total_subjects || 0}
                      </button>
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
                          handleAssignSubjects(teacher);
                        }}
                        className="p-2 text-purple-600 hover:bg-purple-50 rounded-lg transition-colors"
                        title="Assigner matières"
                      >
                        <BookOpen className="h-4 w-4" />
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleToggleActive(teacher);
                        }}
                        className={`p-2 rounded-lg transition-colors ${
                          teacher.is_active
                            ? 'text-orange-600 hover:bg-orange-50'
                            : 'text-green-600 hover:bg-green-50'
                        }`}
                        title={teacher.is_active ? 'Désactiver' : 'Activer'}
                      >
                        {teacher.is_active ? <UserX className="h-4 w-4" /> : <UserCheck className="h-4 w-4" />}
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleEdit(teacher);
                        }}
                        className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                        title="Modifier"
                      >
                        <Edit className="h-4 w-4" />
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleDelete(teacher.user_id, `${firstName} ${lastName}`);
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
            Aucun enseignant trouvé
          </h3>
          <p className="text-gray-600 mb-6">
            Commencez par créer votre premier enseignant
          </p>
          <button
            onClick={handleCreate}
            className="inline-flex items-center space-x-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
          >
            <Plus className="h-5 w-5" />
            <span>Créer un enseignant</span>
          </button>
        </div>
      )}

      {/* Modal Création/Édition */}
      {isModalOpen && (
        <TeacherModal
          teacher={selectedTeacher}
          onClose={handleCloseModal}
          onSuccess={() => {
            queryClient.invalidateQueries({ queryKey: ['teachers'] });
            handleCloseModal();
          }}
        />
      )}

      {/* Modal Assignation */}
      {isAssignModalOpen && selectedTeacher && (
        <AssignSubjectsModal
          teacher={selectedTeacher}
          onClose={handleCloseAssignModal}
        />
      )}
    </div>
  );
}
