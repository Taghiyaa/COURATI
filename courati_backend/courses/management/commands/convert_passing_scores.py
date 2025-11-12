# courses/management/commands/convert_passing_percentages.py

from django.core.management.base import BaseCommand
from courses.models import Quiz

class Command(BaseCommand):
    help = 'Convertit les anciens passing_percentage en passing_percentage'

    def handle(self, *args, **options):
        quizzes = Quiz.objects.all()
        
        for quiz in quizzes:
            # Si vous aviez passing_percentage sur 20
            # Exemple: passing_percentage = 10/20 → passing_percentage = 50%
            if hasattr(quiz, 'passing_percentage'):
                old_score = float(quiz.passing_percentage)
                percentage = (old_score / 20) * 100
                
                quiz.passing_percentage = round(percentage, 2)
                quiz.save()
                
                self.stdout.write(
                    f"✓ Quiz '{quiz.title}': {old_score}/20 → {percentage}%"
                )
        
        self.stdout.write(self.style.SUCCESS(f'\n✅ {quizzes.count()} quiz convertis'))