# Créez ce fichier : accounts/management/commands/create_test_data.py

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from accounts.models import Level, Major

User = get_user_model()

class Command(BaseCommand):
    help = 'Crée des données de test pour les niveaux et filières'

    def handle(self, *args, **options):
        self.stdout.write('Création des données de test...')
        
        # Créer un admin pour les relations
        admin_user, created = User.objects.get_or_create(
            username='admin',
            defaults={
                'email': 'admin@courati.com',
                'role': 'ADMIN',
                'is_staff': True,
                'first_name': 'Admin',
                'last_name': 'System'
            }
        )
        if created:
            admin_user.set_password('admin123')
            admin_user.save()
            self.stdout.write('Admin créé')

        # Créer les niveaux
        levels_data = [
            {'code': 'L1', 'name': 'Licence 1', 'order': 1},
            {'code': 'L2', 'name': 'Licence 2', 'order': 2},
            {'code': 'L3', 'name': 'Licence 3', 'order': 3},
            {'code': 'M1', 'name': 'Master 1', 'order': 4},
            {'code': 'M2', 'name': 'Master 2', 'order': 5},
        ]
        
        for level_data in levels_data:
            level, created = Level.objects.get_or_create(
                code=level_data['code'],
                defaults={
                    'name': level_data['name'],
                    'order': level_data['order'],
                    'is_active': True,
                    'created_by': admin_user
                }
            )
            if created:
                self.stdout.write(f'Niveau créé: {level}')

        # Créer les filières
        majors_data = [
            {'code': 'INFO', 'name': 'Informatique', 'department': 'Sciences et Technologies', 'order': 1},
            {'code': 'MATH', 'name': 'Mathématiques', 'department': 'Sciences et Technologies', 'order': 2},
            {'code': 'PHYS', 'name': 'Physique', 'department': 'Sciences et Technologies', 'order': 3},
            {'code': 'CHIM', 'name': 'Chimie', 'department': 'Sciences et Technologies', 'order': 4},
            {'code': 'BIO', 'name': 'Biologie', 'department': 'Sciences et Technologies', 'order': 5},
            {'code': 'ECO', 'name': 'Économie', 'department': 'Sciences Économiques', 'order': 6},
            {'code': 'GEST', 'name': 'Gestion', 'department': 'Sciences Économiques', 'order': 7},
        ]
        
        for major_data in majors_data:
            major, created = Major.objects.get_or_create(
                code=major_data['code'],
                defaults={
                    'name': major_data['name'],
                    'department': major_data['department'],
                    'order': major_data['order'],
                    'is_active': True,
                    'created_by': admin_user
                }
            )
            if created:
                self.stdout.write(f'Filière créée: {major}')

        self.stdout.write(
            self.style.SUCCESS('Données de test créées avec succès!')
        )