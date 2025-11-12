import { useState, useEffect } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import { X } from 'lucide-react';
import { studentsAPI } from '../../api/students';
import { levelsAPI } from '../../api/levels';
import { majorsAPI } from '../../api/majors';
import { toast } from 'sonner';
import type { Student, CreateStudentDTO, UpdateStudentDTO } from '../../types';

interface StudentModalProps {
  student: Student | null;
  onClose: () => void;
  onSuccess: () => void;
}

export default function StudentModal({ student, onClose, onSuccess }: StudentModalProps) {
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
    first_name: '',
    last_name: '',
    phone_number: '',
    date_of_birth: '',
    address: '',
    level_id: '',
    major_id: '',
  });

  // Charger les niveaux et filières
  const { data: levels = [] } = useQuery({
    queryKey: ['levels'],
    queryFn: levelsAPI.getAll,
  });

  const { data: majors = [] } = useQuery({
    queryKey: ['majors'],
    queryFn: majorsAPI.getAll,
  });

  // Pré-remplir le formulaire en mode édition
  useEffect(() => {
    if (student) {
      setFormData({
        username: student.username || student.user?.username || '',
        email: student.email || student.user?.email || '',
        password: '',
        first_name: student.first_name || student.user?.first_name || '',
        last_name: student.last_name || student.user?.last_name || '',
        phone_number: student.phone_number || student.phone || '',
        date_of_birth: student.date_of_birth || '',
        address: student.address || '',
        level_id: student.level_id?.toString() || '',
        major_id: student.major_id?.toString() || '',
      });
    }
  }, [student]);

  // Mutation créer/modifier
  const mutation = useMutation({
    mutationFn: async (data: CreateStudentDTO | UpdateStudentDTO) => {
      console.log('📤 Envoi données étudiant:', data);
      
      if (student) {
        // Mode édition - ne pas envoyer username et password
        const { username, password, ...updateData } = data as any;
        console.log('✏️ Mode édition, données:', updateData);
        console.log('🔑 Utilisation user_id:', student.user_id);
        const result = await studentsAPI.update(student.user_id, updateData);
        console.log('✅ Étudiant modifié:', result);
        return result;
      } else {
        // Mode création
        console.log('➕ Mode création, données:', data);
        const result = await studentsAPI.create(data as CreateStudentDTO);
        console.log('✅ Étudiant créé:', result);
        return result;
      }
    },
    onSuccess: () => {
      toast.success(student ? 'Étudiant modifié avec succès' : 'Étudiant créé avec succès');
      onSuccess();
    },
    onError: (error: any) => {
      console.error('❌ Erreur:', error);
      
      // Extraire le message d'erreur
      let errorMessage = 'Une erreur est survenue';
      
      if (error.response?.data) {
        const data = error.response.data;
        
        // Gérer différents formats d'erreur
        if (typeof data === 'string') {
          errorMessage = data;
        } else if (data.message) {
          errorMessage = data.message;
        } else if (data.error) {
          errorMessage = data.error;
        } else if (data.detail) {
          errorMessage = data.detail;
        } else {
          // Erreurs de validation par champ
          const fieldErrors = Object.entries(data)
            .map(([field, errors]) => {
              if (Array.isArray(errors)) {
                return `${field}: ${errors.join(', ')}`;
              }
              return `${field}: ${errors}`;
            })
            .join('\n');
          
          if (fieldErrors) {
            errorMessage = fieldErrors;
          }
        }
      } else if (error.message) {
        errorMessage = error.message;
      }
      
      toast.error(errorMessage);
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    // Validation
    if (!formData.username || !formData.email || !formData.first_name || !formData.last_name) {
      toast.error('Veuillez remplir tous les champs obligatoires');
      return;
    }
    
    if (!student && !formData.password) {
      toast.error('Le mot de passe est obligatoire pour la création');
      return;
    }

    // Préparer les données
    const data: any = {
      username: formData.username,
      email: formData.email,
      first_name: formData.first_name,
      last_name: formData.last_name,
      phone_number: formData.phone_number || undefined,
      date_of_birth: formData.date_of_birth || undefined,
      address: formData.address || undefined,
      level_id: formData.level_id ? Number(formData.level_id) : undefined,
      major_id: formData.major_id ? Number(formData.major_id) : undefined,
    };

    // Ajouter le password seulement en mode création
    if (!student) {
      data.password = formData.password;
    }

    mutation.mutate(data);
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value,
    });
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        <div className="flex items-center justify-between p-6 border-b border-gray-200 sticky top-0 bg-white">
          <h2 className="text-xl font-bold text-gray-900">
            {student ? 'Modifier l\'étudiant' : 'Nouvel étudiant'}
          </h2>
          <button onClick={onClose} className="p-2 hover:bg-gray-100 rounded-lg transition-colors">
            <X className="h-5 w-5 text-gray-500" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-6">
          {/* Informations de compte */}
          <div>
            <h3 className="text-sm font-semibold text-gray-700 mb-4">Informations de compte</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Nom d'utilisateur <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  name="username"
                  value={formData.username}
                  onChange={handleChange}
                  disabled={!!student}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent disabled:bg-gray-100"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Email <span className="text-red-500">*</span>
                </label>
                <input
                  type="email"
                  name="email"
                  value={formData.email}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  required
                />
              </div>

              {!student && (
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Mot de passe <span className="text-red-500">*</span>
                  </label>
                  <input
                    type="password"
                    name="password"
                    value={formData.password}
                    onChange={handleChange}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    required
                  />
                </div>
              )}
            </div>
          </div>

          {/* Informations personnelles */}
          <div>
            <h3 className="text-sm font-semibold text-gray-700 mb-4">Informations personnelles</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Prénom <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  name="first_name"
                  value={formData.first_name}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Nom <span className="text-red-500">*</span>
                </label>
                <input
                  type="text"
                  name="last_name"
                  value={formData.last_name}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Téléphone
                </label>
                <input
                  type="tel"
                  name="phone_number"
                  value={formData.phone_number}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Date de naissance
                </label>
                <input
                  type="date"
                  name="date_of_birth"
                  value={formData.date_of_birth}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                />
              </div>

              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Adresse
                </label>
                <textarea
                  name="address"
                  value={formData.address}
                  onChange={handleChange}
                  rows={2}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                />
              </div>
            </div>
          </div>

          {/* Informations académiques */}
          <div>
            <h3 className="text-sm font-semibold text-gray-700 mb-4">Informations académiques</h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Niveau
                </label>
                <select
                  name="level_id"
                  value={formData.level_id}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                >
                  <option value="">Sélectionner un niveau</option>
                  {levels.map((level: any) => (
                    <option key={level.id} value={level.id}>
                      {level.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Filière
                </label>
                <select
                  name="major_id"
                  value={formData.major_id}
                  onChange={handleChange}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                >
                  <option value="">Sélectionner une filière</option>
                  {majors.map((major: any) => (
                    <option key={major.id} value={major.id}>
                      {major.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          </div>

          {/* Boutons */}
          <div className="flex items-center justify-end space-x-3 pt-6 border-t border-gray-200">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors"
            >
              Annuler
            </button>
            <button
              type="submit"
              disabled={mutation.isPending}
              className="px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {mutation.isPending ? 'Enregistrement...' : (student ? 'Modifier' : 'Créer')}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
