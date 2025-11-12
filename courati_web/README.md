# Courati Web - Interface Admin & Enseignant

Interface web moderne pour la plateforme éducative Courati, destinée aux administrateurs et enseignants.

## 🚀 Technologies

- **React 18** + **TypeScript**
- **Vite** (build tool ultra-rapide)
- **TailwindCSS** (styling moderne)
- **React Router v6** (navigation)
- **TanStack Query** (gestion API et cache)
- **Zustand** (state management léger)
- **Axios** (client HTTP)
- **React Hook Form** + **Zod** (formulaires et validation)
- **Lucide React** (icônes modernes)
- **Recharts** (graphiques interactifs)
- **Sonner** (notifications toast)

## 📁 Structure du Projet

```
src/
├── api/              # Clients API
│   ├── client.ts     # Axios instance avec intercepteurs
│   ├── auth.ts       # API authentification
│   ├── dashboard.ts  # API dashboard
│   ├── subjects.ts   # API matières
│   ├── teachers.ts   # API enseignants
│   └── students.ts   # API étudiants
├── components/
│   ├── ui/           # Composants UI réutilisables
│   ├── layout/       # Layout (Sidebar, Header)
│   └── common/       # Composants communs
├── pages/
│   ├── auth/         # Pages authentification
│   └── admin/        # Pages admin
├── hooks/            # Custom hooks React
├── stores/           # Stores Zustand
├── types/            # Types TypeScript
├── lib/              # Utilitaires
└── App.tsx           # Point d'entrée
```

## 🔧 Installation

1. **Installer les dépendances :**
```bash
npm install
```

2. **Configurer les variables d'environnement :**
```bash
# Copier le fichier .env.example
cp .env.example .env

# Modifier l'URL de l'API si nécessaire
VITE_API_BASE_URL=http://127.0.0.1:8000
```

3. **Lancer le serveur de développement :**
```bash
npm run dev
```

L'application sera accessible sur `http://localhost:5173`

## 🏗️ Build pour Production

```bash
npm run build
```

Les fichiers optimisés seront dans le dossier `dist/`

## 📝 Scripts Disponibles

- `npm run dev` - Lancer le serveur de développement
- `npm run build` - Build pour production
- `npm run preview` - Prévisualiser le build de production
- `npm run lint` - Linter le code

## 🎯 Fonctionnalités

### Interface Administrateur
- ✅ Dashboard avec statistiques complètes
- ✅ Gestion des niveaux et filières
- ✅ Gestion des matières (CRUD complet)
- ✅ Gestion des enseignants + assignations
- ✅ Gestion des étudiants + actions en masse
- ✅ Export CSV des données
- ✅ Analytics avancées

### Interface Enseignant
- ✅ Dashboard personnel
- ✅ Gestion des documents (upload, modification)
- ✅ Création et gestion de quiz
- ✅ Suivi des étudiants
- ✅ Statistiques par matière

## 🔐 Authentification

L'application utilise JWT (JSON Web Tokens) pour l'authentification :
- Access token (courte durée)
- Refresh token (longue durée)
- Refresh automatique des tokens expirés

## 🌐 API Backend

L'API backend Django REST est accessible sur `http://127.0.0.1:8000`

Endpoints principaux :
- `/api/auth/login/` - Connexion
- `/api/auth/profile/` - Profil utilisateur
- `/api/courses/admin/subjects/` - Gestion matières
- `/api/auth/admin/teachers/` - Gestion enseignants
- `/api/auth/admin/students/` - Gestion étudiants

## 🎨 Design System

### Couleurs
- **Primaire** : Bleu #3B82F6
- **Secondaire** : Indigo #6366F1
- **Succès** : Vert #10B981
- **Attention** : Orange #F59E0B
- **Erreur** : Rouge #EF4444

### Typographie
- **Font** : Inter (Google Fonts)
- Design moderne et professionnel

## 📱 Responsive

L'interface est entièrement responsive :
- Desktop (>1024px) : Sidebar visible
- Tablet/Mobile (<1024px) : Sidebar collapse avec menu hamburger

## 🤝 Contribution

Ce projet fait partie de la plateforme Courati pour l'éducation en Mauritanie.

## 📄 Licence

Propriétaire - Courati © 2025
