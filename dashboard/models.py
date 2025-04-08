from django.db import models
from django.utils import timezone
import json


class Destination(models.Model):
    """
    Modèle représentant une destination touristique.
    """
    name = models.CharField(max_length=255, unique=True, help_text="Nom de la destination (ex: Paris,France)")
    slug = models.SlugField(max_length=255, unique=True, help_text="Slug pour les URLs")
    last_scraping = models.DateTimeField(null=True, blank=True, help_text="Date du dernier scraping")
    status = models.CharField(max_length=50, default="pending", help_text="Statut du dernier scraping")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name

    def update_scraping_status(self, status):
        """
        Met à jour le statut du scraping pour cette destination.

        Args:
            status: Nouveau statut (pending, running, completed, failed)
        """
        self.status = status
        if status == "completed":
            self.last_scraping = timezone.now()
        self.save()


class PriceData(models.Model):
    """
    Modèle représentant les données de prix pour une destination et un mois.
    """
    destination = models.ForeignKey(Destination, on_delete=models.CASCADE, related_name="price_data")
    year = models.IntegerField(help_text="Année des données")
    month = models.IntegerField(help_text="Mois (1-12)")
    month_name = models.CharField(max_length=20, help_text="Nom du mois")
    avg_price = models.FloatField(help_text="Prix moyen")
    median_price = models.FloatField(help_text="Prix médian")
    min_price = models.FloatField(help_text="Prix minimum")
    max_price = models.FloatField(help_text="Prix maximum")
    sample_size = models.IntegerField(help_text="Nombre d'échantillons")
    season = models.CharField(max_length=20, help_text="Saison")
    relative_price = models.FloatField(help_text="Prix relatif par rapport à la moyenne annuelle")
    price_rank = models.IntegerField(help_text="Rang du prix (du moins cher au plus cher)")
    is_cheapest = models.BooleanField(default=False, help_text="Indique si c'est le mois le moins cher")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('destination', 'year', 'month')
        ordering = ['month']

    def __str__(self):
        return f"{self.destination.name} - {self.month_name} {self.year}"


class AnalysisResult(models.Model):
    """
    Modèle contenant les résultats d'analyse pour une destination.
    """
    destination = models.ForeignKey(Destination, on_delete=models.CASCADE, related_name="analysis_results")
    year = models.IntegerField(help_text="Année de l'analyse")
    cheapest_month = models.CharField(max_length=20, help_text="Mois le moins cher")
    cheapest_month_price = models.FloatField(help_text="Prix moyen du mois le moins cher")
    most_expensive_month = models.CharField(max_length=20, help_text="Mois le plus cher")
    most_expensive_month_price = models.FloatField(help_text="Prix moyen du mois le plus cher")
    potential_savings = models.FloatField(
        help_text="Économies potentielles entre le mois le plus cher et le moins cher")
    savings_percentage = models.FloatField(help_text="Pourcentage d'économies")
    coefficient_of_variation = models.FloatField(help_text="Coefficient de variation des prix (écart-type / moyenne)")
    _statistics_json = models.TextField(db_column="statistics_json", help_text="Statistiques au format JSON")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('destination', 'year')

    def __str__(self):
        return f"Analyse {self.destination.name} - {self.year}"

    @property
    def statistics(self):
        """Retourne les statistiques sous forme de dictionnaire"""
        if self._statistics_json:
            return json.loads(self._statistics_json)
        return {}

    @statistics.setter
    def statistics(self, value):
        """Enregistre les statistiques au format JSON"""
        self._statistics_json = json.dumps(value)

    @property
    def season_analysis(self):
        """Retourne l'analyse par saison"""
        return self.statistics.get('season_analysis', {})

    @property
    def price_ranking(self):
        """Retourne le classement des mois par prix"""
        return self.statistics.get('price_ranking', [])


class ScrapingJob(models.Model):
    """
    Modèle pour suivre les tâches de scraping planifiées ou en cours.
    """
    destination = models.ForeignKey(Destination, on_delete=models.CASCADE, related_name="scraping_jobs")
    status = models.CharField(max_length=50, default="pending", help_text="Statut de la tâche")
    scheduled_time = models.DateTimeField(help_text="Heure planifiée")
    started_at = models.DateTimeField(null=True, blank=True, help_text="Heure de début")
    completed_at = models.DateTimeField(null=True, blank=True, help_text="Heure de fin")
    error_message = models.TextField(blank=True, null=True, help_text="Message d'erreur en cas d'échec")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-scheduled_time']

    def __str__(self):
        return f"Scraping de {self.destination.name} - {self.scheduled_time.strftime('%Y-%m-%d %H:%M')}"