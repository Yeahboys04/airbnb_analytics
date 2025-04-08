import logging
import traceback
from django.core.management.base import BaseCommand, CommandError
from django.conf import settings
from django.utils import timezone
from dashboard.models import Destination, ScrapingJob
from scraper.scraper import scrape_destination
from dashboard.views import process_and_save_results

logger = logging.getLogger('django')


class Command(BaseCommand):
    help = 'Lance le scraping pour une destination spécifique ou pour toutes les destinations'

    def add_arguments(self, parser):
        parser.add_argument(
            '--destination',
            dest='destination_id',
            help='ID de la destination à scraper'
        )

        parser.add_argument(
            '--all',
            action='store_true',
            dest='all_destinations',
            help='Scraper toutes les destinations'
        )

        parser.add_argument(
            '--scheduled',
            action='store_true',
            dest='scheduled_only',
            help='Exécuter uniquement les tâches planifiées dues'
        )

        parser.add_argument(
            '--headless',
            action='store_true',
            dest='headless',
            default=True,
            help='Exécuter le navigateur en mode headless (sans interface graphique)'
        )

    def handle(self, *args, **options):
        """Point d'entrée de la commande"""
        destination_id = options.get('destination_id')
        all_destinations = options.get('all_destinations')
        scheduled_only = options.get('scheduled_only')
        headless = options.get('headless')

        if scheduled_only:
            self.run_scheduled_jobs(headless)
            return

        if destination_id:
            # Scraper une destination spécifique
            try:
                destination = Destination.objects.get(id=destination_id)
                self.scrape_destination(destination, headless)
            except Destination.DoesNotExist:
                raise CommandError(f"Destination avec ID {destination_id} introuvable")

        elif all_destinations:
            # Scraper toutes les destinations
            destinations = Destination.objects.all()

            if not destinations.exists():
                self.stdout.write(self.style.WARNING("Aucune destination trouvée"))
                return

            self.stdout.write(f"Lancement du scraping pour {destinations.count()} destinations...")

            for destination in destinations:
                try:
                    self.scrape_destination(destination, headless)
                except Exception as e:
                    self.stdout.write(
                        self.style.ERROR(f"Erreur lors du scraping de {destination.name}: {str(e)}")
                    )
        else:
            self.stdout.write(
                self.style.WARNING(
                    "Veuillez spécifier une destination (--destination) ou utiliser --all pour toutes les destinations")
            )

    def scrape_destination(self, destination, headless=True):
        """
        Lance le scraping pour une destination.

        Args:
            destination: Instance du modèle Destination
            headless: Si True, exécute le navigateur en mode headless
        """
        job = ScrapingJob.objects.create(
            destination=destination,
            status='running',
            scheduled_time=timezone.now(),
            started_at=timezone.now()
        )

        destination.update_scraping_status('running')
        self.stdout.write(f"Début du scraping pour {destination.name}...")

        try:
            # Exécuter le scraper
            result_df = scrape_destination(
                destination.name,
                settings.DATA_DIR,
                headless=headless
            )

            if result_df is not None:
                # Traiter et sauvegarder les résultats
                process_and_save_results(destination, result_df)

                job.status = 'completed'
                job.completed_at = timezone.now()
                job.save()

                destination.update_scraping_status('completed')

                self.stdout.write(
                    self.style.SUCCESS(f"Scraping terminé avec succès pour {destination.name}")
                )
            else:
                raise Exception("Le scraping n'a pas renvoyé de résultats.")

        except Exception as e:
            error_msg = f"Erreur lors du scraping de {destination.name}: {str(e)}"
            error_trace = traceback.format_exc()
            logger.error(f"{error_msg}\n{error_trace}")

            job.status = 'failed'
            job.error_message = f"{error_msg}\n{error_trace}"
            job.completed_at = timezone.now()
            job.save()

            destination.update_scraping_status('failed')

            self.stdout.write(self.style.ERROR(error_msg))

    def run_scheduled_jobs(self, headless=True):
        """
        Exécute les tâches de scraping planifiées qui sont dues.

        Args:
            headless: Si True, exécute le navigateur en mode headless
        """
        now = timezone.now()

        # Récupérer les tâches planifiées dues
        due_jobs = ScrapingJob.objects.filter(
            status='pending',
            scheduled_time__lte=now
        )

        if not due_jobs.exists():
            self.stdout.write("Aucune tâche planifiée à exécuter")
            return

        self.stdout.write(f"Exécution de {due_jobs.count()} tâches planifiées...")

        for job in due_jobs:
            try:
                destination = job.destination

                job.status = 'running'
                job.started_at = timezone.now()
                job.save()

                destination.update_scraping_status('running')

                # Exécuter le scraper
                result_df = scrape_destination(
                    destination.name,
                    settings.DATA_DIR,
                    headless=headless
                )

                if result_df is not None:
                    # Traiter et sauvegarder les résultats
                    process_and_save_results(destination, result_df)

                    job.status = 'completed'
                    job.completed_at = timezone.now()
                    job.save()

                    destination.update_scraping_status('completed')

                    self.stdout.write(
                        self.style.SUCCESS(f"Tâche terminée avec succès pour {destination.name}")
                    )
                else:
                    raise Exception("Le scraping n'a pas renvoyé de résultats.")

            except Exception as e:
                error_msg = f"Erreur lors de l'exécution de la tâche {job.id}: {str(e)}"
                error_trace = traceback.format_exc()
                logger.error(f"{error_msg}\n{error_trace}")

                job.status = 'failed'
                job.error_message = f"{error_msg}\n{error_trace}"
                job.completed_at = timezone.now()
                job.save()

                if job.destination:
                    job.destination.update_scraping_status('failed')

                self.stdout.write(self.style.ERROR(error_msg))