import { useState, useEffect } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { X } from 'lucide-react';
import { subjectsAPI } from '../../api/subjects';
import { levelsAPI } from '../../api/levels';
import { majorsAPI } from '../../api/majors';
import { toast } from 'sonner';
import type { Subject, Level, Major } from '../../types';

interface SubjectModalProps {
  subject: Subject | null;
  onClose: () => void;
  onSuccess: () => void;
}

interface SubjectFormData {
  name: string;
  code: string;
  description: string;
  levels: number[];
  majors: number[];
  credits?: number;
  semester?: number;
}

export default function SubjectModal({ subject, onClose, onSuccess }: SubjectModalProps) {
  const [formData, setFormData] = useState<SubjectFormData>({
    name: '',
    code: '',
    description: '',
    levels: [],
    majors: [],
    credits: 3,
    semester: 1,
  });

  // Charger les niveaux
  const { data: levelsResponse } = useQuery({
    queryKey: ['levels'],
    queryFn: levelsAPI.getAll,
  });

  // Charger les filières
  const { data: majorsResponse } = useQuery({
    queryKey: ['majors'],
    queryFn: majorsAPI.getAll,
  });

  // ✅ Extraire les données correctement
  const levels = Array.isArray(levelsResponse) 
    ? levelsResponse 
    : levelsResponse?.results || levelsResponse?.levels || [];

  const majors = Array.isArray(majorsResponse) 
    ? majorsResponse 
    : majorsResponse?.results || majorsResponse?.majors || [];

  // ✅ Pré-remplir le formulaire en mode édition
  useEffect(() => {
    if (subject && levels.length > 0 && majors.length > 0) {
      // Extraire les IDs des niveaux
      let levelIds: number[] = [];
      if (Array.isArray(subject.levels)) {
        levelIds = subject.levels.map((l: any) => {
          if (typeof l === 'number') return l;
          if (l?.id) return l.id;
          return null;
        }).filter((id): id is number => id !== null);
      }

      // Extraire les IDs des filières
      let majorIds: number[] = [];
      if (Array.isArray(subject.majors)) {
        majorIds = subject.majors.map((m: any) => {
          if (typeof m === 'number') return m;
          if (m?.id) return m.id;
          return null;
        }).filter((id): id is number => id !== null);
      }

      setFormData({
        name: subject.name || '',
        code: subject.code || '',
        description: subject.description || '',
        levels: levelIds.length > 0 ? [levelIds[0]] : [],
        majors: majorIds,
        credits: (subject as any).credits || 3,
        semester: (subject as any).semester || 1,
      });

      console.log('📝 Formulaire pré-rempli:', {
        subject,
        levelIds,
        majorIds,
        formData: {
          levels: levelIds,
          majors: majorIds,
        }
      });
    }
  }, [subject, levels, majors]);

  // Mutation créer/modifier
  const mutation = useMutation({
    mutationFn: (data: SubjectFormData) =>
      subject
        ? subjectsAPI.update(subject.id, data as any)
        : subjectsAPI.create(data as any),
    onSuccess: () => {
      toast.success(subject ? 'Matière modifiée avec succès' : 'Matière créée avec succès');
      onSuccess();
    },
    onError: (error: any) => {
      const errorMsg = error.response?.data?.error || error.response?.data?.message || 'Une erreur est survenue';
      toast.error(errorMsg);
      console.error('❌ Erreur mutation:', error.response?.data);
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    // Validations
    if (!formData.name.trim()) {
      toast.error('Le nom est requis');
      return;
    }
    if (!formData.code.trim()) {
      toast.error('Le code est requis');
      return;
    }
    if (formData.levels.length !== 1) {
      toast.error('Veuillez sélectionner exactement un niveau');
      return;
    }
    if (formData.majors.length === 0) {
      toast.error('Veuillez sélectionner au moins une filière');
      return;
    }

    console.log('📤 Envoi du formulaire:', formData);
    mutation.mutate(formData);
  };

  const toggleLevel = (levelId: number) => {
    setFormData((prev) => {
      const exists = prev.levels.includes(levelId);
      // Sélection unique: si on clique un niveau différent -> remplace; si on reclique le même -> vide (l'utilisateur devra en choisir un)
      const newLevels = exists ? [] : [levelId];
      console.log('🔄 Sélection niveau (unique):', { levelId, exists, newLevels });
      return { ...prev, levels: newLevels };
    });
  };

  const toggleMajor = (majorId: number) => {
    setFormData((prev) => {
      const exists = prev.majors.includes(majorId);
      const newMajors = exists 
        ? prev.majors.filter((id) => id !== majorId) 
        : [...prev.majors, majorId];
      
      console.log('🔄 Toggle filière:', { majorId, exists, newMajors });
      return { ...prev, majors: newMajors };
    });
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-bold text-gray-900">
            {subject ? 'Modifier la matière' : 'Nouvelle matière'}
          </h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 rounded-lg transition-colors"
          >
            <X className="h-5 w-5 text-gray-500" />
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Nom */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Nom de la matière *
            </label>
            <input
              type="text"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="Ex: Mathématiques"
              required
            />
          </div>

          {/* Code */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Code *
            </label>
            <input
              type="text"
              value={formData.code}
              onChange={(e) => setFormData({ ...formData, code: e.target.value })}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="Ex: MATH101"
              required
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Description
            </label>
            <textarea
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              rows={3}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="Description de la matière..."
            />
          </div>

          {/* Niveaux - Sélection UNIQUE */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Niveau * <span className="text-xs text-gray-500">(sélection unique)</span>
            </label>
            <div className="flex flex-wrap gap-2">
              {levels.length > 0 ? (
                levels.map((level: Level) => {
                  const isSelected = formData.levels.includes(level.id);
                  return (
                    <button
                      key={level.id}
                      type="button"
                      onClick={() => toggleLevel(level.id)}
                      className={`
                        inline-flex items-center px-4 py-2 rounded-full text-sm font-medium border-2 transition-all
                        ${isSelected 
                          ? 'bg-primary-600 border-primary-600 text-white shadow-sm' 
                          : 'bg-white border-gray-300 text-gray-700 hover:border-primary-300'
                        }
                      `}
                    >
                      {isSelected ? '●' : '○'} {level.code} - {level.name}
                    </button>
                  );
                })
              ) : (
                <p className="text-sm text-gray-500">Aucun niveau disponible</p>
              )}
            </div>
            {formData.levels.length !== 1 && (
              <p className="text-xs text-red-500 mt-2">⚠️ Sélectionnez exactement un niveau</p>
            )}
          </div>

          {/* Filières - Pills avec sélection */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Filières * <span className="text-xs text-gray-500">({formData.majors.length} sélectionnée{formData.majors.length > 1 ? 's' : ''})</span>
            </label>
            <div className="flex flex-wrap gap-2">
              {majors.length > 0 ? (
                majors.map((major: Major) => {
                  const isSelected = formData.majors.includes(major.id);
                  return (
                    <button
                      key={major.id}
                      type="button"
                      onClick={() => toggleMajor(major.id)}
                      className={`
                        inline-flex items-center px-4 py-2 rounded-full text-sm font-medium border-2 transition-all
                        ${isSelected 
                          ? 'bg-green-100 border-green-500 text-green-700 shadow-sm' 
                          : 'bg-white border-gray-300 text-gray-700 hover:border-green-300'
                        }
                      `}
                    >
                      {major.code} - {major.name}
                    </button>
                  );
                })
              ) : (
                <p className="text-sm text-gray-500">Aucune filière disponible</p>
              )}
            </div>
            {formData.majors.length === 0 && (
              <p className="text-xs text-red-500 mt-2">⚠️ Sélectionnez au moins une filière</p>
            )}
          </div>

          {/* Crédits et Semestre */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Crédits
              </label>
              <input
                type="number"
                value={formData.credits}
                onChange={(e) => setFormData({ ...formData, credits: parseInt(e.target.value) || 0 })}
                min="1"
                max="12"
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Semestre
              </label>
              <select
                value={formData.semester}
                onChange={(e) => setFormData({ ...formData, semester: parseInt(e.target.value) })}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              >
                <option value={1}>Semestre 1</option>
                <option value={2}>Semestre 2</option>
              </select>
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center justify-end space-x-3 pt-6 border-t border-gray-200">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
            >
              Annuler
            </button>
            <button
              type="submit"
              disabled={mutation.isPending}
              className="px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {mutation.isPending
                ? 'Enregistrement...'
                : subject
                ? 'Enregistrer'
                : 'Créer'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}