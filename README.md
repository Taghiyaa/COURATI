# 🎓 Courati - Plateforme de Gestion Universitaire

Application complète de gestion des cours, documents, quiz et projets universitaires avec système de notifications push en temps réel.

---

## 📁 Structure du projet
```
Courati_app/
├── courati_backend/      # Backend Django REST API
│   ├── config/          # Configuration Django & Celery
│   ├── accounts/        # Gestion utilisateurs
│   ├── courses/         # Cours, documents, quiz
│   ├── notifications/   # Système de notifications
│   ├── firebase_credentials/  # Clés Firebase
│   ├── manage.py
│   ├── requirements.txt
│   └── start_dev.bat    # Script de démarrage développement
└── courati_mobile/       # Application mobile Flutter
    ├── lib/
    ├── android/
    ├── ios/
    └── pubspec.yaml
```

---

## 🚀 Installation

### Prérequis

- **Python 3.11+**
- **PostgreSQL 14+**
- **Redis** (Memurai sur Windows)
- **Flutter 3.x**
- **Firebase Project** configuré
- **Git**

---

### Backend (Django)

#### 1. Installation PostgreSQL

**Windows :**
1. Télécharger : https://www.postgresql.org/download/windows/
2. Installer PostgreSQL (inclut pgAdmin)
3. Ouvrir pgAdmin et créer une base de données :
```sql
CREATE DATABASE courati_db;
CREATE USER courati_user WITH PASSWORD 'votre_mot_de_passe';
ALTER ROLE courati_user SET client_encoding TO 'utf8';
ALTER ROLE courati_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE courati_user SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE courati_db TO courati_user;
```

**Linux :**
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Créer la base de données
sudo -u postgres psql
```
```sql
CREATE DATABASE courati_db;
CREATE USER courati_user WITH PASSWORD 'votre_mot_de_passe';
GRANT ALL PRIVILEGES ON DATABASE courati_db TO courati_user;
\q
```

**Mac :**
```bash
brew install postgresql
brew services start postgresql
createdb courati_db
```

---

#### 2. Installation Redis

**Windows (Memurai) :**
1. Télécharger : https://www.memurai.com/get-memurai
2. Installer et démarrer le service automatiquement

**Linux :**
```bash
sudo apt install redis-server
sudo systemctl start redis-server
sudo systemctl enable redis-server
```

**Mac :**
```bash
brew install redis
brew services start redis
```

**Vérifier Redis :**
```bash
# Windows
"C:\Program Files\Memurai\memurai-cli.exe" ping

# Linux/Mac
redis-cli ping
```

**Résultat attendu :** `PONG`

---

#### 3. Cloner le projet
```bash
git clone https://github.com/Taghiyaa/courati.git
cd courati/courati_backend
```

---

#### 4. Créer l'environnement virtuel
```bash
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/Mac
source venv/bin/activate
```

---

#### 5. Installer les dépendances
```bash
pip install -r requirements.txt
```

---

#### 6. Configuration

**Créez un fichier `.env` à la racine de `courati_backend` :**
```env
# Django
DEBUG=True
SECRET_KEY=votre-cle-secrete-tres-longue-et-complexe-generez-la
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0

# PostgreSQL
DB_NAME=courati_db
DB_USER=courati_user
DB_PASSWORD=votre_mot_de_passe
DB_HOST=localhost
DB_PORT=5432

# Redis
REDIS_URL=redis://localhost:6379/0

# Firebase
FIREBASE_CREDENTIALS_PATH=firebase_credentials/serviceAccountKey.json

# Email (optionnel)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=votre-email@gmail.com
EMAIL_HOST_PASSWORD=votre-mot-de-passe-app
```

**Configuration Firebase :**
1. Créer un projet sur https://console.firebase.google.com
2. Activer Firebase Cloud Messaging (FCM)
3. Télécharger `serviceAccountKey.json` (Settings → Service Accounts)
4. Créer le dossier `firebase_credentials/`
5. Placer `serviceAccountKey.json` dedans

---

#### 7. Migrations de base de données
```bash
python manage.py makemigrations
python manage.py migrate
python manage.py createsuperuser
```

---

#### 8. Démarrage

**Option A : Script automatique (Recommandé pour développement)**

Double-cliquez sur `start_dev.bat` (Windows)

**Option B : Manuel (3 terminaux)**
```bash
# Terminal 1 : Django
python manage.py runserver 0.0.0.0:8000

# Terminal 2 : Celery Worker
celery -A config worker --loglevel=info --pool=solo

# Terminal 3 : Celery Beat
celery -A config beat --loglevel=info
```

**Services disponibles :**
- **Backend API :** http://localhost:8000
- **Admin Django :** http://localhost:8000/admin
- **API Documentation :** http://localhost:8000/api/

**⚠️ Note :** Le script `start_dev.bat` est conçu pour le développement local. Pour un déploiement en production, voir section [Déploiement](#-déploiement).

---

### Mobile (Flutter)
```bash
cd courati_mobile
flutter pub get
flutter run
```

**Ou lancez depuis VS Code avec l'extension Flutter**

**Configuration Firebase pour mobile :**
1. Ajouter l'app Android dans Firebase Console
2. Télécharger `google-services.json`
3. Placer dans `android/app/`
4. Pour iOS : télécharger `GoogleService-Info.plist` → `ios/Runner/`

---

## 🛠️ Technologies

| Backend | Mobile | Services |
|---------|--------|----------|
| Python 3.13 | Flutter 3.x | Firebase FCM |
| Django 5.1.2 | Dart | Redis (Memurai) |
| Django REST Framework 3.15.2 | Provider | Celery 5.5.3 |
| **PostgreSQL 14+** | HTTP Client | JWT Authentication |
| Firebase Admin SDK 6.6.0 | Flutter Local Notifications | psycopg2-binary |

---

## 📦 Dépendances principales

**Backend (`requirements.txt`) :**
```txt
Django==5.1.2
djangorestframework==3.15.2
django-cors-headers==4.5.0
psycopg2-binary==2.9.10          # PostgreSQL adapter
celery==5.5.3                    # Tâches asynchrones
redis==5.2.0                     # Broker Celery
firebase-admin==6.6.0            # Notifications push
PyJWT==2.9.0                     # JWT tokens
python-decouple==3.8             # Variables d'environnement
Pillow==11.0.0                   # Images
djangorestframework-simplejwt==5.4.0
```

**Mobile (`pubspec.yaml`) :**
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  http: ^1.2.2
  firebase_messaging: ^15.0.0
  flutter_local_notifications: ^17.2.2
  shared_preferences: ^2.3.2
```

---

## ✨ Fonctionnalités

### Authentification & Sécurité
- ✅ JWT avec refresh automatique
- ✅ Validation par email (OTP)
- ✅ Gestion des rôles (Étudiant/Professeur/Admin)
- ✅ Tokens sécurisés avec expiration

### Gestion académique
- ✅ Cours organisés par niveau et filière
- ✅ Documents téléchargeables (Cours, TD, TP, Examens)
- ✅ Quiz interactifs avec correction automatique
- ✅ Projets de groupe avec suivi des tâches
- ✅ Statistiques de progression

### Notifications intelligentes
- ✅ Push en temps réel via Firebase Cloud Messaging
- ✅ Historique complet (50 dernières notifications)
- ✅ Préférences personnalisables par type
- ✅ Nettoyage automatique (>30 jours)
- ✅ Badge compteur de notifications non lues
- ✅ Navigation contextuelle depuis les notifications

### Expérience utilisateur
- ✅ Système de favoris pour documents et matières
- ✅ Historique de consultation détaillé
- ✅ Interface moderne et intuitive
- ✅ Mode hors ligne avec cache local
- ✅ Recherche avancée de contenus

---

## 🔔 Système de Notifications

### Architecture
```
Événement (nouveau document/quiz)
        ↓
Signal Django détecte l'événement
        ↓
Vérification des préférences utilisateur
        ↓
Enregistrement en BDD (NotificationHistory)
        ↓
Envoi notification push (Firebase)
        ↓
Notification reçue sur mobile
        ↓
Tap notification → Navigation contextuelle
```

### Types de notifications

| Type | Déclencheur | Données incluses | Action |
|------|-------------|------------------|--------|
| `new_document` | Prof ajoute un document | `document_id`, `subject_id`, `document_type` | Ouvre la page matière |
| `new_quiz` | Prof crée un quiz | `quiz_id`, `subject_id` | Ouvre la liste des quiz |
| `project_reminder` | Deadline proche (3j) | `project_id`, `deadline`, `days_left` | Ouvre le projet |

### Préférences utilisateur

Les utilisateurs peuvent personnaliser :
- ✅ **Notifications globales** : Activer/désactiver tout
- ✅ **Nouveaux documents** : Cours, TD, TP
- ✅ **Nouveaux quiz** : Évaluations
- ✅ **Rappels de deadlines** : Projets (à venir)

**API :** `GET/PUT /api/notifications/preferences/`

### Gestion automatique

- **Affichage limité :** 50 notifications maximum dans l'app
- **Nettoyage automatique :** Suppression après 30 jours (tous les jours à 3h00)
- **Performance :** ~0.09s par tâche de nettoyage
- **Scalabilité :** Optimisé pour 1000+ utilisateurs

---

## ⏰ Tâches automatiques (Celery)

### Architecture Celery
```
Celery Beat (Planificateur)
        ↓
Redis (Broker de messages)
        ↓
Celery Worker (Exécuteur)
        ↓
Base de données PostgreSQL
```

### Tâche : Nettoyage des notifications

**Nom :** `notifications.tasks.delete_old_notifications`

**Planification :** Tous les jours à 3h00 du matin

**Fonction :** 
- Supprime les notifications de plus de 30 jours
- Optimise la base de données
- Maintient les performances

**Logs typiques :**
```
[2025-10-28 03:00:00] 🗑️ [CELERY] Démarrage suppression des anciennes notifications...
[2025-10-28 03:00:00] ✅ [CELERY] 15 notification(s) supprimée(s) (>30 jours)
[2025-10-28 03:00:00] Task succeeded in 0.093s
```

### Lancer manuellement
```bash
python manage.py shell
```
```python
from notifications.tasks import delete_old_notifications, test_celery

# Test de Celery
result = test_celery.delay()
print(result.get(timeout=10))

# Nettoyage manuel
result = delete_old_notifications.delay()
print(result.get(timeout=10))
```

**Résultat attendu :**
```python
{
    'success': True,
    'deleted': 15,
    'message': '15 notifications supprimées',
    'threshold': '2025-09-28T03:00:00+00:00'
}
```

---

## 📡 API Endpoints

### Authentification
```
POST   /api/accounts/register/           # Inscription
POST   /api/accounts/login/              # Connexion (JWT)
POST   /api/accounts/logout/             # Déconnexion
POST   /api/accounts/token/refresh/      # Refresh token
POST   /api/accounts/verify-otp/         # Validation email
GET    /api/accounts/profile/            # Profil utilisateur
```

### Notifications
```
GET    /api/notifications/history/            # Liste (50 dernières)
PATCH  /api/notifications/history/{id}/read/  # Marquer comme lu
POST   /api/notifications/history/mark-all-read/ # Tout marquer
GET    /api/notifications/preferences/        # Récupérer préférences
PUT    /api/notifications/preferences/        # Modifier préférences
POST   /api/notifications/fcm-token/          # Enregistrer token FCM
DELETE /api/notifications/fcm-token/{token}/  # Supprimer token
```

### Cours & Documents
```
GET    /api/courses/subjects/             # Liste des matières
GET    /api/courses/subjects/{id}/        # Détails matière
GET    /api/courses/documents/            # Liste documents
GET    /api/courses/documents/{id}/       # Télécharger document
POST   /api/courses/documents/{id}/favorite/   # Ajouter aux favoris
DELETE /api/courses/documents/{id}/favorite/   # Retirer des favoris
GET    /api/courses/favorites/            # Mes documents favoris
```

### Quiz
```
GET    /api/quizzes/                      # Liste des quiz
GET    /api/quizzes/{id}/                 # Détails quiz
POST   /api/quizzes/{id}/submit/          # Soumettre réponses
GET    /api/quizzes/results/              # Mes résultats
```

### Projets
```
GET    /api/projects/                     # Liste des projets
GET    /api/projects/{id}/                # Détails projet
PATCH  /api/projects/{id}/tasks/{task_id}/ # Mettre à jour tâche
POST   /api/projects/{id}/submit/         # Soumettre projet
```

### Historique & Statistiques
```
GET    /api/history/consultations/        # Historique consultations
GET    /api/stats/dashboard/              # Tableau de bord
```

---

## 🗄️ Base de données PostgreSQL

### Connexion

**Ligne de commande :**
```bash
psql -U courati_user -d courati_db
```

**PgAdmin (Interface graphique) :**
1. Télécharger : https://www.pgadmin.org/
2. Se connecter avec les identifiants configurés

### Commandes SQL utiles
```sql
-- Voir toutes les tables
\dt

-- Voir la structure d'une table
\d notifications_notificationhistory

-- Compter les notifications
SELECT COUNT(*) FROM notifications_notificationhistory;

-- Voir les 10 dernières notifications
SELECT id, title, message, sent_at, read 
FROM notifications_notificationhistory 
ORDER BY sent_at DESC 
LIMIT 10;

-- Notifications non lues par utilisateur
SELECT u.username, COUNT(n.id) as unread_count
FROM accounts_user u
LEFT JOIN notifications_notificationhistory n ON u.id = n.user_id
WHERE n.read = false OR n.read IS NULL
GROUP BY u.username
ORDER BY unread_count DESC;

-- Supprimer les notifications de plus de 30 jours (manuel)
DELETE FROM notifications_notificationhistory 
WHERE sent_at < NOW() - INTERVAL '30 days';

-- Statistiques par type de notification
SELECT notification_type, COUNT(*) as count
FROM notifications_notificationhistory
GROUP BY notification_type
ORDER BY count DESC;
```

### Backup & Restore

**Sauvegarder la base de données :**
```bash
# Backup complet
pg_dump -U courati_user courati_db > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup avec compression
pg_dump -U courati_user courati_db | gzip > backup_$(date +%Y%m%d).sql.gz
```

**Restaurer :**
```bash
# Depuis un fichier SQL
psql -U courati_user courati_db < backup_20251028.sql

# Depuis un fichier compressé
gunzip -c backup_20251028.sql.gz | psql -U courati_user courati_db
```

**Backup automatique (cron Linux) :**
```bash
# Editer crontab
crontab -e

# Ajouter cette ligne (backup quotidien à 2h00)
0 2 * * * pg_dump -U courati_user courati_db | gzip > /backups/courati_$(date +\%Y\%m\%d).sql.gz
```

### Monitoring & Performance
```sql
-- Taille de la base de données
SELECT pg_size_pretty(pg_database_size('courati_db')) AS size;

-- Taille de chaque table
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;

-- Nombre de connexions actives
SELECT count(*) FROM pg_stat_activity WHERE datname = 'courati_db';

-- Requêtes lentes (>1 seconde)
SELECT pid, now() - query_start as duration, query
FROM pg_stat_activity
WHERE state = 'active' AND now() - query_start > interval '1 second';

-- Index inutilisés
SELECT schemaname, tablename, indexname
FROM pg_stat_user_indexes
WHERE idx_scan = 0
AND indexrelname NOT LIKE '%_pkey';
```

### Optimisations

**Index recommandés :**
```sql
-- Index sur les notifications
CREATE INDEX IF NOT EXISTS idx_notification_user ON notifications_notificationhistory(user_id);
CREATE INDEX IF NOT EXISTS idx_notification_sent_at ON notifications_notificationhistory(sent_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_read ON notifications_notificationhistory(read);

-- Index sur les documents
CREATE INDEX IF NOT EXISTS idx_document_subject ON courses_document(subject_id);
CREATE INDEX IF NOT EXISTS idx_document_created ON courses_document(created_at DESC);

-- Index sur les quiz
CREATE INDEX IF NOT EXISTS idx_quiz_subject ON quizzes_quiz(subject_id);
CREATE INDEX IF NOT EXISTS idx_quiz_active ON quizzes_quiz(is_active);
```

**Configuration PostgreSQL (`settings.py`) :**
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME'),
        'USER': config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST'),
        'PORT': config('DB_PORT'),
        'OPTIONS': {
            'connect_timeout': 10,
        },
        'CONN_MAX_AGE': 600,  # Connexions persistantes
    }
}
```

---

## 🧪 Tests

### Backend
```bash
# Tests unitaires
python manage.py test

# Test spécifique
python manage.py test notifications.tests

# Avec coverage
coverage run --source='.' manage.py test
coverage report
```

**Test Celery :**
```bash
python manage.py shell
```
```python
from notifications.tasks import test_celery

result = test_celery.delay()
print(result.get(timeout=10))
```

### Mobile
```bash
# Tests unitaires
flutter test

# Tests d'intégration
flutter test integration_test/

# Tests de widgets
flutter test test/widget_test.dart
```

---

## 📊 Performance

### Métriques

- **Temps de réponse API :** <100ms
- **Notification push :** <2s
- **Tâche Celery :** ~0.09s
- **Base de données :** PostgreSQL (optimisée)
- **Affichage limité :** 50 notifications
- **Nettoyage automatique :** Quotidien à 3h00
- **Scalabilité :** 1000+ utilisateurs simultanés

### Benchmark
```bash
# Test de charge avec Apache Bench
ab -n 1000 -c 10 http://localhost:8000/api/notifications/history/

# Résultats attendus :
# Requests per second: 250-300
# Time per request: 30-40ms
```

---

## 🔧 Maintenance

### Vérifier les services

**Redis :**
```bash
# Windows
"C:\Program Files\Memurai\memurai-cli.exe" ping

# Linux/Mac
redis-cli ping
```

**PostgreSQL :**
```bash
pg_isready -U courati_user -d courati_db
```

**Celery :**
```bash
celery -A config inspect active
celery -A config inspect stats
```

### Logs

**Django :**
```bash
# Les logs s'affichent dans le terminal du serveur
```

**Celery :**
```bash
# Les logs s'affichent dans les terminaux Worker et Beat
```

**PostgreSQL :**
```bash
# Linux
sudo tail -f /var/log/postgresql/postgresql-14-main.log

# Voir les requêtes lentes dans PostgreSQL
SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;
```

---

## 🚀 Déploiement

### Production avec Docker

**Créez `docker-compose.yml` :**
```yaml
version: '3.8'

services:
  db:
    image: postgres:14
    environment:
      POSTGRES_DB: courati_db
      POSTGRES_USER: courati_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  backend:
    build: ./courati_backend
    command: gunicorn config.wsgi:application --bind 0.0.0.0:8000
    environment:
      - DEBUG=False
      - DB_HOST=db
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis
    ports:
      - "8000:8000"

  celery_worker:
    build: ./courati_backend
    command: celery -A config worker --loglevel=info
    environment:
      - DB_HOST=db
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis

  celery_beat:
    build: ./courati_backend
    command: celery -A config beat --loglevel=info
    environment:
      - DB_HOST=db
      - REDIS_URL=redis://redis:6379/0
    depends_on:
      - db
      - redis

volumes:
  postgres_data:
```

**Démarrer :**
```bash
docker-compose up -d
```

---

### Production avec Supervisor (Linux)

**Installer Supervisor :**
```bash
sudo apt install supervisor
```

**Configuration (`/etc/supervisor/conf.d/courati.conf`) :**
```ini
[program:courati_django]
command=/home/user/courati_backend/venv/bin/gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 4
directory=/home/user/courati_backend
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/courati/django.log

[program:courati_celery_worker]
command=/home/user/courati_backend/venv/bin/celery -A config worker --loglevel=info
directory=/home/user/courati_backend
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/courati/celery_worker.log

[program:courati_celery_beat]
command=/home/user/courati_backend/venv/bin/celery -A config beat --loglevel=info
directory=/home/user/courati_backend
user=www-data
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/var/log/courati/celery_beat.log
```

**Démarrer :**
```bash
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all
```

---

### Déploiement sur Render/Heroku

**Render.com (gratuit) :**
1. Créer un compte sur https://render.com
2. Connecter votre repo GitHub
3. Créer un Web Service (Django)
4. Ajouter PostgreSQL Database
5. Ajouter Redis
6. Configurer les variables d'environnement
7. Déployer

**Heroku :**
```bash
heroku create courati-backend
heroku addons:create heroku-postgresql:hobby-dev
heroku addons:create heroku-redis:hobby-dev
git push heroku main
heroku run python manage.py migrate
heroku run python manage.py createsuperuser
```

---

## 🛡️ Sécurité

### Checklist de sécurité

- ✅ `DEBUG=False` en production
- ✅ `SECRET_KEY` fort et unique
- ✅ HTTPS activé (Let's Encrypt)
- ✅ CORS configuré correctement
- ✅ Rate limiting sur API
- ✅ JWT avec expiration courte
- ✅ Validation des données (serializers)
- ✅ Protection CSRF
- ✅ Sanitization des inputs utilisateur
- ✅ Backup automatique quotidien

### Configuration production (`settings.py`)
```python
# Production uniquement
if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = 'DENY'
    
    # HSTS
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
```

---

## 📝 Variables d'environnement

**Développement (`.env`) :**
```env
# Django
DEBUG=True
SECRET_KEY=dev-secret-key-change-me-in-production
ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0

# PostgreSQL
DB_NAME=courati_db
DB_USER=courati_user
DB_PASSWORD=votre_mot_de_passe
DB_HOST=localhost
DB_PORT=5432

# Redis
REDIS_URL=redis://localhost:6379/0

# Firebase
FIREBASE_CREDENTIALS_PATH=firebase_credentials/serviceAccountKey.json

# Email (optionnel)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_HOST_USER=votre-email@gmail.com
EMAIL_HOST_PASSWORD=votre-mot-de-passe-app
```

**Production :**
```env
DEBUG=False
SECRET_KEY=super-long-and-complex-production-secret-key-minimum-50-chars
ALLOWED_HOSTS=votre-domaine.com,www.votre-domaine.com,api.votre-domaine.com

DB_NAME=courati_prod
DB_USER=courati_prod_user
DB_PASSWORD=super-secure-password-minimum-16-chars
DB_HOST=db.example.com
DB_PORT=5432

REDIS_URL=redis://redis-cloud-url.com:6379/0

FIREBASE_CREDENTIALS_PATH=firebase_credentials/serviceAccountKey.json

# Sécurité
SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
CSRF_COOKIE_SECURE=True
```

---

## 📱 Configuration Firebase

### Étape par étape

**1. Créer un projet Firebase :**
- Aller sur https://console.firebase.google.com
- Cliquer sur "Ajouter un projet"
- Nom : Courati
- Activer Google Analytics (optionnel)

**2. Activer Firebase Cloud Messaging :**
- Dans la console → Build → Cloud Messaging
- Activer Cloud Messaging API

**3. Télécharger les credentials :**
- Settings (⚙️) → Project settings
- Service accounts → Generate new private key
- Sauvegarder comme `serviceAccountKey.json`

**4. Configuration mobile Android :**
- Dans la console → Add app → Android
- Package name : `com.courati.app`
- Télécharger `google-services.json`
- Placer dans `courati_mobile/android/app/`

**5. Configuration mobile iOS (optionnel) :**
- Add app → iOS
- Bundle ID : `com.courati.app`
- Télécharger `GoogleService-Info.plist`
- Placer dans `courati_mobile/ios/Runner/`

---

## 👨‍💻 Auteur

**Taghiya9**  
📧 Email: taghiya9@gmail.com  
🔗 GitHub: [@Taghiyaa](https://github.com/Taghiyaa)  
💼 LinkedIn: [Votre LinkedIn]

---

## 🤝 Contribution

Les contributions sont les bienvenues ! 

**Pour contribuer :**
1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit les changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

**Guidelines :**
- Code Python : PEP 8
- Code Dart : Effective Dart
- Tests unitaires obligatoires
- Documentation des fonctions

---

## 📄 Licence

MIT License

Copyright (c) 2024-2025 Taghiya9

