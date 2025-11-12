import { useState, useEffect } from 'react';
import { useMutation } from '@tanstack/react-query';
import { X } from 'lucide-react';
import { majorsAPI, type CreateMajorDTO } from '../../api/majors';
import { toast } from 'sonner';
import type { Major } from '../../types';

interface MajorModalProps {
  major: Major | null;
  onClose: () => void;
  onSuccess: () => void;
}

export default function MajorModal({ major, onClose, onSuccess }: MajorModalProps) {
  const [formData, setFormData] = useState<CreateMajorDTO>({
    code: '',
    name: '',
    description: '',
  });

  // Pré-remplir le formulaire en mode édition
  useEffect(() => {
    if (major) {
      setFormData({
        code: major.code,
        name: major.name,
        description: major.description || '',
      });
    }
  }, [major]);

  // Mutation créer/modifier
  const mutation = useMutation({
    mutationFn: (data: CreateMajorDTO) =>
      major
        ? majorsAPI.update(major.id, data)
        : majorsAPI.create(data),
    onSuccess: () => {
      toast.success(major ? 'Filière modifiée' : 'Filière créée');
      onSuccess();
    },
    onError: (error: any) => {
      const errorMsg = error.response?.data?.message || 'Une erreur est survenue';
      toast.error(errorMsg);
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    mutation.mutate(formData);
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: name === 'code' ? value.toUpperCase() : value,
    }));
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl max-w-lg w-full">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 className="text-xl font-bold text-gray-900">
            {major ? 'Modifier la filière' : 'Nouvelle filière'}
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
              maxLength={10}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent uppercase"
              placeholder="Ex: INFO, MATH"
            />
            <p className="text-xs text-gray-500 mt-1">2-10 caractères, lettres uniquement</p>
          </div>

          {/* Nom */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Nom *
            </label>
            <input
              type="text"
              name="name"
              value={formData.name}
              onChange={handleChange}
              required
              maxLength={100}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="Ex: Informatique, Mathématiques"
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
              rows={5}
              maxLength={1000}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="Description de la filière..."
            />
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
              {mutation.isPending ? 'Enregistrement...' : major ? 'Modifier' : 'Créer'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
