@echo off
REM ========================================
REM 🚀 Script de démarrage Courati Backend
REM ========================================

REM Se déplacer dans le dossier du script
cd /d "%~dp0"

echo ========================================
echo 🚀 Démarrage de Courati Backend
echo ========================================
echo.

REM Vérifier si l'environnement virtuel existe
if not exist "venv\Scripts\activate.bat" (
    echo ❌ ERREUR : Environnement virtuel introuvable !
    echo.
    echo 💡 Créez-le d'abord avec : python -m venv venv
    echo.
    pause
    exit /b 1
)

echo 📦 Activation de l'environnement virtuel...
call venv\Scripts\activate
echo.

REM Vérifier si PostgreSQL est accessible
echo 🔍 Vérification de PostgreSQL...
python -c "import psycopg2" 2>nul
if errorlevel 1 (
    echo ⚠️ ATTENTION : psycopg2 non installé ou PostgreSQL inaccessible
    echo.
    echo 💡 Installez les dépendances : pip install -r requirements.txt
    echo.
    pause
)

REM Vérifier si Redis/Memurai est accessible
echo 🔍 Vérification de Redis/Memurai...
python -c "import redis; r=redis.Redis(host='localhost', port=6379); r.ping()" 2>nul
if errorlevel 1 (
    echo ⚠️ ATTENTION : Redis/Memurai n'est pas démarré !
    echo.
    echo 💡 Démarrez Memurai depuis le menu Démarrer (Windows)
    echo 💡 Ou installez-le : https://www.memurai.com/get-memurai
    echo.
    pause
)

echo.
echo 🌐 Démarrage Django (Terminal 1)...
start "Courati - Django Server" cmd /k "cd /d "%~dp0" && venv\Scripts\activate && python manage.py runserver 0.0.0.0:8000"
timeout /t 3 /nobreak > nul

echo.
echo ⚙️ Démarrage Celery Worker (Terminal 2)...
start "Courati - Celery Worker" cmd /k "cd /d "%~dp0" && venv\Scripts\activate && celery -A config worker --loglevel=info --pool=solo"
timeout /t 3 /nobreak > nul

echo.
echo ⏰ Démarrage Celery Beat (Terminal 3)...
start "Courati - Celery Beat" cmd /k "cd /d "%~dp0" && venv\Scripts\activate && celery -A config beat --loglevel=info"

echo.
echo ========================================
echo ✅ Tous les services sont démarrés !
echo ========================================
echo.
echo 📱 Backend API : http://localhost:8000
echo 📊 Admin Django : http://localhost:8000/admin
echo 📖 Documentation : http://localhost:8000/api/
echo 🔔 Notifications : Actives (Celery + Redis)
echo.
echo 💡 Pour arrêter : Fermez les 3 fenêtres de terminal
echo.
pause