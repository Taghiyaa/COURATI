@echo off
echo Setting up Courati Backend...

REM Create virtual environment if it doesn't exist
if not exist "venv\Scripts\activate" (
    echo Creating virtual environment...
    python -m venv venv
) else (
    echo Virtual environment already exists.
)

REM Activate the virtual environment
call venv\Scripts\activate.bat

echo Upgrading pip...
python -m pip install --upgrade pip

echo Installing requirements...
pip install -r requirements_win.txt

echo Making migrations...
python manage.py makemigrations

echo Applying migrations...
python manage.py migrate

echo Creating superuser...
python manage.py createsuperuser

echo.
echo Setup complete!
echo To start the server, run: python manage.py runserver
echo.

pause
