import { useMemo, useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { Building2, Briefcase, Clock, Mail, Phone, Save, Edit, X, UserCircle, Calendar } from 'lucide-react';
import { profileAPI, ProfileData, UpdateProfilePayload } from '../../api/profile';
import { toast } from 'sonner';

type FieldErrors = Record<string, string[]>;

function formatDate(dateStr?: string) {
  if (!dateStr) return '-';
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString('fr-FR', { year: 'numeric', month: 'long', day: 'numeric' });
  } catch {
    return dateStr;
  }
}

export default function PersonalInfoSection({ profile }: { profile: ProfileData }) {
  const queryClient = useQueryClient();
  const user = profile.user;
  const isTeacher = user.role === 'TEACHER';

  const [isEditing, setIsEditing] = useState(false);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});

  const [form, setForm] = useState<UpdateProfilePayload>({
    first_name: user.first_name || '',
    last_name: user.last_name || '',
    phone_number: (profile as any).phone_number || '',
    department: (profile as any).department || '',
    specialization: (profile as any).specialization || '',
    bio: (profile as any).bio || '',
    office: (profile as any).office || '',
    office_hours: (profile as any).office_hours || '',
  });

  const reset = () => {
    setFieldErrors({});
    setForm({
      first_name: user.first_name || '',
      last_name: user.last_name || '',
      phone_number: (profile as any).phone_number || '',
      department: (profile as any).department || '',
      specialization: (profile as any).specialization || '',
      bio: (profile as any).bio || '',
      office: (profile as any).office || '',
      office_hours: (profile as any).office_hours || '',
    });
  };

  const updateMutation = useMutation({
    mutationFn: (payload: UpdateProfilePayload) => profileAPI.updateProfile(payload),
    onSuccess: (data: any) => {
      toast.success(data?.message || 'Profil mis à jour avec succès');
      setIsEditing(false);
      setFieldErrors({});
      queryClient.invalidateQueries({ queryKey: ['profile'] });
    },
    onError: (error: any) => {
      const api = error?.response?.data;
      if (api?.errors) {
        setFieldErrors(api.errors as FieldErrors);
      } else if (api?.error) {
        toast.error(api.error);
      } else {
        toast.error('Erreur lors de la mise à jour du profil');
      }
    },
  });

  const readOnlyRows = useMemo(() => ([
    { label: 'Nom d’utilisateur', value: user.username, icon: UserCircle },
    { label: 'Email', value: user.email, icon: Mail },
    { label: 'Rôle', value: user.role_display, icon: Briefcase },
    { label: 'Membre depuis', value: formatDate(user.date_joined), icon: Calendar },
  ]), [user]);

  return (
    <div className="border border-gray-200 rounded-xl bg-white shadow-sm">
      <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
        <div className="font-semibold text-gray-900">Informations personnelles</div>
        {!isEditing ? (
          <button onClick={() => setIsEditing(true)} className="inline-flex items-center gap-2 border border-gray-300 text-gray-700 px-3 py-1.5 rounded-lg hover:bg-gray-50 transition-colors">
            <Edit className="w-4 h-4" /> Modifier
          </button>
        ) : (
          <div className="flex items-center gap-2">
            <button onClick={() => { reset(); setIsEditing(false); }} className="inline-flex items-center gap-2 border border-gray-300 text-gray-700 px-3 py-1.5 rounded-lg hover:bg-gray-50 transition-colors">
              <X className="w-4 h-4" /> Annuler
            </button>
            <button onClick={() => updateMutation.mutate(form)} disabled={updateMutation.isPending} className="inline-flex items-center gap-2 bg-primary-500 text-white px-3 py-1.5 rounded-lg hover:bg-primary-600 disabled:bg-gray-300 transition-colors">
              <Save className="w-4 h-4" /> Enregistrer
            </button>
          </div>
        )}
      </div>

      <div className="p-6 grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Col gauche: lecture seule */}
        <div className="lg:col-span-1 space-y-3">
          {readOnlyRows.map((row) => {
            const Icon = row.icon;
            return (
              <div key={row.label} className="flex items-center gap-3 text-sm">
                <Icon className="w-4 h-4 text-gray-500" />
                <div>
                  <div className="text-gray-600">{row.label}</div>
                  <div className="font-medium text-gray-900">{row.value || '-'}</div>
                </div>
              </div>
            );
          })}
        </div>

        {/* Col droite: champs éditables */}
        <div className="lg:col-span-2 space-y-4">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="text-sm text-gray-700">Prénom</label>
              <input disabled={!isEditing} className="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent disabled:bg-gray-100" value={form.first_name || ''} onChange={(e) => setForm({ ...form, first_name: e.target.value })} />
              {fieldErrors.first_name && <div className="text-sm text-red-600 mt-1">{fieldErrors.first_name[0]}</div>}
            </div>
            <div>
              <label className="text-sm text-gray-700">Nom</label>
              <input disabled={!isEditing} className="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent disabled:bg-gray-100" value={form.last_name || ''} onChange={(e) => setForm({ ...form, last_name: e.target.value })} />
              {fieldErrors.last_name && <div className="text-sm text-red-600 mt-1">{fieldErrors.last_name[0]}</div>}
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="text-sm text-gray-700 inline-flex items-center gap-2"><Phone className="w-4 h-4 text-gray-500" /> Téléphone</label>
              <input disabled={!isEditing} className="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent disabled:bg-gray-100" value={form.phone_number || ''} onChange={(e) => setForm({ ...form, phone_number: e.target.value })} />
              {fieldErrors.phone_number && <div className="text-sm text-red-600 mt-1">{fieldErrors.phone_number[0]}</div>}
            </div>
            {user.role === 'ADMIN' ? (
              <div>
                <label className="text-sm text-gray-700 inline-flex items-center gap-2"><Building2 className="w-4 h-4 text-gray-500" /> Département</label>
                <input disabled={!isEditing} className="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent disabled:bg-gray-100" value={(form as any).department || ''} onChange={(e) => setForm({ ...form, department: e.target.value })} />
                {fieldErrors.department && <div className="text-sm text-red-600 mt-1">{fieldErrors.department[0]}</div>}
              </div>
            ) : (
              <div>
                <label className="text-sm text-gray-700 inline-flex items-center gap-2"><Briefcase className="w-4 h-4 text-gray-500" /> Spécialisation</label>
                <input disabled={!isEditing} className="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent disabled:bg-gray-100" value={(form as any).specialization || ''} onChange={(e) => setForm({ ...form, specialization: e.target.value })} />
                {fieldErrors.specialization && <div className="text-sm text-red-600 mt-1">{fieldErrors.specialization[0]}</div>}
              </div>
            )}
          </div>

          {isTeacher && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label className="text-sm text-gray-700">Bio</label>
                <textarea disabled={!isEditing} rows={3} className="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent disabled:bg-gray-100" value={(form as any).bio || ''} onChange={(e) => setForm({ ...form, bio: e.target.value })} />
                {fieldErrors.bio && <div className="text-sm text-red-600 mt-1">{fieldErrors.bio[0]}</div>}
              </div>
              <div>
                <label className="text-sm text-gray-700 inline-flex items-center gap-2"><Building2 className="w-4 h-4 text-gray-500" /> Bureau</label>
                <input disabled={!isEditing} className="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent disabled:bg-gray-100" value={(form as any).office || ''} onChange={(e) => setForm({ ...form, office: e.target.value })} />
                {fieldErrors.office && <div className="text-sm text-red-600 mt-1">{fieldErrors.office[0]}</div>}
                <label className="text-sm text-gray-700 inline-flex items-center gap-2 mt-3"><Clock className="w-4 h-4 text-gray-500" /> Heures de permanence</label>
                <textarea disabled={!isEditing} rows={2} className="w-full px-4 py-2.5 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-transparent disabled:bg-gray-100" value={(form as any).office_hours || ''} onChange={(e) => setForm({ ...form, office_hours: e.target.value })} />
                {fieldErrors.office_hours && <div className="text-sm text-red-600 mt-1">{fieldErrors.office_hours[0]}</div>}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
