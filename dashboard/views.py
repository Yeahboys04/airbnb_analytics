import os
import logging
import json
from datetime import datetime, timedelta
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib import messages
from django.conf import settings
from django.urls import reverse
from django.http import JsonResponse
from django.utils import timezone
from django.views.generic import ListView, DetailView
from django.views.generic.edit import FormView
from django.db.models import Count, Avg, Max, Min
from django.contrib.auth.decorators import login_required
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt

from .models import Destination, PriceData, AnalysisResult, ScrapingJob
from .forms import DestinationForm, ScrapingForm

from scraper.scraper import scrape_destination
from analyzer.data_processor import process_data_for_destination

# Configuration du logger
logger = logging.getLogger('django')


class HomeView(ListView):
    """Vue pour la page d'accueil qui liste les destinations."""
    model = Destination
    template_name = 'dashboard/home.html'
    context_object_name = 'destinations'

    def get_queryset(self):
        return Destination.objects.all().order_by('-updated_at')

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)

        # Récupérer quelques statistiques globales
        destination_count = Destination.objects.count()
        recent_updates = Destination.objects.filter(
            last_scraping__isnull=False
        ).order_by('-last_scraping')[:5]

        # Trouver les destinations avec le mois le moins cher
        cheapest_months = {}
        for dest in Destination.objects.all():
            analysis = AnalysisResult.objects.filter(destination=dest).order_by('-year').first()
            if analysis:
                cheapest_months[dest.name] = {
                    'month': analysis.cheapest_month,
                    'price': analysis.cheapest_month_price
                }

        context.update({
            'destination_count': destination_count,
            'recent_updates': recent_updates,
            'cheapest_months': cheapest_months,
            'form': DestinationForm(),
        })

        return context


class DestinationDetailView(DetailView):
    """Vue détaillée pour une destination spécifique."""
    model = Destination
    template_name = 'dashboard/destination_detail.html'
    context_object_name = 'destination'
    slug_url_kwarg = 'slug'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        destination = self.object

        # Récupérer les dernières données de prix
        price_data = PriceData.objects.filter(destination=destination).order_by('month')

        # Récupérer la dernière analyse
        analysis = AnalysisResult.objects.filter(
            destination=destination
        ).order_by('-year').first()

        # Préparer les données pour les graphiques
        chart_data = {
            'months': [data.month_name for data in price_data],
            'avg_prices': [data.avg_price for data in price_data],
            'median_prices': [data.median_price for data in price_data],
            'min_prices': [data.min_price for data in price_data],
            'max_prices': [data.max_price for data in price_data],
        }

        # Données pour le graphique par saison
        season_data = {}
        if analysis:
            for season, data in analysis.season_analysis.items():
                season_data[season] = data.get('avg_price', 0)

            # Calcul des différences de prix
            if analysis.price_ranking and len(analysis.price_ranking) > 0:
                cheapest_price = analysis.price_ranking[0]['price']
                price_ranking_with_diff = []

                for month in analysis.price_ranking:
                    month_data = month.copy()

                    # Calculer la différence de prix et le pourcentage
                    if month['price'] != cheapest_price:
                        price_diff = month['price'] - cheapest_price
                        percentage_diff = (price_diff / cheapest_price) * 100
                        month_data['price_diff'] = price_diff
                        month_data['percentage_diff'] = percentage_diff
                    else:
                        month_data['price_diff'] = 0
                        month_data['percentage_diff'] = 0

                    price_ranking_with_diff.append(month_data)

                # Au lieu de modifier analysis.price_ranking directement,
                # ajoutons price_ranking_with_diff au contexte
                context['price_ranking'] = price_ranking_with_diff
            else:
                context['price_ranking'] = []

        context.update({
            'price_data': price_data,
            'analysis': analysis,
            'chart_data': json.dumps(chart_data),
            'season_data': json.dumps(season_data),
            'form': ScrapingForm(initial={'destination': destination.id}),
        })

        return context


class AddDestinationView(FormView):
    """Vue pour ajouter une nouvelle destination."""
    template_name = 'dashboard/add_destination.html'
    form_class = DestinationForm

    def form_valid(self, form):
        # Sauvegarder la nouvelle destination
        destination = form.save()
        messages.success(
            self.request,
            f"Destination '{destination.name}' ajoutée avec succès."
        )

        # Rediriger vers la page de détail
        return redirect('destination_detail', slug=destination.slug)



def run_scraper_view(request):
    if request.method == 'POST':
        form = ScrapingForm(request.POST)
        if form.is_valid():
            destination = form.cleaned_data['destination']

            # Créer une tâche de scraping
            job = ScrapingJob.objects.create(
                destination=destination,
                status='pending',
                scheduled_time=timezone.now()
            )

            # Mettre à jour le statut de la destination
            destination.update_scraping_status('pending')

            try:
                job.status = 'running'
                job.started_at = timezone.now()
                job.save()

                destination.update_scraping_status('running')

                # Exécuter le scraper
                result_df = scrape_destination(
                    destination.name,
                    settings.DATA_DIR,
                    year=datetime.now().year
                )

                if result_df is not None:
                    # Traiter et sauvegarder les résultats
                    process_and_save_results(destination, result_df)

                    job.status = 'completed'
                    job.completed_at = timezone.now()
                    job.save()

                    destination.update_scraping_status('completed')

                    messages.success(
                        request,
                        f"Scraping pour {destination.name} terminé avec succès."
                    )
                else:
                    raise Exception("Le scraping n'a pas renvoyé de résultats.")

            except Exception as e:
                logger.error(f"Erreur lors du scraping de {destination.name}: {str(e)}")

                job.status = 'failed'
                job.error_message = str(e)
                job.completed_at = timezone.now()
                job.save()

                destination.update_scraping_status('failed')

                messages.error(
                    request,
                    f"Erreur lors du scraping de {destination.name}: {str(e)}"
                )

            return redirect('destination_detail', slug=destination.slug)

    return redirect('home')


@csrf_exempt
def update_data_view(request, slug):
    """API pour mettre à jour les données d'une destination."""
    if request.method == 'POST':
        destination = get_object_or_404(Destination, slug=slug)

        try:
            # Traiter les données existantes si elles ne l'ont pas été
            df, stats = process_data_for_destination(settings.DATA_DIR, destination.name)

            if df is not None:
                # Sauvegarder les résultats
                process_and_save_results(destination, df, stats)

                return JsonResponse({
                    'status': 'success',
                    'message': f"Données pour {destination.name} mises à jour avec succès."
                })
            else:
                return JsonResponse({
                    'status': 'error',
                    'message': "Aucune donnée disponible pour cette destination."
                }, status=400)

        except Exception as e:
            logger.error(f"Erreur lors de la mise à jour des données: {str(e)}")
            return JsonResponse({
                'status': 'error',
                'message': f"Erreur: {str(e)}"
            }, status=500)

    return JsonResponse({
        'status': 'error',
        'message': "Méthode non autorisée."
    }, status=405)


def dashboard_view(request):
    """Vue pour le tableau de bord principal."""
    # Récupérer toutes les destinations avec leur dernière analyse
    destinations = Destination.objects.all()

    # Statistiques globales
    stats = {
        'destination_count': destinations.count(),
        'avg_savings': 0,
        'avg_variation': 0,
        'cheapest_seasons': {'Hiver': 0, 'Printemps': 0, 'Été': 0, 'Automne': 0}
    }

    # Données pour les graphiques
    destination_prices = []
    season_data = {'Hiver': [], 'Printemps': [], 'Été': [], 'Automne': []}
    savings_data = []

    # Collecter les données
    total_savings = 0
    total_variation = 0
    count = 0

    for dest in destinations:
        analysis = AnalysisResult.objects.filter(destination=dest).order_by('-year').first()

        if analysis:
            count += 1
            total_savings += analysis.savings_percentage
            total_variation += analysis.coefficient_of_variation

            # Trouver la saison la moins chère
            min_season_price = float('inf')
            min_season = None

            for season, data in analysis.season_analysis.items():
                season_data[season].append(data.get('avg_price', 0))

                if data.get('avg_price', float('inf')) < min_season_price:
                    min_season_price = data.get('avg_price', 0)
                    min_season = season

            if min_season:
                stats['cheapest_seasons'][min_season] += 1

            # Données pour le graphique des destinations
            destination_prices.append({
                'name': dest.name,
                'avg_price': analysis.statistics.get('annual_variation', {}).get('mean', 0),
                'min_price': analysis.cheapest_month_price,
                'max_price': analysis.most_expensive_month_price
            })

            # Données pour le graphique des économies
            savings_data.append({
                'name': dest.name,
                'savings': analysis.potential_savings,
                'percentage': analysis.savings_percentage
            })

    # Calculer les moyennes
    if count > 0:
        stats['avg_savings'] = round(total_savings / count, 2)
        stats['avg_variation'] = round(total_variation / count, 2)

    # Préparer le contexte
    context = {
        'stats': stats,
        'destinations': destinations,
        'destination_prices': json.dumps(destination_prices),
        'season_data': json.dumps(season_data),
        'savings_data': json.dumps(savings_data)
    }

    return render(request, 'dashboard/dashboard.html', context)


def price_comparison_view(request):
    """Vue pour comparer les prix entre les destinations."""
    destinations = Destination.objects.all()

    # Récupérer les paramètres de filtre
    selected_destinations = request.GET.getlist('destinations', [])
    selected_month = request.GET.get('month', '')

    if not selected_destinations and destinations.exists():
        # Par défaut, sélectionner toutes les destinations
        selected_destinations = [str(dest.id) for dest in destinations]

    # Convertir les IDs en entiers
    selected_dest_ids = [int(dest_id) for dest_id in selected_destinations if dest_id.isdigit()]

    # Préparer les données de comparaison
    comparison_data = []
    months_data = {}

    # Pour le débogage
    logger.info(f"Destinations sélectionnées: {selected_dest_ids}")

    for dest_id in selected_dest_ids:
        try:
            dest = Destination.objects.get(id=dest_id)
            price_data = PriceData.objects.filter(destination=dest)

            if selected_month and selected_month.isdigit():
                price_data = price_data.filter(month=int(selected_month))

            # Organiser les données par destination et par mois
            dest_data = {
                'name': dest.name,
                'months': {}
            }

            # Pour le débogage
            data_count = price_data.count()
            logger.info(f"Destination {dest.name} (ID: {dest.id}): {data_count} entrées de prix trouvées")

            for data in price_data:
                dest_data['months'][str(data.month)] = {
                    'name': data.month_name,
                    'avg_price': data.avg_price,
                    'is_cheapest': data.is_cheapest
                }
                months_data[data.month] = data.month_name
                # Pour le débogage
                logger.info(f"  - Mois {data.month} ({data.month_name}): {data.avg_price}€")

            comparison_data.append(dest_data)

        except Destination.DoesNotExist:
            logger.warning(f"Destination avec ID {dest_id} non trouvée")
            continue

    # Préparer les données pour le graphique
    chart_data = {
        'labels': [months_data.get(month, f"Mois {month}") for month in sorted(months_data.keys())],
        'datasets': []
    }

    colors = ['#FF6384', '#36A2EB', '#FFCE56', '#4BC0C0', '#9966FF', '#FF9F40']

    for i, dest_data in enumerate(comparison_data):
        dataset = {
            'label': dest_data['name'],
            'data': [],
            'backgroundColor': colors[i % len(colors)],
            'borderColor': colors[i % len(colors)],
            'fill': False
        }

        for month in sorted(months_data.keys()):
            month_str = str(month)
            if month_str in dest_data['months']:
                dataset['data'].append(dest_data['months'][month_str]['avg_price'])
            else:
                dataset['data'].append(None)

        chart_data['datasets'].append(dataset)

    # Pour le débogage
    logger.info(f"Mois disponibles: {', '.join([f'{k}:{v}' for k, v in months_data.items()])}")
    logger.info(f"Nombre de destinations dans comparison_data: {len(comparison_data)}")

    context = {
        'destinations': destinations,
        'selected_destinations': selected_dest_ids,
        'selected_month': selected_month,
        'comparison_data': comparison_data,
        'months': sorted([(k, v) for k, v in months_data.items()], key=lambda x: x[0]),
        'chart_data': json.dumps(chart_data)
    }

    return render(request, 'dashboard/price_comparison.html', context)


# Fonctions utilitaires

def process_and_save_results(destination, df, stats=None):
    """
    Traite les résultats du scraping, calcule les statistiques
    et les enregistre dans la base de données.

    Args:
        destination: Instance du modèle Destination
        df: DataFrame pandas contenant les données
        stats: Dictionnaire de statistiques (optionnel)
    """
    # Si les statistiques ne sont pas fournies, les calculer
    if stats is None:
        _, stats = process_data_for_destination(settings.DATA_DIR, destination.name)

    year = datetime.now().year

    # Supprimer les anciennes données
    PriceData.objects.filter(destination=destination, year=year).delete()
    AnalysisResult.objects.filter(destination=destination, year=year).delete()

    # Ajouter les nouvelles données de prix
    for _, row in df.iterrows():
        # S'assurer que toutes les colonnes requises existent
        # Si 'season' n'existe pas, utiliser une valeur par défaut basée sur le mois
        if 'season' not in row:
            month = row.get('month', 1)
            seasons = {
                12: 'Hiver', 1: 'Hiver', 2: 'Hiver',
                3: 'Printemps', 4: 'Printemps', 5: 'Printemps',
                6: 'Été', 7: 'Été', 8: 'Été',
                9: 'Automne', 10: 'Automne', 11: 'Automne'
            }
            season = seasons.get(month, 'Inconnu')
        else:
            season = row['season']

        # S'assurer que toutes les autres colonnes requises existent
        price_data = PriceData(
            destination=destination,
            year=year,
            month=row.get('month', 0),
            month_name=row.get('month_name', ''),
            avg_price=row.get('avg_price', 0),
            median_price=row.get('median_price', 0),
            min_price=row.get('min_price', 0),
            max_price=row.get('max_price', 0),
            sample_size=row.get('sample_size', 0),
            season=season,
            relative_price=row.get('relative_price', 1.0),
            price_rank=row.get('price_rank', 0),
            is_cheapest=row.get('is_cheapest', False)
        )
        price_data.save()

    # Créer l'analyse
    if stats:
        analysis = AnalysisResult(
            destination=destination,
            year=year,
            cheapest_month=stats.get('cheapest_month', {}).get('name', ''),
            cheapest_month_price=stats.get('cheapest_month', {}).get('avg_price', 0),
            most_expensive_month=stats.get('most_expensive_month', {}).get('name', ''),
            most_expensive_month_price=stats.get('most_expensive_month', {}).get('avg_price', 0),
            potential_savings=stats.get('potential_savings', 0),
            savings_percentage=stats.get('savings_percentage', 0),
            coefficient_of_variation=stats.get('annual_variation', {}).get('coefficient_of_variation', 0)
        )
        analysis.statistics = stats
        analysis.save()

    logger.info(f"Résultats enregistrés pour {destination.name}")