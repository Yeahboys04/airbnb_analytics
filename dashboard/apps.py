from django.apps import AppConfig


class DashboardConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'dashboard'
    verbose_name = 'Tableau de bord Airbnb Analytics'

    def ready(self):
        """
        Méthode appelée lors du démarrage de l'application.
        Peut être utilisée pour configurer des signaux, des tâches périodiques, etc.
        """
        # Import pour éviter les imports circulaires
        import dashboard.signals  # noqa