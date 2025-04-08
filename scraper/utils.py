"""
Fonctions utilitaires pour le module de scraping.
"""

import random
import time
import logging
import re
from datetime import datetime, timedelta
from urllib.parse import quote_plus
from .constants import USER_AGENTS, SEASONS

# Configuration du logger
logger = logging.getLogger('scraper')


def get_random_user_agent():
    """
    Renvoie un User-Agent aléatoire pour simuler un navigateur réel.

    Returns:
        Un User-Agent aléatoire
    """
    return random.choice(USER_AGENTS)


def random_delay(min_seconds=2, max_seconds=5):
    """
    Ajoute un délai aléatoire pour simuler un comportement humain
    et éviter d'être détecté comme bot.

    Args:
        min_seconds: Délai minimum en secondes
        max_seconds: Délai maximum en secondes
    """
    delay = random.uniform(min_seconds, max_seconds)
    time.sleep(delay)


def format_destination_for_url(destination):
    """
    Formate une destination pour une utilisation dans une URL.

    Args:
        destination: Destination (ex: "Paris, France")

    Returns:
        Destination formatée pour l'URL
    """
    # Nettoyer la destination et la formater pour l'URL
    formatted = destination.strip()
    # Remplacer les espaces par des tirets
    formatted = formatted.replace(' ', '-')
    # Remplacer les virgules par des doubles tirets (convention Airbnb)
    formatted = formatted.replace(',', '--')
    # Encoder les caractères spéciaux restants
    formatted = quote_plus(formatted)

    return formatted


def construct_search_url(base_url, destination, check_in_date, check_out_date, adults=2):
    """
    Construit l'URL de recherche Airbnb.

    Args:
        base_url: URL de base d'Airbnb
        destination: Nom de la destination (ex: "Paris, France")
        check_in_date: Date d'arrivée au format 'YYYY-MM-DD'
        check_out_date: Date de départ au format 'YYYY-MM-DD'
        adults: Nombre d'adultes

    Returns:
        URL formatée pour la recherche
    """
    # Formater la destination
    formatted_dest = format_destination_for_url(destination)

    # Construire l'URL avec les paramètres de recherche
    search_url = f"{base_url}/s/{formatted_dest}/homes"
    search_url += f"?checkin={check_in_date}&checkout={check_out_date}"
    search_url += f"&adults={adults}&children=0&infants=0&pets=0"

    logger.debug(f"URL de recherche construite: {search_url}")
    return search_url


def clean_price_text(price_text):
    """
    Nettoie et convertit un texte de prix en nombre.

    Args:
        price_text: Texte du prix (ex: "145 €", "1 045,50 €")

    Returns:
        Prix en nombre flottant, ou None si la conversion échoue
    """
    try:
        # Supprimer la devise et les espaces
        price_text = price_text.replace('€', '').replace(' ', '').replace('\xa0', '')

        # Remplacer les virgules par des points pour la décimale
        price_text = price_text.replace(',', '.')

        # Extraire le nombre avec regex
        match = re.search(r'(\d+(?:\.\d+)?)', price_text)
        if match:
            return float(match.group(1))
        else:
            return None
    except (ValueError, AttributeError):
        logger.warning(f"Impossible de convertir le prix: {price_text}")
        return None


def get_month_dates(year, month, stay_duration=7):
    """
    Calcule les dates de début et de fin pour un séjour au milieu du mois.

    Args:
        year: Année du séjour
        month: Mois du séjour (1-12)
        stay_duration: Durée du séjour en jours

    Returns:
        Tuple de dates (check_in, check_out) au format 'YYYY-MM-DD'
    """
    # Calculer le jour du milieu du mois (15 par défaut)
    check_in_date = datetime(year, month, 15)
    check_out_date = check_in_date + timedelta(days=stay_duration)

    # Formater en chaînes de caractères
    check_in_str = check_in_date.strftime('%Y-%m-%d')
    check_out_str = check_out_date.strftime('%Y-%m-%d')

    return check_in_str, check_out_str


def get_season(month):
    """
    Renvoie la saison correspondant à un mois donné.

    Args:
        month: Numéro du mois (1-12)

    Returns:
        Nom de la saison
    """
    return SEASONS.get(month, 'Inconnu')


def create_filename(destination, year, prefix='', suffix=''):
    """
    Crée un nom de fichier standardisé pour les données.

    Args:
        destination: Nom de la destination
        year: Année des données
        prefix: Préfixe optionnel
        suffix: Suffixe optionnel

    Returns:
        Nom de fichier formaté
    """
    # Formater la destination pour le nom de fichier
    formatted_dest = destination.replace(',', '_').replace(' ', '_')

    # Ajouter un timestamp pour rendre le nom unique
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

    # Construire le nom
    filename = f"{formatted_dest}_{year}"
    if prefix:
        filename = f"{prefix}_{filename}"
    if suffix:
        filename = f"{filename}_{suffix}"

    filename = f"{filename}_{timestamp}.csv"

    return filename