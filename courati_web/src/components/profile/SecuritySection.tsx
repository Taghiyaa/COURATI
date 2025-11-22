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

  const [show, setShow] = useState<{ old: boolean; next: boolean; confirm: boolean }>({ old: false, next: false, confirm: false });
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});

  const validate = (): string[] => {
    const errs: string[] = [];
    if (!passwords.old_password) errs.push('Le mot de passe actuel est requis');
    if (!passwords.new_password) errs.push('Le nouveau mot de passe est requis');
    if (passwords.new_password && passwords.new_password.length < 8) errs.push('Le nouveau mot de passe doit contenir au moins 8 caractères');
    if (!passwords.confirm_password) errs.push('La confirmation du mot de passe est requise');
    if (passwords.new_password && passwords.confirm_password && passwords.new_password !== passwords.confirm_password) errs.push('Les mots de passe ne correspondent pas');
    if (passwords.old_password && passwords.new_password && passwords.old_password === passwords.new_password) errs.push('Le nouveau mot de passe doit être différent de l\'ancien');
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

  const Input = ({ name, label, typeKey }: { name: keyof ChangePasswordPayload; label: string; typeKey: 'old' | 'next' | 'confirm' }) => {
    const showFlag = typeKey === 'old' ? show.old : typeKey === 'next' ? show.next : show.confirm;
    const toggle = () => setShow((s) => ({ ...s, [typeKey]: !showFlag }));
    const err = fieldErrors[name]?.[0];
    return (
      <div>
        <label className="text-sm text-gray-700 inline-flex items-center gap-2"><Lock className="w-4 h-4 text-gray-500" /> {label}</label>
        <div className="relative">
          <input
            type={showFlag ? 'text' : 'password'}
            value={passwords[name]}
            onChange={(e) => setPasswords({ ...passwords, [name]: e.target.value })}
            className="w-full px-4 py-2.5 pr-10 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            placeholder="••••••••"
          />
          <button type="button" onClick={toggle} className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500">
            {showFlag ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
          </button>
        </div>
        {err && <div className="text-sm text-red-600 mt-1">{err}</div>}
      </div>
    );
  };

  return (
    <div className="border border-gray-200 rounded-xl bg-white shadow-sm p-6">
      <div className="font-semibold text-gray-900 mb-4">Changer le mot de passe</div>
      <form onSubmit={onSubmit} className="space-y-4">
        <Input name="old_password" label="Mot de passe actuel" typeKey="old" />
        <Input name="new_password" label="Nouveau mot de passe" typeKey="next" />
        <Input name="confirm_password" label="Confirmer le mot de passe" typeKey="confirm" />
        <div className="pt-2">
          <button type="submit" disabled={changePasswordMutation.isPending} className="bg-primary-500 text-white px-6 py-2.5 rounded-lg hover:bg-primary-600 disabled:bg-gray-300 transition-colors">
            {changePasswordMutation.isPending ? 'Modification...' : 'Changer le mot de passe'}
          </button>
        </div>
      </form>
    </div>
  );
}
