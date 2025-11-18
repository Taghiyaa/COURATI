import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Plus, Search, Edit, Trash2, GraduationCap } from 'lucide-react';
import { levelsAPI } from '../../api/levels';
import { toast } from 'sonner';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import LevelModal from '../../components/levels/LevelModal';
import type { Level } from '../../types';

export default function LevelsPage() {
  const queryClient = useQueryClient();
  const [searchTerm, setSearchTerm] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedLevel, setSelectedLevel] = useState<Level | null>(null);

  // Récupérer les niveaux
  const { data: levels, isLoading } = useQuery({
    queryKey: ['levels'],
    queryFn: levelsAPI.getAll,
  });

  // Mutation pour supprimer
  const deleteMutation = useMutation({
    mutationFn: levelsAPI.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['levels'] });
      toast.success('Niveau supprimé avec succès');
    },
    onError: () => {
      toast.error('Erreur lors de la suppression');
    },
  });

  const handleDelete = (id: number, name: string) => {
    if (confirm(`Voulez-vous vraiment supprimer le niveau "${name}" ?`)) {
      deleteMutation.mutate(id);
    }
  };

  const handleEdit = (level: Level) => {
    setSelectedLevel(level);
    setIsModalOpen(true);
  };

  const handleCreate = () => {
    setSelectedLevel(null);
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setSelectedLevel(null);
  };

  // Filtrer les niveaux
  const filteredLevels = levels?.filter((level: Level) =>
    level.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    level.code.toLowerCase().includes(searchTerm.toLowerCase())
  ) || [];

  if (isLoading) {
    return <LoadingSpinner size="lg" text="Chargement des niveaux..." />;
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Niveaux Académiques</h1>
          <p className="text-gray-600 mt-1">
            {filteredLevels.length} niveau(x) au total
          </p>
        </div>
        <button
          onClick={handleCreate}
          className="flex items-center space-x-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
        >
          <Plus className="h-5 w-5" />
          <span>Créer niveau</span>
        </button>
      </div>

      {/* Barre de recherche */}
      <div className="bg-white rounded-xl p-4 border border-gray-200">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
          <input
            type="text"
            placeholder="Rechercher un niveau..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          />
        </div>
      </div>

      {/* Table */}
      {filteredLevels.length > 0 ? (
        <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
          <table className="w-full">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Code</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Nom</th>
                <th className="text-left py-3 px-4 text-sm font-medium text-gray-600">Description</th>
                <th className="text-center py-3 px-4 text-sm font-medium text-gray-600">Ordre</th>
                <th className="text-right py-3 px-4 text-sm font-medium text-gray-600">Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredLevels
                .sort((a: Level, b: Level) => a.order - b.order)
                .map((level: Level) => (
                  <tr key={level.id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                    <td className="py-3 px-4">
                      <span className="inline-flex items-center px-2.5 py-0.5 rounded-md text-sm font-medium bg-primary-100 text-primary-800">
                        {level.code}
                      </span>
                    </td>
                    <td className="py-3 px-4 font-medium text-gray-900">{level.name}</td>
                    <td className="py-3 px-4 text-sm text-gray-600 max-w-md truncate">
                      {level.description || '-'}
                    </td>
                    <td className="py-3 px-4 text-center text-sm text-gray-600">{level.order}</td>
                    <td className="py-3 px-4">
                      <div className="flex items-center justify-end space-x-2">
                        <button
                          onClick={() => handleEdit(level)}
                          className="p-2 text-primary-600 hover:bg-primary-50 rounded-lg transition-colors"
                          title="Modifier"
                        >
                          <Edit className="h-4 w-4" />
                        </button>
                        <button
                          onClick={() => handleDelete(level.id, level.name)}
                          disabled={deleteMutation.isPending}
                          className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-50"
                          title="Supprimer"
                        >
                          <Trash2 className="h-4 w-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="bg-white rounded-xl p-12 border border-gray-200 text-center">
          <GraduationCap className="h-12 w-12 text-gray-400 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-gray-900 mb-2">
            Aucun niveau trouvé
          </h3>
          <p className="text-gray-600 mb-6">
            Commencez par créer votre premier niveau académique
          </p>
          <button
            onClick={handleCreate}
            className="inline-flex items-center space-x-2 px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
          >
            <Plus className="h-5 w-5" />
            <span>Créer un niveau</span>
          </button>
        </div>
      )}

      {/* Modal */}
      {isModalOpen && (
        <LevelModal
          level={selectedLevel}
          onClose={handleCloseModal}
          onSuccess={() => {
            queryClient.invalidateQueries({ queryKey: ['levels'] });
            handleCloseModal();
          }}
        />
      )}
    </div>
  );
}
