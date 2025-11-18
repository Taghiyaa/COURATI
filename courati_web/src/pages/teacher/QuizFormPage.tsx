import { useEffect, useMemo, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { teacherAPI } from '../../api/teacher';
import { teacherQuizzesAPI } from '../../api/teacherQuizzes';
import { toast } from 'sonner';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { Plus, Trash2, ArrowLeft, Save } from 'lucide-react';

 type Choice = { text: string; is_correct: boolean };
 type Question = {
  text: string;
  question_type: 'QCM' | 'TRUE_FALSE' | 'MULTIPLE';
  points: number;
  explanation?: string;
  choices: Choice[];
};

type FormState = {
  title: string;
  description: string;
  subject_id: number | '';
  duration_minutes: number;
  passing_percentage: number;
  max_attempts: number | '' | null;
  show_correction: boolean;
  is_active: boolean;
  questions: Question[];
};

export default function QuizFormPage() {
  const { id } = useParams();
  const quizId = Number(id);
  const isEdit = Number.isFinite(quizId) && quizId > 0;
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const [step, setStep] = useState<0 | 1 | 2>(0);
  const [form, setForm] = useState<FormState>({
    title: '',
    description: '',
    subject_id: '' as any,
    duration_minutes: 60,
    passing_percentage: 50,
    max_attempts: '' as any,
    show_correction: true,
    is_active: true,
    questions: [
      {
        text: '',
        question_type: 'QCM',
        points: 1,
        explanation: '',
        choices: [
          { text: '', is_correct: true },
          { text: '', is_correct: false },
        ],
      },
    ],
  });

  const { data: subjectsData } = useQuery({
    queryKey: ['teacher_subjects'],
    queryFn: teacherAPI.getMySubjects,
  });

  const subjects: any[] = useMemo(() => {
    if (!subjectsData) return [];
    if (Array.isArray(subjectsData)) return subjectsData;
    return subjectsData.subjects || [];
  }, [subjectsData]);

  const subjectOptions = useMemo(() => {
    return subjects
      .map((item: any) => item?.subject || item)
      .filter(Boolean)
      .map((s: any) => ({ id: s.id, name: s.name }));
  }, [subjects]);

  const { data: quizData, isLoading: quizLoading } = useQuery({
    queryKey: ['teacher_quiz', quizId],
    queryFn: () => teacherQuizzesAPI.getById(quizId),
    enabled: isEdit,
  });

  useEffect(() => {
    if (!isEdit || !quizData) return;
    const q: any = (quizData as any).quiz || quizData;
    const mappedQuestions: Question[] = (q.questions || []).map((qq: any) => ({
      text: qq.text || qq.question_text || '',
      question_type: (qq.question_type as any) || 'QCM',
      points: Number(qq.points ?? 1),
      explanation: qq.explanation || '',
      choices: (qq.choices || []).map((c: any) => ({ text: c.text || '', is_correct: !!c.is_correct })),
    }));
    setForm({
      title: q.title || '',
      description: q.description || '',
      subject_id: q.subject?.id ?? q.subject ?? '',
      duration_minutes: Number(q.duration_minutes ?? q.duration ?? 60),
      passing_percentage: Number(q.passing_percentage ?? q.passing_percent ?? 50),
      max_attempts: q.max_attempts != null ? Number(q.max_attempts) : '',
      show_correction: q.show_correction ?? true,
      is_active: q.is_active ?? true,
      questions: mappedQuestions.length > 0 ? mappedQuestions : form.questions,
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isEdit, quizData]);

  const createMutation = useMutation({
    mutationFn: (payload: any) => teacherQuizzesAPI.create(payload),
    onSuccess: () => {
      toast.success('Quiz créé avec succès');
      queryClient.invalidateQueries({ queryKey: ['teacher_quizzes'] });
      navigate('/teacher/quizzes');
    },
    onError: (error: any) => {
      toast.error(error?.response?.data?.error || 'Erreur lors de la création');
    },
  });

  const updateMutation = useMutation({
    mutationFn: (payload: any) => teacherQuizzesAPI.update(quizId, payload),
    onSuccess: () => {
      toast.success('Quiz modifié avec succès');
      queryClient.invalidateQueries({ queryKey: ['teacher_quizzes'] });
      navigate(`/teacher/quizzes/${quizId}`);
    },
    onError: (error: any) => {
      toast.error(error?.response?.data?.error || 'Erreur lors de la modification');
    },
  });

  const totalPoints = useMemo(() => form.questions.reduce((sum, q) => sum + Number(q.points || 0), 0), [form.questions]);

  const setQuestion = (idx: number, updater: (q: Question) => Question) => {
    setForm(prev => ({
      ...prev,
      questions: prev.questions.map((q, i) => (i === idx ? updater(q) : q)),
    }));
  };

  const addQuestion = () => {
    setForm(prev => ({
      ...prev,
      questions: [
        ...prev.questions,
        { text: '', question_type: 'QCM', points: 1, explanation: '', choices: [{ text: '', is_correct: true }, { text: '', is_correct: false }] },
      ],
    }));
  };

  const removeQuestion = (idx: number) => {
    setForm(prev => ({ ...prev, questions: prev.questions.filter((_, i) => i !== idx) }));
  };

  const addChoice = (qIdx: number) => {
    setQuestion(qIdx, (q) => {
      if (q.question_type === 'TRUE_FALSE') return q;
      const next = { ...q, choices: [...q.choices, { text: '', is_correct: false }] };
      return next;
    });
  };

  const removeChoice = (qIdx: number, cIdx: number) => {
    setQuestion(qIdx, (q) => {
      if (q.question_type === 'TRUE_FALSE') return q;
      if (q.choices.length <= 2) return q;
      const next = { ...q, choices: q.choices.filter((_, i) => i !== cIdx) };
      return next;
    });
  };

  const handleTypeChange = (qIdx: number, newType: Question['question_type']) => {
    setQuestion(qIdx, (q) => {
      let choices: Choice[] = q.choices;
      if (newType === 'TRUE_FALSE') {
        choices = [
          { text: 'Vrai', is_correct: true },
          { text: 'Faux', is_correct: false },
        ];
      } else if (q.question_type === 'TRUE_FALSE') {
        choices = [
          { text: '', is_correct: true },
          { text: '', is_correct: false },
        ];
      } else if (choices.length < 2) {
        choices = [
          { text: '', is_correct: true },
          { text: '', is_correct: false },
        ];
      }
      return { ...q, question_type: newType, choices };
    });
  };

  const handleToggleCorrect = (qIdx: number, cIdx: number) => {
    setQuestion(qIdx, (q) => {
      if (q.question_type === 'QCM') {
        return { ...q, choices: q.choices.map((c, i) => ({ ...c, is_correct: i === cIdx })) };
      }
      return { ...q, choices: q.choices.map((c, i) => (i === cIdx ? { ...c, is_correct: !c.is_correct } : c)) };
    });
  };

  const validateGeneral = () => {
    if (!form.title.trim()) return 'Le titre est requis';
    if (!form.subject_id) return 'La matière est requise';
    if (!form.duration_minutes || form.duration_minutes < 1 || form.duration_minutes > 180) return 'Durée invalide (1-180)';
    if (form.passing_percentage < 0 || form.passing_percentage > 100) return 'Note de passage invalide (0-100)';
    if (form.max_attempts !== '' && form.max_attempts !== null) {
      const m = Number(form.max_attempts);
      if (Number.isNaN(m) || m < 1 || m > 10) return 'Tentatives max invalides (1-10)';
    }
    return '';
  };

  const validateQuestions = () => {
    if (form.questions.length < 1) return 'Ajoutez au moins une question';
    for (let i = 0; i < form.questions.length; i++) {
      const q = form.questions[i];
      if (!q.text.trim()) return `Texte requis pour la question ${i + 1}`;
      if (q.points == null || Number(q.points) < 1) return `Points invalides pour la question ${i + 1}`;
      if (!Array.isArray(q.choices) || q.choices.length < 2) return `Au moins 2 choix pour la question ${i + 1}`;
      const correctCount = q.choices.filter(c => c.is_correct).length;
      if (q.question_type === 'QCM' && correctCount !== 1) return `QCM: exactement 1 bonne réponse (question ${i + 1})`;
      if (q.question_type === 'MULTIPLE' && correctCount < 2) return `Choix multiples: au moins 2 bonnes réponses (question ${i + 1})`;
      if (q.question_type === 'TRUE_FALSE') {
        if (q.choices.length !== 2) return `Vrai/Faux: exactement 2 choix (question ${i + 1})`;
        if (correctCount !== 1) return `Vrai/Faux: exactement 1 bonne réponse (question ${i + 1})`;
        if (!(q.choices[0].text === 'Vrai' && q.choices[1].text === 'Faux')) return `Vrai/Faux: choix fixes Vrai/Faux (question ${i + 1})`;
      }
      for (let j = 0; j < q.choices.length; j++) {
        if (!q.choices[j].text.trim()) return `Texte du choix ${j + 1} manquant (question ${i + 1})`;
      }
    }
    return '';
  };

  const buildPayload = () => {
    const subject = Number(form.subject_id);
    const maxAttempts = form.max_attempts === '' ? null : form.max_attempts === null ? null : Number(form.max_attempts);
    const questions = form.questions.map((q, idx) => ({
      text: q.text,
      question_type: q.question_type,
      points: Number(q.points),
      order: idx + 1,
      explanation: q.explanation || '',
      choices: q.choices.map((c, cIdx) => ({ text: c.text, is_correct: !!c.is_correct, order: cIdx + 1 })),
    }));
    return {
      title: form.title,
      description: form.description,
      subject,
      duration_minutes: Number(form.duration_minutes),
      passing_percentage: Number(form.passing_percentage),
      max_attempts: maxAttempts,
      show_correction: !!form.show_correction,
      is_active: !!form.is_active,
      available_from: null,
      available_until: null,
      questions,
    };
  };

  const handleNextFromGeneral = () => {
    const err = validateGeneral();
    if (err) return toast.error(err);
    setStep(1);
  };

  const handleNextFromQuestions = () => {
    const err = validateQuestions();
    if (err) return toast.error(err);
    setStep(2);
  };

  const handleSubmit = () => {
    const err1 = validateGeneral();
    if (err1) return toast.error(err1);
    const err2 = validateQuestions();
    if (err2) return toast.error(err2);
    const payload = buildPayload();
    if (isEdit) updateMutation.mutate(payload);
    else createMutation.mutate(payload);
  };

   const progress = useMemo(() => ((step + 1) / 3) * 100, [step]);

  if (isEdit && quizLoading) return <LoadingSpinner />;

 

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <button onClick={() => navigate(-1)} className="px-3 py-2 border rounded-lg text-gray-700 hover:bg-gray-50"><ArrowLeft className="w-4 h-4" /></button>
          <h1 className="text-2xl font-bold text-gray-900">{isEdit ? 'Modifier le quiz' : 'Créer un quiz'}</h1>
        </div>
        <button onClick={handleSubmit} disabled={createMutation.isPending || updateMutation.isPending} className="inline-flex items-center gap-2 px-3 py-2 bg-primary-500 text-white rounded-lg hover:bg-primary-600 disabled:opacity-50">
          <Save className="w-4 h-4" /> {isEdit ? 'Enregistrer les modifications' : 'Créer le quiz'}
        </button>
      </div>

      <div className="bg-white rounded-xl border border-gray-200">
        <div className="px-4 pt-4">
          <div className="h-2 bg-gray-100 rounded">
            <div className="h-2 bg-primary-500 rounded" style={{ width: `${progress}%` }} />
          </div>
        </div>
        <div className="p-6">
          {step === 0 && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="text-sm text-gray-700">Titre *</label>
                  <input className="w-full px-3 py-2 border rounded" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
                </div>
                <div>
                  <label className="text-sm text-gray-700">Matière *</label>
                  <select className="w-full px-3 py-2 border rounded" value={form.subject_id} onChange={(e) => setForm({ ...form, subject_id: Number(e.target.value) })}>
                    <option value="">Sélectionner…</option>
                    {subjectOptions.map((s) => (
                      <option key={s.id} value={s.id}>{s.name}</option>
                    ))}
                  </select>
                </div>
                <div className="md:col-span-2">
                  <label className="text-sm text-gray-700">Description</label>
                  <textarea className="w-full px-3 py-2 border rounded" rows={3} value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
                </div>
                <div>
                  <label className="text-sm text-gray-700">Durée (minutes) *</label>
                  <input type="number" min={1} max={180} className="w-full px-3 py-2 border rounded" value={form.duration_minutes} onChange={(e) => setForm({ ...form, duration_minutes: Number(e.target.value) })} />
                </div>
                <div>
                  <label className="text-sm text-gray-700">Note de passage (%) *</label>
                  <input type="number" min={0} max={100} className="w-full px-3 py-2 border rounded" value={form.passing_percentage} onChange={(e) => setForm({ ...form, passing_percentage: Number(e.target.value) })} />
                </div>
                <div>
                  <label className="text-sm text-gray-700">Tentatives max (vide = illimité)</label>
                  <input type="number" min={1} max={10} className="w-full px-3 py-2 border rounded" value={form.max_attempts as any} onChange={(e) => setForm({ ...form, max_attempts: e.target.value === '' ? '' : Number(e.target.value) })} />
                </div>
                <div className="flex items-center gap-6">
                  <label className="inline-flex items-center gap-2 text-sm text-gray-700"><input type="checkbox" checked={form.is_active} onChange={(e) => setForm({ ...form, is_active: e.target.checked })} /> Actif</label>
                  <label className="inline-flex items-center gap-2 text-sm text-gray-700"><input type="checkbox" checked={form.show_correction} onChange={(e) => setForm({ ...form, show_correction: e.target.checked })} /> Afficher la correction</label>
                </div>
              </div>
              <div className="flex items-center justify-end gap-2">
                <button onClick={() => navigate('/teacher/quizzes')} className="px-4 py-2 rounded border">Annuler</button>
                <button onClick={handleNextFromGeneral} className="px-4 py-2 rounded bg-primary-500 text-white hover:bg-primary-600">Suivant</button>
              </div>
            </div>
          )}

          {step === 1 && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="text-sm text-gray-700">Questions: {form.questions.length} • Points totaux: {totalPoints}</div>
                <button onClick={addQuestion} className="inline-flex items-center gap-1 px-3 py-2 border rounded hover:bg-gray-50"><Plus className="w-4 h-4" /> Ajouter une question</button>
              </div>

              <div className="space-y-4">
                {form.questions.map((q, qIdx) => (
                  <div key={qIdx} className="p-4 border rounded-lg">
                    <div className="flex items-start justify-between gap-3">
                      <div className="flex-1 space-y-2">
                        <input className="w-full px-3 py-2 border rounded" placeholder={`Question ${qIdx + 1}`} value={q.text} onChange={(e) => setQuestion(qIdx, (qq) => ({ ...qq, text: e.target.value }))} />
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
                          <select className="px-3 py-2 border rounded" value={q.question_type} onChange={(e) => handleTypeChange(qIdx, e.target.value as any)}>
                            <option value="QCM">QCM (1 bonne réponse)</option>
                            <option value="MULTIPLE">Choix multiples (2+)</option>
                            <option value="TRUE_FALSE">Vrai/Faux</option>
                          </select>
                          <input type="number" min={1} className="px-3 py-2 border rounded" value={q.points} onChange={(e) => setQuestion(qIdx, (qq) => ({ ...qq, points: Number(e.target.value) }))} />
                          <input className="px-3 py-2 border rounded" placeholder="Explication (optionnel)" value={q.explanation || ''} onChange={(e) => setQuestion(qIdx, (qq) => ({ ...qq, explanation: e.target.value }))} />
                        </div>
                      </div>
                      <button onClick={() => removeQuestion(qIdx)} className="p-2 rounded border text-red-600 hover:bg-red-50"><Trash2 className="w-4 h-4" /></button>
                    </div>

                    <div className="mt-3 space-y-2">
                      {q.choices.map((c, cIdx) => (
                        <div key={cIdx} className="flex items-center gap-2">
                          <input
                            className="flex-1 px-3 py-2 border rounded"
                            value={c.text}
                            onChange={(e) => setQuestion(qIdx, (qq) => ({ ...qq, choices: qq.choices.map((cc, i) => (i === cIdx ? { ...cc, text: e.target.value } : cc)) }))}
                            disabled={q.question_type === 'TRUE_FALSE'}
                          />
                          <label className="inline-flex items-center gap-2 text-sm text-gray-700">
                            <input
                              type="checkbox"
                              checked={!!c.is_correct}
                              onChange={() => handleToggleCorrect(qIdx, cIdx)}
                            />
                            Correct
                          </label>
                          {q.question_type !== 'TRUE_FALSE' && (
                            <button onClick={() => removeChoice(qIdx, cIdx)} className="p-2 rounded border hover:bg-gray-50">
                              <Trash2 className="w-4 h-4 text-red-600" />
                            </button>
                          )}
                        </div>
                      ))}
                      {q.question_type !== 'TRUE_FALSE' && (
                        <button onClick={() => addChoice(qIdx)} className="mt-2 inline-flex items-center gap-1 px-3 py-2 border rounded hover:bg-gray-50">
                          <Plus className="w-4 h-4" /> Ajouter un choix
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>

              <div className="flex items-center justify-between">
                <button onClick={() => setStep(0)} className="px-4 py-2 rounded border">Précédent</button>
                <button onClick={handleNextFromQuestions} className="px-4 py-2 rounded bg-primary-500 text-white hover:bg-primary-600">Suivant</button>
              </div>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 border rounded">
                  <div className="text-sm text-gray-600">Titre</div>
                  <div className="font-medium text-gray-900">{form.title || '-'}</div>
                </div>
                <div className="p-4 border rounded">
                  <div className="text-sm text-gray-600">Matière</div>
                  <div className="font-medium text-gray-900">{subjectOptions.find(s => s.id === Number(form.subject_id))?.name || '-'}</div>
                </div>
                <div className="p-4 border rounded">
                  <div className="text-sm text-gray-600">Durée</div>
                  <div className="font-medium text-gray-900">{form.duration_minutes} min</div>
                </div>
                <div className="p-4 border rounded">
                  <div className="text-sm text-gray-600">Passage</div>
                  <div className="font-medium text-gray-900">{form.passing_percentage}%</div>
                </div>
                <div className="p-4 border rounded">
                  <div className="text-sm text-gray-600">Tentatives max</div>
                  <div className="font-medium text-gray-900">{form.max_attempts === '' || form.max_attempts == null ? 'Illimité' : form.max_attempts}</div>
                </div>
                <div className="p-4 border rounded">
                  <div className="text-sm text-gray-600">Points totaux</div>
                  <div className="font-medium text-gray-900">{totalPoints}</div>
                </div>
              </div>

              <div className="space-y-3">
                {form.questions.map((q, qIdx) => (
                  <div key={qIdx} className="p-4 border rounded">
                    <div className="flex items-start justify-between">
                      <div className="font-medium text-gray-900">Question {qIdx + 1} • {q.question_type}</div>
                      <div className="text-xs px-2 py-1 bg-primary-50 text-primary-700 rounded">{q.points} pts</div>
                    </div>
                    <div className="text-gray-700 mt-1">{q.text || '-'}</div>
                    <div className="mt-2 ml-4 space-y-1">
                      {q.choices.map((c, cIdx) => (
                        <div key={cIdx} className={`text-sm ${c.is_correct ? 'text-green-700 font-medium' : 'text-gray-600'}`}>
                          {String.fromCharCode(65 + cIdx)}. {c.text || '-'}{c.is_correct ? ' ✓' : ''}
                        </div>
                      ))}
                    </div>
                  </div>
                ))}
              </div>

              <div className="flex items-center justify-between">
                <button onClick={() => setStep(1)} className="px-4 py-2 rounded border">Précédent</button>
                <button onClick={handleSubmit} disabled={createMutation.isPending || updateMutation.isPending} className="px-4 py-2 rounded bg-primary-500 text-white hover:bg-primary-600 disabled:opacity-50">{isEdit ? 'Enregistrer les modifications' : 'Créer le quiz'}</button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
