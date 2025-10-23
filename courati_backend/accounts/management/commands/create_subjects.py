from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from accounts.models import Level, Major
from courses.models import Subject

User = get_user_model()

class Command(BaseCommand):
    help = 'Crée des matières associées aux niveaux et filières'

    def handle(self, *args, **options):
        self.stdout.write('Création des matières...')
        
        # Récupérer l'admin ami
        try:
            admin_user = User.objects.get(username='ali')
            self.stdout.write(f'Utilisation de l\'admin: {admin_user.username}')
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR('Admin "ali" non trouvé'))
            return

        # Récupérer les niveaux
        try:
            l1 = Level.objects.get(code='L1')
            l2 = Level.objects.get(code='L2')
            l3 = Level.objects.get(code='L3')
        except Level.DoesNotExist:
            self.stdout.write(self.style.ERROR('Niveaux non trouvés. Exécutez d\'abord: python manage.py create_test_data'))
            return
        
        # Récupérer les filières
        try:
            info = Major.objects.get(code='INFO')
            math = Major.objects.get(code='MATH')
            phys = Major.objects.get(code='PHYS')
        except Major.DoesNotExist:
            self.stdout.write(self.style.ERROR('Filières non trouvées. Exécutez d\'abord: python manage.py create_test_data'))
            return
        
        # Définir les matières
        subjects_data = [
            {
                'name': 'Algorithmique et Structures de Données',
                'code': 'INFO101',
                'description': 'Introduction à l\'algorithmique et aux structures de données',
                'credits': 6,
                'levels': [l1],
                'majors': [info]
            },
            {
                'name': 'Programmation Orientée Objet',
                'code': 'INFO201',
                'description': 'Concepts de POO avec Java',
                'credits': 6,
                'levels': [l2],
                'majors': [info]
            },
            {
                'name': 'Base de Données',
                'code': 'INFO202',
                'description': 'Conception et manipulation de bases de données',
                'credits': 5,
                'levels': [l2],
                'majors': [info]
            },
            {
                'name': 'Analyse Mathématique',
                'code': 'MATH101',
                'description': 'Fonctions, limites, dérivées et intégrales',
                'credits': 6,
                'levels': [l1],
                'majors': [math, info]
            },
            {
                'name': 'Algèbre Linéaire',
                'code': 'MATH102',
                'description': 'Espaces vectoriels, matrices et déterminants',
                'credits': 6,
                'levels': [l1],
                'majors': [math, info, phys]
            },
            {
                'name': 'Physique Générale',
                'code': 'PHYS101',
                'description': 'Mécanique et thermodynamique',
                'credits': 5,
                'levels': [l1],
                'majors': [phys, info]
            },
            {
                'name': 'Électromagnétisme',
                'code': 'PHYS201',
                'description': 'Champs électriques et magnétiques',
                'credits': 5,
                'levels': [l2],
                'majors': [phys]
            },
        ]
        
        # Créer les matières
        created_count = 0
        for subject_data in subjects_data:
            levels = subject_data.pop('levels')
            majors = subject_data.pop('majors')
            
            subject, created = Subject.objects.get_or_create(
                code=subject_data['code'],
                defaults={
                    'name': subject_data['name'],
                    'description': subject_data['description'],
                    'credits': subject_data['credits'],
                    'is_active': True,
                }
            )
            
            if created:
                subject.levels.set(levels)
                subject.majors.set(majors)
                created_count += 1
                self.stdout.write(
                    self.style.SUCCESS(f'✓ Matière créée: {subject.code} - {subject.name}')
                )
            else:
                self.stdout.write(f'- Matière existe déjà: {subject.code}')

        self.stdout.write(
            self.style.SUCCESS(f'\n{created_count} nouvelles matières créées!')
        )
        self.stdout.write(f'Total matières: {Subject.objects.count()}')