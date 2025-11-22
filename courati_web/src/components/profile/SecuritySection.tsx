import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { profileAPI } from '../../api/profile';
import type { ChangePasswordPayload } from '../../api/profile';
import { toast } from 'sonner';
import { Eye, EyeOff, Lock } from 'lucide-react';

type FieldErrors = Record<string, string[]>;

export default function SecuritySection() {
  const [passwords, setPasswords] = useState<ChangePasswordPayload>({
    old_password: '',
    new_password: '',
    confirm_password: '',
  });

  const [show, setShow] = useState<{ old: boolean; next: boolean; confirm: boolean }>({ 
    old: false, 
    next: false, 
    confirm: false 
  });
  
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});

  const validate = (): string[] => {
    const errs: string[] = [];
    if (!passwords.old_password) errs.push('Le mot de passe actuel est requis');
    if (!passwords.new_password) errs.push('Le nouveau mot de passe est requis');
    if (passwords.new_password && passwords.new_password.length < 8) {
      errs.push('Le nouveau mot de passe doit contenir au moins 8 caractères');
    }
    if (!passwords.confirm_password) errs.push('La confirmation du mot de passe est requise');
    if (passwords.new_password && passwords.confirm_password && passwords.new_password !== passwords.confirm_password) {
      errs.push('Les mots de passe ne correspondent pas');
    }
    if (passwords.old_password && passwords.new_password && passwords.old_password === passwords.new_password) {
      errs.push('Le nouveau mot de passe doit être différent de l\'ancien');
    }
    return errs;
  };

  const changePasswordMutation = useMutation({
    mutationFn: (payload: ChangePasswordPayload) => profileAPI.changePassword(payload),
    onSuccess: (data: any) => {
      toast.success(data?.message || 'Mot de passe modifié avec succès');
      setPasswords({ old_password: '', new_password: '', confirm_password: '' });
      setFieldErrors({});
    },
    onError: (error: any) => {
      const api = error?.response?.data;
      if (api?.errors) {
        setFieldErrors(api.errors as FieldErrors);
      } else if (api?.error) {
        toast.error(api.error);
      } else {
        toast.error('Erreur lors du changement de mot de passe');
      }
    },
  });

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setFieldErrors({});
    const errs = validate();
    if (errs.length) {
      toast.error(errs.join('\n'));
      return;
    }
    changePasswordMutation.mutate(passwords);
  };

  // ✅ GESTION DU CHANGEMENT D'INPUT
  const handleInputChange = (name: keyof ChangePasswordPayload, value: string) => {
    // Nettoyer l'erreur du champ si elle existe
    if (fieldErrors[name]) {
      setFieldErrors((prev) => {
        const copy = { ...prev };
        delete copy[name];
        return copy;
      });
    }
    // Mettre à jour le state
    setPasswords((prev) => ({ ...prev, [name]: value }));
  };

  // ✅ TOGGLE VISIBILITÉ MOT DE PASSE
  const toggleVisibility = (typeKey: 'old' | 'next' | 'confirm') => {
    setShow((prev) => ({ ...prev, [typeKey]: !prev[typeKey] }));
  };

  return (
    <div className="border border-gray-200 rounded-xl bg-white shadow-sm p-6">
      <div className="font-semibold text-gray-900 mb-4">Changer le mot de passe</div>
      
      <form onSubmit={onSubmit} className="space-y-4">
        {/* MOT DE PASSE ACTUEL */}
        <div>
          <label className="text-sm text-gray-700 inline-flex items-center gap-2">
            <Lock className="w-4 h-4 text-gray-500" /> 
            Mot de passe actuel
          </label>
          <div className="relative">
            <input
              type={show.old ? 'text' : 'password'}
              value={passwords.old_password}
              onChange={(e) => handleInputChange('old_password', e.target.value)}
              className="w-full px-4 py-2.5 pr-10 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="••••••••"
              required
              aria-invalid={!!fieldErrors.old_password}
              autoComplete="current-password"
            />
            <button 
              type="button" 
              onClick={() => toggleVisibility('old')} 
              className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-700"
            >
              {show.old ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
          {fieldErrors.old_password?.[0] && (
            <div className="text-sm text-red-600 mt-1">{fieldErrors.old_password[0]}</div>
          )}
        </div>

        {/* NOUVEAU MOT DE PASSE */}
        <div>
          <label className="text-sm text-gray-700 inline-flex items-center gap-2">
            <Lock className="w-4 h-4 text-gray-500" /> 
            Nouveau mot de passe
          </label>
          <div className="relative">
            <input
              type={show.next ? 'text' : 'password'}
              value={passwords.new_password}
              onChange={(e) => handleInputChange('new_password', e.target.value)}
              className="w-full px-4 py-2.5 pr-10 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="••••••••"
              required
              aria-invalid={!!fieldErrors.new_password}
              autoComplete="new-password"
              minLength={8}
            />
            <button 
              type="button" 
              onClick={() => toggleVisibility('next')} 
              className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-700"
            >
              {show.next ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
          {fieldErrors.new_password?.[0] && (
            <div className="text-sm text-red-600 mt-1">{fieldErrors.new_password[0]}</div>
          )}
        </div>

        {/* CONFIRMER MOT DE PASSE */}
        <div>
          <label className="text-sm text-gray-700 inline-flex items-center gap-2">
            <Lock className="w-4 h-4 text-gray-500" /> 
            Confirmer le mot de passe
          </label>
          <div className="relative">
            <input
              type={show.confirm ? 'text' : 'password'}
              value={passwords.confirm_password}
              onChange={(e) => handleInputChange('confirm_password', e.target.value)}
              className="w-full px-4 py-2.5 pr-10 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              placeholder="••••••••"
              required
              aria-invalid={!!fieldErrors.confirm_password}
              autoComplete="new-password"
            />
            <button 
              type="button" 
              onClick={() => toggleVisibility('confirm')} 
              className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-700"
            >
              {show.confirm ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
            </button>
          </div>
          {fieldErrors.confirm_password?.[0] && (
            <div className="text-sm text-red-600 mt-1">{fieldErrors.confirm_password[0]}</div>
          )}
        </div>

        {/* BOUTON SUBMIT */}
        <div className="pt-2">
          <button 
            type="submit" 
            disabled={changePasswordMutation.isPending} 
            className="bg-primary-500 text-white px-6 py-2.5 rounded-lg hover:bg-primary-600 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
          >
            {changePasswordMutation.isPending ? 'Modification...' : 'Changer le mot de passe'}
          </button>
        </div>
      </form>
    </div>
  );
}