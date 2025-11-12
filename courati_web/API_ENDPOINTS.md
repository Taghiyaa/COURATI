# 📡 Endpoints API Backend

## Base URL
```
http://127.0.0.1:8000
```

---

## 🔐 Authentification

### Login
```
POST /api/auth/login/
Body: { username, password }
Response: { access, refresh, user: { id, username, email, role } }
```

---

## 📊 Dashboard Admin

### Statistiques
```
GET /api/auth/admin/dashboard/
Response: { dashboard: { ... } } ou { ... }
```

---

## 🎓 Niveaux (Levels)

### Liste
```
GET /api/auth/admin/levels/
Response: { results: [...] } ou [...]
```

### Détail
```
GET /api/auth/admin/levels/{id}/
```

### Créer
```
POST /api/auth/admin/levels/
Body: { code, name, description?, order }
```

### Modifier
```
PUT /api/auth/admin/levels/{id}/
Body: { code?, name?, description?, order? }
```

### Supprimer
```
DELETE /api/auth/admin/levels/{id}/
```

---

## 📚 Filières (Majors)

### Liste
```
GET /api/auth/admin/majors/
Response: { results: [...] } ou [...]
```

### Détail
```
GET /api/auth/admin/majors/{id}/
```

### Créer
```
POST /api/auth/admin/majors/
Body: { code, name, description? }
```

### Modifier
```
PUT /api/auth/admin/majors/{id}/
Body: { code?, name?, description? }
```

### Supprimer
```
DELETE /api/auth/admin/majors/{id}/
```

---

## 📖 Matières (Subjects)

### Liste
```
GET /api/courses/admin/subjects/
Query params: ?search=...&level=...&major=...
Response: {
  success: true,
  total_subjects: 10,
  subjects: [...],
  filters_applied: {...}
}
```

### Détail
```
GET /api/courses/admin/subjects/{id}/
```

### Créer
```
POST /api/courses/admin/subjects/
Body: { name, code, description?, levels: [], majors: [], credits?, semester? }
```

### Modifier
```
PUT /api/courses/admin/subjects/{id}/
Body: { name?, code?, description?, levels?, majors?, credits?, semester? }
```

### Supprimer
```
DELETE /api/courses/admin/subjects/{id}/
```

### Assigner Enseignant
```
POST /api/courses/admin/subjects/{id}/assign-teacher/
Body: { teacher_id }
```

### Retirer Enseignant
```
POST /api/courses/admin/subjects/{id}/remove-teacher/
Body: { teacher_id }
```

---

## 👨‍🏫 Enseignants (Teachers)

### ✅ Liste tous les enseignants
```
GET /api/auth/admin/teachers/
Query params: ?search=...&is_active=true
Response: { ... }
```

### ✅ Détail d'un enseignant
```
GET /api/auth/admin/teachers/{pk}/
Response: { 
  id: number,
  user: { id, username, email, first_name, last_name, is_active, role },
  phone_number: string,
  photo?: string,
  total_assignments?: number,
  active_assignments?: number,
  created_at: string,
  updated_at: string
}
```

### ✅ Créer un enseignant
```
POST /api/auth/admin/teachers/
Body: { 
  username: string,
  email: string,
  password: string,
  first_name: string,
  last_name: string,
  phone_number?: string
}
```

### ✅ Modifier un enseignant
```
PUT /api/auth/admin/teachers/{pk}/
Body: { 
  username?: string,
  email?: string,
  first_name?: string,
  last_name?: string,
  phone_number?: string,
  is_active?: boolean
}
```

### ✅ Supprimer un enseignant
```
DELETE /api/auth/admin/teachers/{pk}/
```

### ✅ Activer/Désactiver un enseignant
```
POST /api/auth/admin/teachers/{teacher_id}/toggle-active/
Response: { 
  id: number,
  user_id: number,
  is_active: boolean,
  ...
}
```

---

## 📚 Assignations (Teacher Assignments)

### ✅ Liste des assignations d'un enseignant
```
GET /api/auth/admin/teachers/{teacher_id}/assignments/
Response: { 
  assignments: [
    {
      id: number,
      teacher: number,
      subject: { id, code, name },
      can_edit_content: boolean,
      can_upload_documents: boolean,
      can_delete_documents: boolean,
      can_manage_students: boolean,
      notes: string,
      is_active: boolean,
      assigned_at: string
    }
  ]
}
```

### ✅ Créer une assignation
```
POST /api/auth/admin/teachers/{teacher_id}/assignments/
Body: {
  subject_id: number,
  can_edit_content?: boolean,    // default: true
  can_upload_documents?: boolean, // default: true
  can_delete_documents?: boolean, // default: true
  can_manage_students?: boolean,  // default: false
  notes?: string
}
```

### ✅ Modifier une assignation
```
PUT /api/auth/admin/assignments/{assignment_id}/
Body: {
  subject_id?: number,
  can_edit_content?: boolean,
  can_upload_documents?: boolean,
  can_delete_documents?: boolean,
  can_manage_students?: boolean,
  notes?: string,
  is_active?: boolean
}
```

### ✅ Supprimer une assignation
```
DELETE /api/auth/admin/assignments/{assignment_id}/
```

---

## 📝 Notes

- Tous les endpoints nécessitent un token JWT dans le header `Authorization: Bearer {token}`
- Les réponses paginées peuvent avoir le format `{ results: [...] }` ou directement `[...]`
- Les endpoints admin nécessitent le rôle `ADMIN`
