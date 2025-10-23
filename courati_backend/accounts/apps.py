from django.apps import AppConfig
from django.utils.translation import gettext_lazy as _


class AccountsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'accounts'
    verbose_name = _('Authentication et comptes')
    
    def ready(self):
        # Import models to ensure they are registered
        from . import models  # noqa
        import accounts.signals
