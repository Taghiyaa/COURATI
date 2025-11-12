import { useState, useEffect, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { X, BookOpen } from 'lucide-react';
import { teachersAPI } from '../../api/teachers';
import { subjectsAPI } from '../../api/subjects';
import { toast } from 'sonner';
import type { Teacher, Subject } from '../../types';

interface AssignSubjectsModalProps {
  teacher: Teacher;
  onClose: () => void;
}

export default function AssignSubjectsModal({ teacher, onClose }: AssignSubjectsModalProps) {
  const queryClient = useQueryClient();
  const [selectedSubjects, setSelectedSubjects] = useState<number[]>([]);

  // Charger toutes les matières
  const { data: allSubjects = [] } = useQuery({
    queryKey: ['subjects'],
    queryFn: async () => {
      console.log('📖 Chargement de toutes les matières...');
      const subjects = await subjectsAPI.getAll();
      console.log('📚 Toutes les matières chargées:', subjects);
      return subjects;
    },
  });

  // Charger les assignations de l'enseignant
  const { data: assignmentsData, isLoading } = useQuery({
    queryKey: ['teacher-assignments', teacher.user_id],
    queryFn: async () => {
      console.log('📚 Récupération assignations pour user_id:', teacher.user_id);
      const response = await teachersAPI.getAssignments(teacher.user_id);
      console.log('📦 Réponse assignations brute:', response);
      return response;
    },
  });

  // Extraire les IDs des matières depuis les assignations
  const teacherSubjectIds = useMemo(() => {
    if (!assignmentsData) return [];
    
    // Le backend retourne { teacher: { assignments: [...] } }
    let assignments = [];
    if (assignmentsData.teacher?.assignments) {
      assignments = assignmentsData.teacher.assignments;
    } else if (assignmentsData.assignments) {
      assignments = assignmentsData.assignments;
    } else if (Array.isArray(assignmentsData)) {
      assignments = assignmentsData;
    }
    
    console.log('📋 Assignations extraites:', assignments);
    
    // Les assignations contiennent { subject: 5, subject_name: "...", ... }
    // On extrait juste les IDs
    const subjectIds = assignments
      .map((a: any) => a.subject)
      .filter(Boolean);
    
    console.log('🔢 IDs matières extraits:', subjectIds);
    return subjectIds;
  }, [assignmentsData]);

  // Pré-sélectionner les matières actuelles
  useEffect(() => {
    console.log('🔄 useEffect déclenché');
    console.log('🔢 teacherSubjectIds:', teacherSubjectIds);
    console.log('📖 allSubjects:', allSubjects);
    
    if (teacherSubjectIds.length > 0) {
      console.log('✅ Sélection des IDs:', teacherSubjectIds);
      setSelectedSubjects(teacherSubjectIds);
    } else {
      console.log('⚠️ teacherSubjectIds est vide');
    }
  }, [teacherSubjectIds, allSubjects]);

  // Mutation pour assigner
  const assignMutation = useMutation({
    mutationFn: async (subjectId: number) => {
      console.log(`Tentative d'assignation: matière ${subjectId} -> enseignant user_id ${teacher.user_id}`);
      return teachersAPI.createAssignment(teacher.user_id, { subject_id: subjectId });
    },
    onSuccess: (_data, subjectId) => {
      console.log(`Assignation réussie pour matière ${subjectId}`);
      queryClient.invalidateQueries({ queryKey: ['teacher-assignments', teacher.user_id] });
      queryClient.invalidateQueries({ queryKey: ['teachers'] });
      toast.success('Matière assignée avec succès');
    },
    onError: (error: any, subjectId) => {
      console.error(`Erreur assignation matière ${subjectId}:`, error);
      console.error('Détails:', error.response?.data);
      
      if (error.response?.status === 404) {
        toast.error('Enseignant ou matière introuvable');
      } else {
        const errorMsg = error.response?.data?.message || 
                         error.response?.data?.error ||
                         error.response?.data?.detail ||
                         error.message ||
                         "Erreur lors de l'assignation";
        toast.error(errorMsg);
      }
    },
  });

  // Mutation pour retirer (nécessite l'ID de l'assignation)
  const removeMutation = useMutation({
    mutationFn: async (subjectId: number) => {
      console.log(`Tentative de retrait: matière ${subjectId} <- enseignant user_id ${teacher.user_id}`);
      // Note: Pour retirer, on devrait avoir l'ID de l'assignation
      // Pour l'instant, on va juste invalider le cache
      // TODO: Implémenter la logique de retrait avec l'ID d'assignation
      throw new Error('Fonctionnalité de retrait non implémentée - utilisez le backend pour retirer');
    },
    onSuccess: (_data, subjectId) => {
      console.log(`Retrait réussi pour matière ${subjectId}`);
      queryClient.invalidateQueries({ queryKey: ['teacher-assignments', teacher.user_id] });
      queryClient.invalidateQueries({ queryKey: ['teachers'] });
      toast.success('Matière retirée avec succès');
    },
    onError: (error: any, subjectId) => {
      console.error(`Erreur retrait matière ${subjectId}:`, error);
      console.error('Détails:', error.response?.data);
      
      if (error.response?.status === 404) {
        toast.error('Assignation introuvable (déjà supprimée?)');
      } else {
        const errorMsg = error.response?.data?.message || 
                         error.response?.data?.error ||
                         error.response?.data?.detail ||
                         error.message ||
                         'Erreur lors du retrait';
        toast.error(errorMsg);
      }
    },
  });

  const handleToggleSubject = (subjectId: number) => {
    if (selectedSubjects.includes(subjectId)) {
      removeMutation.mutate(subjectId);
      setSelectedSubjects(prev => prev.filter(id => id !== subjectId));
    } else {
      assignMutation.mutate(subjectId);
      setSelectedSubjects(prev => [...prev, subjectId]);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between p-6 border-b border-gray-200 sticky top-0 bg-white">
          <div>
            <h2 className="text-xl font-bold text-gray-900">Matières de l'enseignant</h2>
            <p className="text-sm text-gray-600 mt-1">
              {teacher.first_name || teacher.user?.first_name} {teacher.last_name || teacher.user?.last_name}
            </p>
            <p className="text-xs text-purple-600 font-medium mt-1">
              {selectedSubjects.length} matière(s) assignée(s)
            </p>
          </div>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg transition-colors">
            <X className="h-5 w-5 text-gray-500" />
          </button>
        </div>

        <div className="p-6">
          {isLoading || allSubjects.length === 0 ? (
            <div className="text-center py-8">
              <BookOpen className="h-12 w-12 text-gray-400 mx-auto mb-4 animate-pulse" />
              <p className="text-gray-500">
                {isLoading ? 'Chargement des assignations...' : 'Chargement des matières...'}
              </p>
              <p className="text-xs text-gray-400 mt-2">
                Assignations: {assignmentsData ? '✓' : '...'} | 
                Matières: {allSubjects.length > 0 ? '✓' : '...'}
              </p>
            </div>
          ) : (
            <>
              {/* Section matières assignées */}
              {selectedSubjects.length > 0 && (
                <div className="mb-6 p-4 bg-purple-50 rounded-lg border border-purple-200">
                  <h3 className="text-sm font-semibold text-purple-900 mb-3 flex items-center">
                    <BookOpen className="h-4 w-4 mr-2" />
                    Matières actuellement assignées ({selectedSubjects.length})
                  </h3>
                  <div className="flex flex-wrap gap-2">
                    {(() => {
                      const assignedSubjects = allSubjects.filter((s: Subject) => selectedSubjects.includes(s.id));
                      console.log('🎯 Matières filtrées pour affichage:', assignedSubjects);
                      console.log('🔢 IDs sélectionnés:', selectedSubjects);
                      console.log('📚 Toutes matières disponibles:', allSubjects);
                      
                      if (assignedSubjects.length === 0) {
                        return <p className="text-sm text-gray-500">Chargement des matières...</p>;
                      }
                      
                      return assignedSubjects.map((subject: Subject) => (
                        <span
                          key={subject.id}
                          className="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-purple-600 text-white"
                        >
                          {subject.code} - {subject.name}
                        </span>
                      ));
                    })()}
                  </div>
                </div>
              )}

              {/* Liste de toutes les matières */}
              <h3 className="text-sm font-semibold text-gray-700 mb-3">
                Toutes les matières disponibles
              </h3>
              <div className="space-y-2">
              {allSubjects.map((subject: Subject) => {
                const isAssigned = selectedSubjects.includes(subject.id);
                
                return (
                  <div
                    key={subject.id}
                    className={`flex items-center justify-between p-4 rounded-lg border-2 transition-all cursor-pointer ${
                      isAssigned
                        ? 'border-primary-500 bg-primary-50'
                        : 'border-gray-200 hover:border-gray-300'
                    }`}
                    onClick={() => handleToggleSubject(subject.id)}
                  >
                    <div className="flex items-center space-x-3">
                      <input
                        type="checkbox"
                        checked={isAssigned}
                        readOnly
                        className="h-5 w-5 text-primary-600 rounded focus:ring-primary-500"
                      />
                      <div>
                        <p className="font-medium text-gray-900">{subject.name}</p>
                        <p className="text-sm text-gray-500">{subject.code}</p>
                      </div>
                    </div>
                    
                    {isAssigned && (
                      <span className="text-xs font-medium text-primary-600 bg-primary-100 px-2 py-1 rounded">
                        Assigné
                      </span>
                    )}
                  </div>
                );
              })}
              </div>
            </>
          )}
        </div>

        <div className="flex items-center justify-between p-6 border-t border-gray-200 bg-gray-50">
          <p className="text-sm text-gray-600">
            {selectedSubjects.length} matière(s) assignée(s)
          </p>
          <button
            onClick={onClose}
            className="px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors"
          >
            Fermer
          </button>
        </div>
      </div>
    </div>
  );
}
