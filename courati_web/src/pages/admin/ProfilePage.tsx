import { useQuery } from '@tanstack/react-query';
import { profileAPI } from '../../api/profile';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import ProfileHeader from '../../components/profile/ProfileHeader';
import PersonalInfoSection from '../../components/profile/PersonalInfoSection';
import SecuritySection from '../../components/profile/SecuritySection';
import StatsSection from '../../components/profile/StatsSection';

export default function ProfilePage() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['profile'],
    queryFn: profileAPI.getProfile,
    staleTime: 5 * 60 * 1000,
    refetchOnMount: true,
  });

  if (isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600 p-6">Erreur: {(error as Error).message}</div>;
  if (!data?.success || !data.profile) return <div className="p-6">Profil introuvable</div>;

  const profile = data.profile;
  const isTeacher = profile.user.role === 'TEACHER';

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Mon Profil</h1>
        <p className="text-gray-600 mt-1">Gérez vos informations personnelles et votre sécurité</p>
      </div>

      <ProfileHeader profile={profile} />

      <PersonalInfoSection profile={profile} />

      <SecuritySection />

      {isTeacher && (
        <div>
          <div className="font-semibold text-gray-900 mb-3">Mes statistiques</div>
          <StatsSection />
        </div>
      )}
    </div>
  );
}
