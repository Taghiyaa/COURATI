import { useState, useEffect } from 'react';
import { useMutation } from '@tanstack/react-query';
import { X } from 'lucide-react';
import { teachersAPI, type CreateTeacherDTO, type UpdateTeacherDTO } from '../../api/teachers';
import { toast } from 'sonner';
import type { Teacher } from '../../types';

interface TeacherModalProps {
  teacher: Teacher | null;
  onClose: () => void;
  onSuccess: () => void;
}

export default function TeacherModal({ teacher, onClose, onSuccess }: TeacherModalProps) {
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
    first_name: '',
    last_name: '',
    phone: '', // Stocker seulement les 8 chiffres
    specialization: '',
  });

  // Pré-remplir le formulaire en mode édition
  useEffect(() => {
    if (teacher) {
      console.log('📝 Teacher data COMPLET:', JSON.stringify(teacher, null, 2));
      
      // ✅ CORRECTION : Le champ s'appelle phone_number, pas phone
      const phoneFromDB = (teacher as any).phone_number || teacher.phone || '';
      console.log('📞 Phone from DB:', phoneFromDB);
      
      // Extraire le numéro sans le préfixe +222 s'il existe
      let phoneNumber = '';
      if (phoneFromDB) {
        phoneNumber = phoneFromDB.toString().trim();
        console.log('📞 Phone avant traitement:', phoneNumber);
        
        // Enlever +222 s'il est présent
        if (phoneNumber.startsWith('+222')) {
          phoneNumber = phoneNumber.slice(4);
          console.log('📞 Phone après suppression +222:', phoneNumber);
        }
        // Enlever aussi les espaces éventuels
        phoneNumber = phoneNumber.replace(/\s/g, '');
        console.log('📞 Phone final (sans espaces):', phoneNumber);
      }
      
      setFormData({
        username: teacher.username || '',
        email: teacher.email || '',
        password: '', // Ne pas pré-remplir le mot de passe
        first_name: teacher.first_name || '',
        last_name: teacher.last_name || '',
        phone: phoneNumber,
        specialization: teacher.specialization || '',
      });
      
      console.log('✅ FormData mis à jour avec phone:', phoneNumber);
    }
  }, [teacher]);

  // Mutation créer/modifier
  const mutation = useMutation({
    mutationFn: async (data: CreateTeacherDTO | UpdateTeacherDTO) => {
      console.log('📤 Envoi données enseignant:', data);
      
      // Ajouter le préfixe +222 au téléphone si renseigné
      const phoneWithPrefix = data.phone ? `+222${data.phone}` : '';
      
      // ✅ CORRECTION : Envoyer phone_number au backend
      const dataToSend: any = { 
        ...data, 
        phone_number: phoneWithPrefix || null, // null si vide
        specialization: data.specialization || null, // null si vide
      };
      
      // Supprimer phone car le backend attend phone_number
      delete dataToSend.phone;
      
      // Nettoyer les champs vides (convertir "" en null)
      Object.keys(dataToSend).forEach(key => {
        if (dataToSend[key] === '') {
          dataToSend[key] = null;
        }
      });
      
      console.log('📤 Données après traitement:', dataToSend);
      
      if (teacher) {
        // Mode édition - ne pas envoyer username et password
        const { username, password, ...updateData } = dataToSend;
        console.log('✏️ Mode édition, données:', updateData);
        console.log('🔑 Utilisation user_id:', teacher.user_id);
        const result = await teachersAPI.update(teacher.user_id, updateData);
        console.log('✅ Enseignant modifié:', result);
        return result;
      } else {
        // Mode création
        console.log('➕ Mode création, données:', dataToSend);
        const result = await teachersAPI.create(dataToSend as CreateTeacherDTO);
        console.log('✅ Enseignant créé:', result);
        return result;
      }
    },
    onSuccess: () => {
      toast.success(teacher ? 'Enseignant modifié avec succès' : 'Enseignant créé avec succès');
      onSuccess();
    },
    onError: (error: any) => {
      console.error('❌ Erreur mutation enseignant:', error);
      console.error('Détails erreur:', error.response?.data);
      
      // Extraire le message d'erreur
      let errorMsg = 'Une erreur est survenue';
      
      if (error.response?.data) {
        const data = error.response.data;
        // Gérer différents formats d'erreur
        if (typeof data === 'string') {
          errorMsg = data;
        } else if (data.message) {
          errorMsg = data.message;
        } else if (data.error) {
          errorMsg = data.error;
        } else if (data.detail) {
          errorMsg = data.detail;
        } else {
          // Afficher les erreurs de champs
          const fieldErrors = Object.entries(data)
            .map(([key, value]) => `${key}: ${Array.isArray(value) ? value.join(', ') : value}`)
            .join('; ');
          if (fieldErrors) errorMsg = fieldErrors;
        }
      }
      
      toast.error(errorMsg);
    },
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    // Validation
    if (!teacher && !formData.password) {
      toast.error('Le mot de passe est requis pour créer un enseignant');
      return;
    }

    // Validation du téléphone si renseigné
    if (formData.phone && formData.phone.length !== 8) {
      toast.error('Le numéro de téléphone doit contenir 8 chiffres');
      return;
    }

    mutation.mutate(formData as any);
  };

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  // Gestionnaire spécifique pour le téléphone
  const handlePhoneChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    let value = e.target.value;
    
    // Supprimer tous les caractères non numériques
    value = value.replace(/\D/g, '');
    
    // Limiter à 8 chiffres
    if (value.length > 8) {
      value = value.slice(0, 8);
    }
    
    setFormData(prev => ({ ...prev, phone: value }));
  };

  // Formater l'affichage du téléphone (XX XX XX XX)
  const formatPhoneDisplay = (phone: string) => {
    if (!phone) return '';
    if (phone.length <= 2) return phone;
    if (phone.length <= 4) return `${phone.slice(0, 2)} ${phone.slice(2)}`;
    if (phone.length <= 6) return `${phone.slice(0, 2)} ${phone.slice(2, 4)} ${phone.slice(4)}`;
    return `${phone.slice(0, 2)} ${phone.slice(2, 4)} ${phone.slice(4, 6)} ${phone.slice(6)}`;
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl max-w-2xl w-full max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-gray-200 sticky top-0 bg-white">
          <h2 className="text-xl font-bold text-gray-900">
            {teacher ? 'Modifier l\'enseignant' : 'Nouvel enseignant'}
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
          {/* Nom d'utilisateur */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Nom d'utilisateur *
            </label>
            <input
              type="text"
              name="username"
              value={formData.username}
              onChange={handleChange}
              required
              disabled={!!teacher} // Désactiver en mode édition
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent disabled:bg-gray-100 disabled:cursor-not-allowed"
              placeholder="Ex: jdupont"
            />
            {teacher && (
              <p className="text-xs text-gray-500 mt-1">Le nom d'utilisateur ne peut pas être modifié</p>
            )}
          </div>

          {/* Prénom et Nom */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Prénom *
              </label>
              <input
                type="text"
                name="first_name"
                value={formData.first_name}
                onChange={handleChange}
                required
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                placeholder="Jean"
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Nom *
              </label>
              <input
                type="text"
                name="last_name"
                value={formData.last_name}
                onChange={handleChange}
                required
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                placeholder="Dupont"
              />
            </div>
          </div>

          {/* Email */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Email *
            </label>
            <input
              type="email"
              name="email"
              value={formData.email}
              onChange={handleChange}
              required
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="jean.dupont@example.com"
            />
          </div>

          {/* Mot de passe */}
          {!teacher && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Mot de passe *
              </label>
              <input
                type="password"
                name="password"
                value={formData.password}
                onChange={handleChange}
                required={!teacher}
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                placeholder="••••••••"
              />
              <p className="text-xs text-gray-500 mt-1">Minimum 8 caractères</p>
            </div>
          )}

          {/* Téléphone avec préfixe +222 */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Téléphone
            </label>
            <div className="relative">
              {/* Préfixe fixe +222 */}
              <span className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-700 font-medium pointer-events-none z-10">
                +222
              </span>
              {/* Input pour les 8 chiffres */}
              <input
                type="tel"
                name="phone"
                value={formatPhoneDisplay(formData.phone)}
                onChange={handlePhoneChange}
                className="w-full pl-16 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                placeholder="XX XX XX XX"
                maxLength={11} // 8 chiffres + 3 espaces
              />
            </div>
            <p className="text-xs text-gray-500 mt-1">
              Le numéro sera enregistré avec le préfixe +222
            </p>
          </div>

          {/* Spécialisation */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Spécialisation
            </label>
            <input
              type="text"
              name="specialization"
              value={formData.specialization}
              onChange={handleChange}
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="Ex: Informatique, Mathématiques..."
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
              {mutation.isPending ? 'Enregistrement...' : teacher ? 'Modifier' : 'Créer'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}