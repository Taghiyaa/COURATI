import { Calendar, Mail, User as UserIcon } from 'lucide-react';
import type { ProfileData } from '../../api/profile';

function formatDate(dateStr?: string) {
  if (!dateStr) return '-';
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString('fr-FR', { year: 'numeric', month: 'long', day: 'numeric' });
  } catch {
    return dateStr;
  }
}

export default function ProfileHeader({ profile }: { profile: ProfileData }) {
  const user = profile.user;
  const displayName = [user.first_name, user.last_name].filter(Boolean).join(' ') || user.username;

  return (
    <div className="border border-gray-200 rounded-xl bg-white p-6 shadow-sm">
      <div className="flex items-start gap-4">
        <div className="p-3 rounded-full bg-primary-50 text-primary-600">
          <UserIcon className="w-8 h-8" />
        </div>
        <div className="flex-1">
          <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-2">
            <div>
              <h1 className="text-2xl font-bold text-gray-900">{displayName}</h1>
              <div className="text-gray-600">{user.role_display} • {user.username}</div>
            </div>
          </div>
          <div className="mt-3 flex flex-wrap items-center gap-4 text-sm text-gray-700">
            <div className="inline-flex items-center gap-2"><Mail className="w-4 h-4 text-gray-500" /> {user.email}</div>
            <div className="inline-flex items-center gap-2"><Calendar className="w-4 h-4 text-gray-500" /> Membre depuis {formatDate(user.date_joined)}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
