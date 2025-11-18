import { useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { ArrowLeft, Edit, Trash2, UserCheck, UserX } from 'lucide-react';
import { toast } from 'sonner';
import { studentsAPI } from '../../api/students';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import StudentModal from '../../components/students/StudentModal';
import type { Student } from '../../types';

export default function StudentDetailPage() {
  const { id } = useParams();
  const studentId = Number(id);
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);

  const { data: student, isLoading, error, refetch } = useQuery<Student>({
    queryKey: ['student', studentId],
    queryFn: () => studentsAPI.getById(studentId),
    enabled: Number.isFinite(studentId) && studentId > 0,
  });

  const toggleActiveMutation = useMutation({
    mutationFn: studentsAPI.toggleActive,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['student', studentId] });
      queryClient.invalidateQueries({ queryKey: ['students'] });
      refetch();
      toast.success('Statut mis à jour');
    },
    onError: (err: any) => {
      const msg = err?.response?.data?.detail || err?.message || 'Erreur lors de la mise à jour du statut';
      toast.error(msg);
    },
  });

  const deleteMutation = useMutation({
    mutationFn: studentsAPI.delete,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['students'] });
      toast.success('Étudiant supprimé');
      navigate('/admin/students');
    },
    onError: (err: any) => {
      const msg = err?.response?.data?.detail || err?.message || 'Erreur lors de la suppression';
      toast.error(msg);
    },
  });

  if (!Number.isFinite(studentId) || studentId <= 0) {
    return <div className="text-red-600">Identifiant étudiant invalide</div>;
  }

  if (isLoading) return <LoadingSpinner />;
  if (error) return <div className="text-red-600">Erreur: {(error as Error).message}</div>;
  if (!student) return <div className="text-gray-600">Étudiant introuvable</div>;

  const fullName = `${student.first_name || ''} ${student.last_name || ''}`.trim();
  const username = student.username || '';
  const email = student.email || '';
  const isActive = student.is_active ?? true;
  const levelName = student.level?.name || (student as any).level_name || '-';
  const majorName = student.major?.name || (student as any).major_name || '-';
  const phone = student.phone_number || (student as any).phone || '-';
  const dateJoined = student.date_joined ? new Date(student.date_joined).toLocaleString() : '-';

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <Link to="/admin/students" className="inline-flex items-center px-3 py-2 rounded-lg border border-gray-200 hover:bg-gray-50 text-gray-700">
            <ArrowLeft className="h-4 w-4 mr-2" /> Retour
          </Link>
          <h1 className="text-2xl font-bold text-gray-900">Détail de l'étudiant</h1>
        </div>
        <div className="flex items-center space-x-2">
          <button
            onClick={() => setIsModalOpen(true)}
            className="px-3 py-2 text-primary-600 hover:bg-primary-50 rounded-lg transition-colors flex items-center"
            title="Modifier"
          >
            <Edit className="h-4 w-4 mr-2" /> Modifier
          </button>
          <button
            onClick={() => toggleActiveMutation.mutate(student.id)}
            className={`px-3 py-2 rounded-lg transition-colors flex items-center ${isActive ? 'text-orange-600 hover:bg-orange-50' : 'text-green-600 hover:bg-green-50'}`}
            title={isActive ? 'Désactiver' : 'Activer'}
          >
            {isActive ? <UserX className="h-4 w-4 mr-2" /> : <UserCheck className="h-4 w-4 mr-2" />} {isActive ? 'Désactiver' : 'Activer'}
          </button>
          <button
            onClick={() => {
              if (confirm('Confirmer la suppression de cet étudiant ?')) {
                deleteMutation.mutate(student.id);
              }
            }}
            className="px-3 py-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors flex items-center disabled:opacity-50"
            disabled={deleteMutation.isPending}
            title="Supprimer"
          >
            <Trash2 className="h-4 w-4 mr-2" /> Supprimer
          </button>
        </div>
      </div>

      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-start justify-between">
          <div>
            <h2 className="text-xl font-semibold text-gray-900">{fullName || username}</h2>
            {username && <p className="text-gray-500">@{username}</p>}
          </div>
          <span className={`inline-flex items-center px-3 py-1 rounded-full text-sm font-medium ${
            isActive ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
          }`}>
            {isActive ? 'Actif' : 'Inactif'}
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-6">
          <div>
            <p className="text-sm text-gray-500">Email</p>
            <p className="text-gray-900">{email}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Téléphone</p>
            <p className="text-gray-900">{phone}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Niveau</p>
            <p className="text-gray-900">{levelName}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Filière</p>
            <p className="text-gray-900">{majorName}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Inscription</p>
            <p className="text-gray-900">{dateJoined}</p>
          </div>
        </div>
      </div>

      {isModalOpen && (
        <StudentModal
          student={student}
          onClose={() => setIsModalOpen(false)}
          onSuccess={() => {
            queryClient.invalidateQueries({ queryKey: ['student', studentId] });
            queryClient.invalidateQueries({ queryKey: ['students'] });
            refetch();
            setIsModalOpen(false);
          }}
        />
      )}
    </div>
  );
}
