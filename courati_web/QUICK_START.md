# 🚀 Quick Start - Courati Web

## Démarrage Rapide (3 étapes)

### 1. Vérifier que le backend Django tourne
```bash
# Dans le terminal du backend
cd courati_backend
python manage.py runserver
# Doit être sur http://127.0.0.1:8000
```

### 2. Installer les dépendances (si pas déjà fait)
```bash
cd courati_web
npm install
```

### 3. Lancer le serveur de développement
```bash
npm run dev
```

✅ **L'application sera accessible sur** : http://localhost:5173

---

## 📋 Prérequis

- ✅ Node.js >= 18.0.0
- ✅ npm >= 9.0.0
- ✅ Backend Django sur http://127.0.0.1:8000

**Vérifier les versions :**
```bash
node --version
npm --version
```

---

## 🔧 Configuration

### Variables d'environnement
Le fichier `.env` est déjà créé avec :
```env
VITE_API_BASE_URL=http://127.0.0.1:8000
```

Si besoin de modifier, éditez `.env`

---

## 📦 Packages Installés

**Total : 239 packages**

### Principaux (Production)
- React 19.2.0
- React Router 7.9.5
- TanStack Query 5.90.7
- Axios 1.13.2
- Zustand 5.0.8
- React Hook Form 7.66.0
- Zod 4.1.12
- Lucide React 0.553.0
- Recharts 3.4.1
- Sonner 2.0.7

### Principaux (Dev)
- Vite 7.2.2
- TypeScript 5.9.3
- TailwindCSS 4.1.17
- ESLint 9.39.1

---

## 🎯 Commandes Disponibles

```bash
# Développement (avec hot reload)
npm run dev

# Build production
npm run build

# Prévisualiser le build
npm run preview

# Linter
npm run lint
```

---

## 📁 Structure du Projet

```
courati_web/
├── src/
│   ├── api/              # Clients API (axios)
│   │   ├── client.ts     # ✅ Axios configuré
│   │   └── auth.ts       # ✅ API auth
│   ├── components/
│   │   ├── ui/           # Composants Shadcn (à ajouter)
│   │   ├── layout/       # Sidebar, Header (Étape 3)
│   │   └── common/       # Composants réutilisables
│   ├── pages/
│   │   ├── auth/         # LoginPage (Étape 2)
│   │   └── admin/        # Dashboard, etc. (Étapes 4-7)
│   ├── hooks/            # Custom hooks
│   ├── stores/
│   │   └── authStore.ts  # ✅ Store Zustand
│   ├── types/
│   │   └── index.ts      # ✅ Types TypeScript
│   ├── lib/
│   │   └── utils.ts      # ✅ Utilitaires
│   └── main.tsx          # Point d'entrée
├── public/               # Assets statiques
├── .env                  # ✅ Variables d'environnement
├── tailwind.config.js    # ✅ Config Tailwind
├── vite.config.ts        # ✅ Config Vite
└── package.json          # ✅ Dépendances
```

---

## 🎨 Design System

### Couleurs Courati
```css
Primaire   : #3B82F6 (Bleu)
Secondaire : #6366F1 (Indigo)
Succès     : #10B981 (Vert)
Attention  : #F59E0B (Orange)
Erreur     : #EF4444 (Rouge)
```

### Typographie
- **Font** : Inter (Google Fonts)
- **Poids** : 300, 400, 500, 600, 700, 800

---

## 🔐 Authentification

### Tokens JWT
Stockés dans `localStorage` :
- `access_token` - Token d'accès (courte durée)
- `refresh_token` - Token de rafraîchissement
- `user` - Données utilisateur (JSON)

### Refresh Automatique
L'intercepteur Axios gère automatiquement le refresh des tokens expirés.

---

## 🌐 API Backend

### Base URL
```
http://127.0.0.1:8000
```

### Endpoints Principaux
```
POST   /api/auth/login/              # Connexion
GET    /api/auth/profile/            # Profil utilisateur
POST   /api/auth/logout/             # Déconnexion
POST   /api/auth/token/refresh/      # Refresh token

GET    /api/auth/admin/dashboard/    # Dashboard admin
GET    /api/courses/admin/subjects/  # Matières
GET    /api/auth/admin/teachers/     # Enseignants
GET    /api/auth/admin/students/     # Étudiants
```

---

## 📚 Documentation

| Fichier | Description |
|---------|-------------|
| `README.md` | Documentation générale |
| `QUICK_START.md` | Ce fichier - Démarrage rapide |
| `SETUP_COMPLETE.md` | Résumé setup étape 1 |
| `ETAPE_1_RESUME.md` | Détails étape 1 |
| `DEPENDENCIES.md` | Liste des dépendances |
| `INSTALL_COMMANDS.md` | Commandes d'installation |
| `PACKAGES_INSTALLED.md` | 239 packages installés |

---

## 🐛 Troubleshooting

### Le serveur ne démarre pas
```bash
# Nettoyer et réinstaller
rm -rf node_modules package-lock.json
npm install
npm run dev
```

### Erreur "Cannot find module"
```bash
npm install
```

### Port 5173 déjà utilisé
Modifier `vite.config.ts` :
```typescript
server: {
  port: 3000, // ou autre port
}
```

### Erreur de connexion à l'API
Vérifier que le backend Django tourne sur `http://127.0.0.1:8000`

---

## ✅ Étape 1 : TERMINÉ

### Ce qui est prêt
- [x] Projet React + TypeScript + Vite
- [x] 239 packages installés
- [x] TailwindCSS configuré
- [x] Axios client avec intercepteurs
- [x] Auth store Zustand
- [x] Types TypeScript complets
- [x] Utilitaires (formatDate, etc.)
- [x] Documentation complète

### Prochaine étape
**Étape 2 : Authentification**
- Page de login moderne
- Hook useAuth
- Routes protégées
- Gestion erreurs

---

## 🎯 Objectif Final

### Interface Admin (Étapes 1-7)
- ✅ Setup (Étape 1)
- 🔜 Authentification (Étape 2)
- 🔜 Layout (Étape 3)
- 🔜 Dashboard (Étape 4)
- 🔜 Gestion Matières (Étape 5)
- 🔜 Gestion Enseignants (Étape 6)
- 🔜 Gestion Étudiants (Étape 7)

### Interface Enseignant (Étapes 8-10)
- 🔜 Dashboard Enseignant (Étape 8)
- 🔜 Gestion Documents (Étape 9)
- 🔜 Gestion Quiz (Étape 10)

---

## 💡 Conseils

### Développement
- Utiliser les **React DevTools** pour débugger
- Utiliser **TanStack Query DevTools** pour voir les requêtes
- Utiliser **Zustand DevTools** pour voir le state

### Performance
- Vite offre un **HMR instantané**
- Les builds sont **optimisés automatiquement**
- Le **code splitting** est géré par Vite

### Code Quality
- Lancer `npm run lint` régulièrement
- Utiliser TypeScript pour éviter les erreurs
- Suivre les conventions de nommage

---

## 📞 Support

En cas de problème :
1. Vérifier la documentation
2. Vérifier les logs du terminal
3. Vérifier que le backend tourne
4. Nettoyer et réinstaller les dépendances

---

**Prêt à développer ! 🚀**

**Prochaine commande :**
```bash
npm run dev
```

Puis ouvrir http://localhost:5173 dans le navigateur.
