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

// Type simplifié pour le formulaire
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
  const { data: levels = [] } = useQuery({
    queryKey: ['levels'],
    queryFn: levelsAPI.getAll,
  });

  // Charger les filières
  const { data: majors = [] } = useQuery({
    queryKey: ['majors'],
    queryFn: majorsAPI.getAll,
  });

  // Modification: préremplissage correct dépendant du chargement des listes
  useEffect(() => {
    if (subject && levels.length > 0 && majors.length > 0) {
      setFormData({
        name: subject.name,
        code: subject.code,
        description: subject.description || '',
        levels: Array.isArray(subject.levels)
          ? subject.levels.map((l: any) => typeof l === 'number' ? l : (l?.id ?? l))
          : [],
        majors: Array.isArray(subject.majors)
          ? subject.majors.map((m: any) => typeof m === 'number' ? m : (m?.id ?? m))
          : [],
        credits: (subject as any).credits || 3,
        semester: (subject as any).semester || 1,
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
      toast.success(subject ? 'Matière modifiée' : 'Matière créée');
      onSuccess();
    },
    onError: (error: any) => {
      const errorMsg = error.response?.data?.message || 'Une erreur est survenue';
      toast.error(errorMsg);
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (formData.levels.length === 0) {
      toast.error('Veuillez sélectionner au moins un niveau.');
      return;
    }
    if (formData.majors.length === 0) {
      toast.error('Veuillez sélectionner au moins une filière.');
      return;
    }
    mutation.mutate(formData);
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: name === 'level' || name === 'major' ? parseInt(value) : value,
    }));
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
        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {/* Nom */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Nom de la matière *
            </label>
            <input
              type="text"
              name="name"
              value={formData.name}
              onChange={handleChange}
              required
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="Ex: Mathématiques"
            />
          </div>

          {/* Code */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Code *
            </label>
            <input
              type="text"
              name="code"
              value={formData.code}
              onChange={handleChange}
              required
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="Ex: MATH101"
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Description
            </label>
            <textarea
              name="description"
              value={formData.description}
              onChange={handleChange}
              rows={3}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="Description de la matière..."
            />
          </div>

          {/* Sélection Niveaux */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Niveaux <span className="text-red-500">*</span>
            </label>
            <div className="flex flex-wrap gap-2">
              {levels.map((level: Level) => {
                const checked = formData.levels.includes(level.id);
                return (
                  <label
                    key={level.id}
                    className={`inline-flex items-center rounded-full px-4 py-2 border cursor-pointer select-none text-sm font-medium transition-all
                              ${checked ? 'bg-primary-100 border-primary-500 text-primary-700 font-semibold shadow' : 'bg-white border-gray-300 text-gray-700'}
                              hover:border-primary-500 focus-within:ring-2 focus-within:ring-primary-400 focus:z-10`}
                  >
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => {
                        setFormData((prev) => {
                          const exists = prev.levels.includes(level.id);
                          return {
                            ...prev,
                            levels: exists ? prev.levels.filter((id) => id !== level.id) : [...prev.levels, level.id],
                          };
                        });
                      }}
                      className="hidden"
                    />
                    {level.code} - {level.name}
                  </label>
                );
              })}
            </div>
            {formData.levels.length === 0 && (
              <p className="text-xs text-red-500 mt-1">Veuillez sélectionner au moins un niveau.</p>
            )}
          </div>

          {/* Sélection Filières */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Filières <span className="text-red-500">*</span>
            </label>
            <div className="flex flex-wrap gap-2">
              {majors.map((major: Major) => {
                const checked = formData.majors.includes(major.id);
                return (
                  <label
                    key={major.id}
                    className={`inline-flex items-center rounded-full px-4 py-2 border cursor-pointer select-none text-sm font-medium transition-all
                              ${checked ? 'bg-primary-100 border-primary-500 text-primary-700 font-semibold shadow' : 'bg-white border-gray-300 text-gray-700'}
                              hover:border-primary-500 focus-within:ring-2 focus-within:ring-primary-400 focus:z-10`}
                  >
                    <input
                      type="checkbox"
                      checked={checked}
                      onChange={() => {
                        setFormData((prev) => {
                          const exists = prev.majors.includes(major.id);
                          return {
                            ...prev,
                            majors: exists ? prev.majors.filter((id) => id !== major.id) : [...prev.majors, major.id],
                          };
                        });
                      }}
                      className="hidden"
                    />
                    {major.code} - {major.name}
                  </label>
                );
              })}
            </div>
            {formData.majors.length === 0 && (
              <p className="text-xs text-red-500 mt-1">Veuillez sélectionner au moins une filière.</p>
            )}
          </div>

          {/* Crédits et Semestre */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Crédits *
              </label>
              <input
                type="number"
                name="credits"
                value={formData.credits}
                onChange={(e) => setFormData(prev => ({ ...prev, credits: parseInt(e.target.value) || 0 }))}
                required
                min="1"
                max="12"
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Semestre *
              </label>
              <select
                name="semester"
                value={formData.semester}
                onChange={(e) => setFormData(prev => ({ ...prev, semester: parseInt(e.target.value) }))}
                required
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              >
                <option value="1">Semestre 1</option>
                <option value="2">Semestre 2</option>
              </select>
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center justify-end space-x-3 pt-4 border-t border-gray-200">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg transition-colors"
            >
              Annuler
            </button>
            <button
              type="submit"
              disabled={mutation.isPending}
              className="px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors disabled:opacity-50"
            >
              {mutation.isPending ? 'Enregistrement...' : subject ? 'Modifier' : 'Créer'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
