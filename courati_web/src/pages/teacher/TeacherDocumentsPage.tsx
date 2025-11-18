import { useEffect } from 'react';
import { useNavigate, Link } from 'react-router-dom';

export default function TeacherDocumentsPage() {
  const navigate = useNavigate();

  useEffect(() => {
    navigate('/teacher/subjects');
  }, [navigate]);

  return (
    <div className="p-6 text-center">
      <h1 className="text-2xl font-bold text-gray-900 mb-2">Gestion des documents</h1>
      <p className="text-gray-600 mb-4">Les documents sont gérés depuis chaque matière.</p>
      <Link to="/teacher/subjects" className="inline-flex px-4 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600">Voir mes matières</Link>
    </div>
  );
}
