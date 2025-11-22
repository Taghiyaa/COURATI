import { useEffect, useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useParams } from 'react-router-dom';
import { subjectsAPI } from '../../api/subjects';
import { adminQuizzesAPI } from '../../api/adminQuizzes';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { toast } from 'sonner';
import { ChevronLeft, ChevronRight, Plus, Save, Trash2 } from 'lucide-react';

interface ChoiceForm {
  text: string;
  is_correct: boolean;
  order: number;
}

interface QuestionForm {
  text: string;
  question_type: 'QCM' | 'TRUE_FALSE' | 'MULTIPLE';
  points: number;
  order: number;
  explanation?: string;
  choices: ChoiceForm[];
}

interface QuizFormState {
  subject: number | '';
  title: string;
  description?: string;
  duration_minutes: number | '';
  passing_percentage: number | '';
  max_attempts: number | '' | null;
  show_correction: boolean;
  is_active: boolean;
  available_from?: string | null; // ISO or null
  available_until?: string | null; // ISO or null
  questions: QuestionForm[];
}

export default function AdminQuizFormPage() {
  const { id } = useParams();
  const quizId = id ? Number(id) : null;
  const isEdit = Number.isFinite(quizId) && (quizId as number) > 0;
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  // Step
  const [step, setStep] = useState<number>(1);

  // Load subjects for dropdown
  const { data: subjectsData, isLoading: loadingSubjects } = useQuery({
    queryKey: ['admin_quiz_subjects_for_form'],
    queryFn: () => subjectsAPI.getAll(),
  });

  const subjectOptions: { id: number; name: string }[] = useMemo(() => {
    const arr = Array.isArray(subjectsData) ? subjectsData : (subjectsData?.subjects || []);
    return arr.map((s: any) => ({ id: Number(s.id), name: String(s.name ?? '') }));
  }, [subjectsData]);

  // Load quiz detail if edit
  const { data: quizDetail, isLoading: loadingDetail } = useQuery({
    queryKey: ['admin_quiz_detail', quizId],
    queryFn: () => adminQuizzesAPI.getById(quizId as number),
    enabled: !!isEdit,
  });

  const [form, setForm] = useState<QuizFormState>({
    subject: '',
    title: '',
    description: '',
    duration_minutes: '' as any,
    passing_percentage: '' as any,
    max_attempts: null,
    show_correction: true,
    is_active: true,
    available_from: null,
    available_until: null,
    questions: [
      {
        text: '',
        question_type: 'QCM',
        points: 1,
        order: 1,
        explanation: '',
        choices: [
          { text: '', is_correct: true, order: 1 },
          { text: '', is_correct: false, order: 2 },
        ],
      },
    ],
  });

  useEffect(() => {
    if (!isEdit || !quizDetail) return;
    const q = (quizDetail as any).quiz || quizDetail;
    const mappedQuestions: QuestionForm[] = (q.questions || []).map((qq: any, idx: number) => ({
      text: qq.text || '',
      question_type: (qq.question_type as any) || 'QCM',
      points: Number(qq.points) || 1,
      order: Number(qq.order) || (idx + 1),
      explanation: qq.explanation || '',
      choices: (qq.choices || []).map((c: any, i: number) => ({ text: c.text || '', is_correct: !!c.is_correct, order: Number(c.order) || (i + 1) })),
    }));
    setForm({
      subject: Number(q.subject) || '',
      title: q.title || '',
      description: q.description || '',
      duration_minutes: Number(q.duration_minutes) || '' as any,
      passing_percentage: Number(q.passing_percentage) || '' as any,
      max_attempts: q.max_attempts == null ? null : Number(q.max_attempts),
      show_correction: !!q.show_correction,
      is_active: !!q.is_active,
      available_from: q.available_from || null,
      available_until: q.available_until || null,
      questions: mappedQuestions.length ? mappedQuestions : form.questions,
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [quizDetail, isEdit]);

  const totalPoints = useMemo(() => {
    return (form.questions || []).reduce((sum, q) => sum + (Number(q.points) || 0), 0);
  }, [form.questions]);

  // Helpers
  const addQuestion = () => {
    setForm((prev) => ({
      ...prev,
      questions: [
        ...prev.questions,
        {
          text: '',
          question_type: 'QCM',
          points: 1,
          order: prev.questions.length + 1,
          explanation: '',
          choices: [
            { text: '', is_correct: true, order: 1 },
            { text: '', is_correct: false, order: 2 },
          ],
        },
      ],
    }));
  };

  const removeQuestion = (index: number) => {
    setForm((prev) => {
      const copy = [...prev.questions];
      copy.splice(index, 1);
      return { ...prev, questions: copy.map((q, i) => ({ ...q, order: i + 1 })) };
    });
  };

  const updateQuestion = (index: number, updater: (q: QuestionForm) => QuestionForm) => {
    setForm((prev) => {
      const copy = [...prev.questions];
      copy[index] = updater(copy[index]);
      return { ...prev, questions: copy };
    });
  };

  const handleTypeChange = (index: number, newType: 'QCM' | 'TRUE_FALSE' | 'MULTIPLE') => {
    updateQuestion(index, (q) => {
      let choices = q.choices;
      if (newType === 'TRUE_FALSE') {
        choices = [
          { text: 'Vrai', is_correct: true, order: 1 },
          { text: 'Faux', is_correct: false, order: 2 },
        ];
      } else if (q.question_type === 'TRUE_FALSE') {
        choices = [
          { text: '', is_correct: true, order: 1 },
          { text: '', is_correct: false, order: 2 },
        ];
      }
      return { ...q, question_type: newType, choices };
    });
  };

  const addChoice = (qIdx: number) => {
    updateQuestion(qIdx, (q) => ({
      ...q,
      choices: [...q.choices, { text: '', is_correct: false, order: q.choices.length + 1 }],
    }));
  };

  const removeChoice = (qIdx: number, cIdx: number) => {
    updateQuestion(qIdx, (q) => {
      const copy = [...q.choices];
      copy.splice(cIdx, 1);
      return { ...q, choices: copy.map((c, i) => ({ ...c, order: i + 1 })) };
    });
  };

  // Validations
  const validateStep1 = (): string[] => {
    const errors: string[] = [];
    if (!form.title.trim()) errors.push('Le titre est requis');
    if (!form.subject || Number(form.subject) <= 0) errors.push('Sélectionnez une matière');
    const duration = Number(form.duration_minutes);
    if (!(duration >= 1 && duration <= 180)) errors.push('La durée doit être entre 1 et 180 minutes');
    const pass = Number(form.passing_percentage);
    if (!(pass >= 0 && pass <= 100)) errors.push('La note de passage doit être entre 0 et 100');
    if (form.max_attempts !== null && form.max_attempts !== '' && !(Number(form.max_attempts) >= 1 && Number(form.max_attempts) <= 10)) {
      errors.push('Les tentatives doivent être entre 1 et 10 ou vide pour illimité');
    }
    return errors;
  };

  const validateStep2 = (): string[] => {
    const errors: string[] = [];
    if (!form.questions.length) errors.push('Au moins une question est requise');
    form.questions.forEach((q, idx) => {
      if (!q.text.trim()) errors.push(`Question ${idx + 1}: le texte est requis`);
      if (!(Number(q.points) > 0)) errors.push(`Question ${idx + 1}: les points doivent être > 0`);
      if (q.choices.length < 2) errors.push(`Question ${idx + 1}: au moins 2 choix`);
      const correctCount = q.choices.filter((c) => c.is_correct).length;
      if (correctCount < 1) errors.push(`Question ${idx + 1}: au moins 1 bonne réponse`);
      if (q.question_type === 'QCM' && correctCount !== 1) errors.push(`Question ${idx + 1}: un QCM doit avoir exactement 1 bonne réponse`);
      if (q.question_type === 'TRUE_FALSE') {
        if (q.choices.length !== 2) errors.push(`Question ${idx + 1}: Vrai/Faux doit avoir exactement 2 choix`);
        if (correctCount !== 1) errors.push(`Question ${idx + 1}: Vrai/Faux doit avoir exactement 1 bonne réponse`);
      }
      if (q.question_type === 'MULTIPLE' && correctCount < 2) errors.push(`Question ${idx + 1}: Choix multiples doit avoir au moins 2 bonnes réponses`);
    });
    return errors;
  };

  const mapPayload = () => {
    const available_from = form.available_from ? new Date(form.available_from).toISOString() : null;
    const available_until = form.available_until ? new Date(form.available_until).toISOString() : null;
    return {
      subject: Number(form.subject),
      title: form.title,
      description: form.description || undefined,
      duration_minutes: Number(form.duration_minutes),
      passing_percentage: Number(form.passing_percentage),
      max_attempts: form.max_attempts === '' ? null : form.max_attempts,
      show_correction: !!form.show_correction,
      is_active: !!form.is_active,
      available_from,
      available_until,
      questions: form.questions.map((q, qi) => ({
        text: q.text,
        question_type: q.question_type,
        points: Number(q.points),
        order: qi + 1,
        explanation: q.explanation || undefined,
        choices: q.choices.map((c, ci) => ({ text: c.text, is_correct: !!c.is_correct, order: ci + 1 })),
      })),
    };
  };

  const createMutation = useMutation({
    mutationFn: (payload: any) => adminQuizzesAPI.create(payload),
    onSuccess: () => {
      toast.success('Quiz créé avec succès');
      queryClient.invalidateQueries({ queryKey: ['admin_quizzes'] });
      navigate('/admin/quizzes');
    },
    onError: (e: any) => toast.error(e?.response?.data?.error || 'Erreur lors de la création'),
  });

  const updateMutation = useMutation({
    mutationFn: (payload: any) => adminQuizzesAPI.update(quizId as number, payload),
    onSuccess: () => {
      toast.success('Quiz modifié avec succès');
      queryClient.invalidateQueries({ queryKey: ['admin_quizzes'] });
      navigate('/admin/quizzes');
    },
    onError: (e: any) => toast.error(e?.response?.data?.error || 'Erreur lors de la modification'),
  });

  const handleNext = () => {
    if (step === 1) {
      const errs = validateStep1();
      if (errs.length) return toast.error(errs.join('\n'));
    }
    if (step === 2) {
      const errs = validateStep2();
      if (errs.length) return toast.error(errs.join('\n'));
    }
    setStep((s) => Math.min(3, s + 1));
  };

  const handlePrev = () => setStep((s) => Math.max(1, s - 1));

  const handleSubmit = () => {
    const errs = [...validateStep1(), ...validateStep2()];
    if (errs.length) return toast.error(errs.join('\n'));
    const payload = mapPayload();
    if (isEdit) updateMutation.mutate(payload);
    else createMutation.mutate(payload);
  };

  const progress = step === 1 ? 33 : step === 2 ? 66 : 100;

  if (loadingSubjects || (isEdit && loadingDetail)) return <LoadingSpinner />;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">{isEdit ? 'Modifier un quiz' : 'Créer un quiz'}</h1>
          <p className="text-gray-600 mt-1">Étape {step} / 3</p>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => navigate('/admin/quizzes')} className="px-3 py-2 border rounded-lg">Annuler</button>
          {step > 1 && <button onClick={handlePrev} className="inline-flex items-center gap-2 px-3 py-2 border rounded-lg"><ChevronLeft className="w-4 h-4" /> Précédent</button>}
          {step < 3 && <button onClick={handleNext} className="inline-flex items-center gap-2 px-3 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600">Suivant <ChevronRight className="w-4 h-4" /></button>}
          {step === 3 && (
            <button onClick={handleSubmit} disabled={createMutation.isPending || updateMutation.isPending} className="inline-flex items-center gap-2 px-3 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 disabled:opacity-50"><Save className="w-4 h-4" /> {isEdit ? 'Enregistrer' : 'Créer le quiz'}</button>
          )}
        </div>
      </div>

      {/* Progress */}
      <div className="w-full bg-gray-200 rounded-full h-2">
        <div className="bg-primary-500 h-2 rounded-full transition-all" style={{ width: `${progress}%` }} />
      </div>

      {/* Step content */}
      {step === 1 && (
        <div className="bg-white rounded-xl border p-6 space-y-4">
          <div>
            <label className="text-sm text-gray-700">Titre</label>
            <input className="w-full px-3 py-2 border rounded" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          </div>
          <div>
            <label className="text-sm text-gray-700">Description</label>
            <textarea rows={3} className="w-full px-3 py-2 border rounded" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="text-sm text-gray-700">Matière</label>
              <select className="w-full px-3 py-2 border rounded" value={form.subject} onChange={(e) => setForm({ ...form, subject: e.target.value ? Number(e.target.value) : '' })}>
                <option value="">Sélectionner une matière</option>
                {subjectOptions.map((s) => (
                  <option key={s.id} value={s.id}>{s.name}</option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-sm text-gray-700">Durée (minutes)</label>
              <input type="number" min={1} max={180} className="w-full px-3 py-2 border rounded" value={form.duration_minutes as any} onChange={(e) => setForm({ ...form, duration_minutes: e.target.value ? Number(e.target.value) : '' as any })} />
            </div>
            <div>
              <label className="text-sm text-gray-700">Note de passage (%)</label>
              <input type="number" min={0} max={100} className="w-full px-3 py-2 border rounded" value={form.passing_percentage as any} onChange={(e) => setForm({ ...form, passing_percentage: e.target.value ? Number(e.target.value) : '' as any })} />
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label className="text-sm text-gray-700">Tentatives max (vide = illimité)</label>
              <input type="number" min={1} max={10} className="w-full px-3 py-2 border rounded" value={form.max_attempts === null ? '' : (form.max_attempts as any)} onChange={(e) => setForm({ ...form, max_attempts: e.target.value === '' ? null : Number(e.target.value) })} />
            </div>
            <label className="inline-flex items-center gap-2 text-sm text-gray-700 mt-6"><input type="checkbox" checked={form.show_correction} onChange={(e) => setForm({ ...form, show_correction: e.target.checked })} /> Afficher la correction</label>
            <label className="inline-flex items-center gap-2 text-sm text-gray-700 mt-6"><input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} /> Actif</label>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="text-sm text-gray-700">Disponible à partir de</label>
              <input type="datetime-local" className="w-full px-3 py-2 border rounded" value={form.available_from ? new Date(form.available_from).toISOString().slice(0,16) : ''} onChange={(e) => setForm({ ...form, available_from: e.target.value ? new Date(e.target.value).toISOString() : null })} />
            </div>
            <div>
              <label className="text-sm text-gray-700">Disponible jusqu'à</label>
              <input type="datetime-local" className="w-full px-3 py-2 border rounded" value={form.available_until ? new Date(form.available_until).toISOString().slice(0,16) : ''} onChange={(e) => setForm({ ...form, available_until: e.target.value ? new Date(e.target.value).toISOString() : null })} />
            </div>
          </div>
        </div>
      )}

      {step === 2 && (
        <div className="space-y-4">
          {form.questions.map((q, qIdx) => (
            <div key={qIdx} className="bg-white rounded-xl border p-6 space-y-4">
              <div className="flex items-center justify-between">
                <div className="font-semibold text-gray-900">Question {qIdx + 1}</div>
                <button onClick={() => removeQuestion(qIdx)} className="inline-flex items-center gap-2 px-2 py-1 border border-red-300 rounded text-red-700 hover:bg-red-50"><Trash2 className="w-4 h-4" /> Supprimer</button>
              </div>
              <div>
                <label className="text-sm text-gray-700">Texte</label>
                <textarea rows={3} className="w-full px-3 py-2 border rounded" value={q.text} onChange={(e) => updateQuestion(qIdx, (qq) => ({ ...qq, text: e.target.value }))} />
              </div>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label className="text-sm text-gray-700">Type</label>
                  <select className="w-full px-3 py-2 border rounded" value={q.question_type} onChange={(e) => handleTypeChange(qIdx, e.target.value as any)}>
                    <option value="QCM">QCM</option>
                    <option value="TRUE_FALSE">Vrai / Faux</option>
                    <option value="MULTIPLE">Choix multiples</option>
                  </select>
                </div>
                <div>
                  <label className="text-sm text-gray-700">Points</label>
                  <input type="number" min={1} className="w-full px-3 py-2 border rounded" value={q.points} onChange={(e) => updateQuestion(qIdx, (qq) => ({ ...qq, points: Number(e.target.value) }))} />
                </div>
                <div>
                  <label className="text-sm text-gray-700">Explication (optionnel)</label>
                  <input className="w-full px-3 py-2 border rounded" value={q.explanation || ''} onChange={(e) => updateQuestion(qIdx, (qq) => ({ ...qq, explanation: e.target.value }))} />
                </div>
              </div>

              {/* Choices */}
              <div className="space-y-3">
                <div className="font-medium text-gray-800">Choix</div>
                {q.choices.map((c, cIdx) => (
                  <div key={cIdx} className="grid grid-cols-1 md:grid-cols-12 gap-3 items-center">
                    <input className="md:col-span-9 px-3 py-2 border rounded" placeholder={`Choix ${cIdx + 1}`} value={c.text} onChange={(e) => updateQuestion(qIdx, (qq) => {
                      const cc = [...qq.choices];
                      cc[cIdx] = { ...cc[cIdx], text: e.target.value };
                      return { ...qq, choices: cc };
                    })} />
                    <label className="md:col-span-2 inline-flex items-center gap-2"><input type="checkbox" checked={c.is_correct} onChange={(e) => updateQuestion(qIdx, (qq) => {
                      const cc = [...qq.choices];
                      cc[cIdx] = { ...cc[cIdx], is_correct: e.target.checked };
                      return { ...qq, choices: cc };
                    })} /> Correct</label>
                    <button onClick={() => removeChoice(qIdx, cIdx)} className="md:col-span-1 px-2 py-2 border rounded hover:bg-gray-50">Suppr</button>
                  </div>
                ))}
                {q.question_type !== 'TRUE_FALSE' && (
                  <button onClick={() => addChoice(qIdx)} className="inline-flex items-center gap-2 px-3 py-2 border rounded"><Plus className="w-4 h-4" /> Ajouter un choix</button>
                )}
              </div>
            </div>
          ))}
          <button onClick={addQuestion} className="inline-flex items-center gap-2 px-4 py-2 border rounded"><Plus className="w-4 h-4" /> Ajouter une question</button>

          <div className="text-right text-sm text-gray-700">Total des points: <span className="font-semibold">{totalPoints}</span></div>
        </div>
      )}

      {step === 3 && (
        <div className="space-y-4">
          <div className="bg-white rounded-xl border p-6 space-y-2">
            <div className="text-lg font-semibold">Informations générales</div>
            <div className="text-sm"><span className="text-gray-600">Titre:</span> <span className="font-medium">{form.title || '-'}</span></div>
            <div className="text-sm"><span className="text-gray-600">Matière:</span> <span className="font-medium">{subjectOptions.find(s => s.id === Number(form.subject))?.name || '-'}</span></div>
            <div className="text-sm"><span className="text-gray-600">Durée:</span> <span className="font-medium">{form.duration_minutes || '-'} min</span></div>
            <div className="text-sm"><span className="text-gray-600">Note de passage:</span> <span className="font-medium">{form.passing_percentage || '-'}%</span></div>
            <div className="text-sm"><span className="text-gray-600">Tentatives max:</span> <span className="font-medium">{form.max_attempts == null ? 'Illimité' : form.max_attempts}</span></div>
            <div className="text-sm"><span className="text-gray-600">Correction:</span> <span className="font-medium">{form.show_correction ? 'Afficher' : 'Masquer'}</span></div>
            <div className="text-sm"><span className="text-gray-600">Statut:</span> <span className="font-medium">{form.is_active ? 'Actif' : 'Inactif'}</span></div>
          </div>

          <div className="bg-white rounded-xl border p-6 space-y-4">
            <div className="text-lg font-semibold">Questions</div>
            {form.questions.map((q, idx) => (
              <div key={idx} className="border rounded p-4 space-y-2">
                <div className="flex items-center justify-between">
                  <div className="font-medium">Q{idx + 1} • {q.question_type} • {q.points} pts</div>
                </div>
                <div className="text-gray-800">{q.text || '-'}</div>
                {q.explanation && <div className="text-sm text-gray-600">Explication: {q.explanation}</div>}
                <div className="space-y-1">
                  {q.choices.map((c, i) => (
                    <div key={i} className="text-sm">
                      <span className={`inline-block w-2 h-2 rounded-full mr-2 ${c.is_correct ? 'bg-green-500' : 'bg-gray-300'}`} />
                      {c.text || `Choix ${i + 1}`} {c.is_correct && <span className="text-green-700">(✓)</span>}
                    </div>
                  ))}
                </div>
              </div>
            ))}
            <div className="text-right text-sm text-gray-700">Total des points: <span className="font-semibold">{totalPoints}</span></div>
          </div>
        </div>
      )}
    </div>
  );
}
