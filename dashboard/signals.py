"""
Signaux Django pour l'application dashboard.
"""

import logging
from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Destination, PriceData, AnalysisResult, ScrapingJob

# Configuration du logger
logger = logging.getLogger('django')

@receiver(post_save, sender=Destination)
def log_destination_save(sender, instance, created, **kwargs):
    """
    Enregistre un message de log lorsqu'une destination est créée ou modifiée.
    """
    if created:
        logger.info(f"Nouvelle destination créée: {instance.name} (ID: {instance.id})")
    else:
        logger.info(f"Destination mise à jour: {instance.name} (ID: {instance.id})")

@receiver(post_delete, sender=Destination)
def log_destination_delete(sender, instance, **kwargs):
    """
    Enregistre un message de log lorsqu'une destination est supprimée.
    """
    logger.info(f"Destination supprimée: {instance.name} (ID: {instance.id})")

@receiver(post_save, sender=ScrapingJob)
def log_scraping_job_status(sender, instance, created, **kwargs):
    """
    Enregistre un message de log lorsqu'une tâche de scraping change de statut.
    """
    if created:
        logger.info(f"Nouvelle tâche de scraping créée pour {instance.destination.name} "
                   f"(ID: {instance.id}, statut: {instance.status})")
    else:
        # Si le statut a changé, on le log
        if hasattr(instance, '_original_status') and instance._original_status != instance.status:
            if instance.status == 'completed':
                logger.info(f"Tâche de scraping pour {instance.destination.name} terminée avec succès "
                           f"(ID: {instance.id})")
            elif instance.status == 'failed':
                logger.error(f"Tâche de scraping pour {instance.destination.name} échouée "
                            f"(ID: {instance.id}): {instance.error_message}")
            else:
                logger.info(f"Statut de la tâche de scraping pour {instance.destination.name} "
                           f"mis à jour: {instance.status} (ID: {instance.id})")

@receiver(post_save, sender=PriceData)
def log_price_data_save(sender, instance, created, **kwargs):
    """
    Enregistre un message de log lorsque des données de prix sont ajoutées.
    """
    if created:
        logger.debug(f"Nouvelles données de prix pour {instance.destination.name}, "
                    f"{instance.month_name} {instance.year}: {instance.avg_price}€")

@receiver(post_save, sender=AnalysisResult)
def log_analysis_result_save(sender, instance, created, **kwargs):
    """
    Enregistre un message de log lorsqu'un résultat d'analyse est ajouté.
    """
    if created:
        logger.info(f"Nouvelle analyse pour {instance.destination.name}, {instance.year}. "
                   f"Mois le moins cher: {instance.cheapest_month} ({instance.cheapest_month_price}€)")