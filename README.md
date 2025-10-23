# 🎓 Courati - Plateforme de Gestion Universitaire

Application complète pour la gestion des cours, documents, quiz et projets universitaires.

---

## 📁 Structure du projet
```
Courati_app/
├── courati_backend/      # Backend Django REST API
└── courati_mobile/       # Application mobile Flutter
```

---

## 🚀 Installation

### Backend (Django)
```bash
cd courati_backend
python -m venv venv
venv\Scripts\activate      # Windows
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

### Mobile (Flutter)
```bash
cd courati_mobile
flutter pub get
flutter run
```

---

## 🛠️ Technologies

| Backend | Mobile |
|---------|--------|
| Python 3.13 | Flutter 3.x |
| Django 4.2 | Dart |
| Django REST Framework | Provider |
| Firebase Admin SDK | Firebase Messaging |
| PostgreSQL / SQLite | HTTP Client |

---

## ✨ Fonctionnalités

- ✅ Authentification JWT avec refresh automatique
- ✅ Gestion des cours par niveau et filière
- ✅ Documents (Cours, TD, TP) téléchargeables
- ✅ Quiz interactifs
- ✅ Projets de groupe avec suivi des tâches
- ✅ Notifications push en temps réel (Firebase)
- ✅ Système de favoris
- ✅ Historique de consultation

---

## 📱 Captures d'écran



---

## 👨‍💻 Auteur

**Taghiya9**  
📧 Email: taghiya9@gmail.com  
🔗 GitHub: [@Taghiyaa](https://github.com/Taghiyaa)

---

## 📄 Licence

MIT License

---

**Développé avec ❤️ pour la communauté universitaire**