#!/usr/bin/env python
"""
Script pour créer tous les fichiers du projet Airbnb Analytics
avec leur contenu.

Exécutez ce script à la racine du projet après avoir créé
la structure des dossiers avec setup_project.sh.
"""

import os
import sys
import json

# Détecter si on est dans le dossier principal ou non
if os.path.basename(os.getcwd()) == 'airbnb_analytics':
    # On est déjà dans le dossier principal
    ROOT_DIR = os.getcwd()
else:
    # On peut être à un niveau supérieur
    ROOT_DIR = os.path.join(os.getcwd(), 'airbnb_analytics')
    if not os.path.exists(ROOT_DIR):
        os.makedirs(ROOT_DIR)

# Fichiers et leur contenu
FILES = {
    # Configuration du projet et requirements
    'requirements.txt': '''django==4.2.10
selenium==4.18.1
pandas==2.2.1
numpy==1.26.3
plotly==5.18.0
beautifulsoup4==4.12.3
webdriver-manager==4.0.1
python-dotenv==1.0.1
requests==2.31.0
sentry-sdk==1.40.4
djangorestframework==3.14.0
django-crispy-forms==2.1
crispy-bootstrap5==0.7
gunicorn==21.2.0
apscheduler==3.10.4
''',

    '.env.example': '''# Django settings
SECRET_KEY=django-insecure-change-me-in-production
DEBUG=True
ENVIRONMENT=development

# Sentry configuration
SENTRY_DSN=https://your-sentry-dsn.ingest.sentry.io/project

# Airbnb Scraper configuration
AIRBNB_BASE_URL=https://www.airbnb.fr
MAX_RETRIES=3
REQUEST_TIMEOUT=30
DEFAULT_DESTINATION=Paris,France

# Optional: Path to ChromeDriver if not using webdriver-manager
# CHROMEDRIVER_PATH=/path/to/chromedriver
''',

    # Fichiers Django principaux
    'manage.py': '''#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys


def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'airbnb_analytics.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
''',

    'airbnb_analytics/__init__.py': '# Ce fichier est vide, simplement pour marquer le répertoire comme package Python\n',

    'airbnb_analytics/settings.py': '''import os
import logging.config
from pathlib import Path
from dotenv import load_dotenv
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration
from sentry_sdk.integrations.logging import LoggingIntegration

# Charger les variables d'environnement
load_dotenv()

# Build paths inside the project
BASE_DIR = Path(__file__).resolve().parent.parent

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-default-key-for-development')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get('DEBUG', 'True') == 'True'

ALLOWED_HOSTS = ['localhost', '127.0.0.1']

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'dashboard.apps.DashboardConfig',
    'crispy_forms',
    'crispy_bootstrap5',
    'rest_framework',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'airbnb_analytics.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'airbnb_analytics.wsgi.application'

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# Internationalization
LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'Europe/Paris'
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = 'static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Crispy Forms
CRISPY_ALLOWED_TEMPLATE_PACKS = "bootstrap5"
CRISPY_TEMPLATE_PACK = "bootstrap5"

# Configuration des chemins pour les données et les logs
DATA_DIR = os.path.join(BASE_DIR, 'data')
LOGS_DIR = os.path.join(BASE_DIR, 'logs')

# Créer les répertoires s'ils n'existent pas
os.makedirs(os.path.join(DATA_DIR, 'raw'), exist_ok=True)
os.makedirs(os.path.join(DATA_DIR, 'processed'), exist_ok=True)
os.makedirs(LOGS_DIR, exist_ok=True)

# Configuration de Sentry
SENTRY_DSN = os.environ.get('SENTRY_DSN', '')
if SENTRY_DSN:
    sentry_logging = LoggingIntegration(
        level=logging.INFO,  # Capture les logs INFO et supérieurs
        event_level=logging.ERROR  # Envoie les logs ERROR et supérieurs à Sentry
    )

    sentry_sdk.init(
        dsn=SENTRY_DSN,
        integrations=[
            DjangoIntegration(),
            sentry_logging,
        ],
        # Définir un taux d'échantillonnage pour limiter le nombre d'événements envoyés
        traces_sample_rate=1.0,  # Ajuster selon le volume de trafic en production

        # Si vous souhaitez capturer des données personnelles, réglez sur False
        send_default_pii=False,

        # Nom de l'environnement (dev, staging, production)
        environment=os.environ.get('ENVIRONMENT', 'development'),
    )

# Configuration du logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
        'file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': os.path.join(LOGS_DIR, 'airbnb_analytics.log'),
            'maxBytes': 10485760,  # 10 MB
            'backupCount': 10,
            'formatter': 'verbose',
        },
        'scraper_file': {
            'level': 'INFO',
            'class': 'logging.handlers.RotatingFileHandler',
            'filename': os.path.join(LOGS_DIR, 'scraper.log'),
            'maxBytes': 10485760,  # 10 MB
            'backupCount': 5,
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': True,
        },
        'scraper': {
            'handlers': ['console', 'scraper_file'],
            'level': 'INFO',
            'propagate': False,
        },
        'analyzer': {
            'handlers': ['console', 'file'],
            'level': 'INFO',
            'propagate': False,
        },
    },
}

# Variables spécifiques à l'application
AIRBNB_BASE_URL = os.environ.get('AIRBNB_BASE_URL', 'https://www.airbnb.fr')
CHROMEDRIVER_PATH = os.environ.get('CHROMEDRIVER_PATH', '')
MAX_RETRIES = int(os.environ.get('MAX_RETRIES', '3'))
REQUEST_TIMEOUT = int(os.environ.get('REQUEST_TIMEOUT', '30'))
DEFAULT_DESTINATION = os.environ.get('DEFAULT_DESTINATION', 'Paris,France')
''',

    'airbnb_analytics/urls.py': '''from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('dashboard.urls')),  # Redirection vers les URLs de l'app dashboard
]

# Ajout des URLs pour servir les fichiers statiques en développement
if settings.DEBUG:
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
''',

    'airbnb_analytics/wsgi.py': '''"""
WSGI config for airbnb_analytics project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/4.2/howto/deployment/wsgi/
"""

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'airbnb_analytics.settings')

application = get_wsgi_application()
''',

    'airbnb_analytics/asgi.py': '''"""
ASGI config for airbnb_analytics project.

It exposes the ASGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/4.2/howto/deployment/asgi/
"""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'airbnb_analytics.settings')

application = get_asgi_application()
''',

    # Scraper
    'scraper/__init__.py': '# Ce fichier est vide, simplement pour marquer le répertoire comme package Python\n',

    'scraper/constants.py': '''"""
Constantes utilisées par le module de scraping.
"""

# User agents pour simuler un navigateur réel
USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/111.0",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.3 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/111.0.0.0 Safari/537.36",
]

# Sélecteurs CSS pour extraire les données
SELECTORS = {
    'price_container': "[data-testid='card-container']",
    'price_element': 'span[data-testid="price-element"] span',
    'alternative_price': 'span._tyxjp1',
    'cookie_button': "button[data-testid='accept-btn']",
}

# Délais pour simuler un comportement humain (en secondes)
DELAYS = {
    'page_load': (2, 5),        # (min, max) délai après chargement de page
    'scroll': (1, 2),           # délai durant le scroll
    'between_months': (8, 15),  # délai entre les requêtes de différents mois
    'retry': (5, 10),           # délai entre les tentatives après échec
}

# Durée de séjour par défaut pour les recherches (en jours)
DEFAULT_STAY_DURATION = 7

# Nombre d'adultes par défaut pour les recherches
DEFAULT_ADULTS = 2

# Saisons correspondant aux mois
SEASONS = {
    12: 'Hiver', 1: 'Hiver', 2: 'Hiver',
    3: 'Printemps', 4: 'Printemps', 5: 'Printemps',
    6: 'Été', 7: 'Été', 8: 'Été',
    9: 'Automne', 10: 'Automne', 11: 'Automne'
}

# Messages d'erreur
ERROR_MESSAGES = {
    'driver_init': "Erreur lors de l'initialisation du driver Selenium",
    'no_prices': "Aucun prix n'a pu être extrait de la page",
    'timeout': "Délai d'attente dépassé lors du chargement de la page",
    'navigation': "Erreur lors de la navigation vers l'URL",
    'extraction': "Erreur lors de l'extraction des données",
    'parse_error': "Erreur lors de l'analyse des prix",
}
''',

    'scraper/utils.py': '''"""
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
''',

    'scraper/scraper.py': '''import os
import time
import random
import json
import logging
import pandas as pd
from datetime import datetime, timedelta
from pathlib import Path
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import (
    TimeoutException, NoSuchElementException, StaleElementReferenceException,
    WebDriverException
)
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup

# Configuration du logger
logger = logging.getLogger('scraper')

class AirbnbScraper:
    """
    Classe pour scraper les prix des hébergements sur Airbnb pour une destination
    donnée sur une période de 12 mois.
    """

    def __init__(self, base_url, data_dir, headless=True, max_retries=3, timeout=30):
        """
        Initialise le scraper Airbnb.

        Args:
            base_url: URL de base d'Airbnb
            data_dir: Répertoire où stocker les données
            headless: Si True, exécute le navigateur en mode headless (sans interface graphique)
            max_retries: Nombre maximal de tentatives en cas d'échec
            timeout: Délai d'attente maximum pour les éléments web (en secondes)
        """
        self.base_url = base_url
        self.raw_data_dir = Path(data_dir) / 'raw'
        self.max_retries = max_retries
        self.timeout = timeout

        # Configurer les options du navigateur
        self.chrome_options = Options()
        if headless:
            self.chrome_options.add_argument("--headless")

        self.chrome_options.add_argument("--window-size=1920,1080")
        self.chrome_options.add_argument("--disable-notifications")
        self.chrome_options.add_argument("--disable-infobars")
        self.chrome_options.add_argument("--disable-extensions")
        self.chrome_options.add_argument("--disable-gpu")
        self.chrome_options.add_argument("--no-sandbox")
        self.chrome_options.add_argument("--disable-dev-shm-usage")

        # Ajouter un user agent réaliste
        self.chrome_options.add_argument("user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36")

        # Initialiser le driver à None (sera créé lors de l'appel à run)
        self.driver = None

        logger.info("AirbnbScraper initialisé avec succès")

    def __enter__(self):
        """Permet l'utilisation avec le bloc 'with'"""
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Ferme le navigateur à la fin du bloc 'with'"""
        self.close()
        if exc_type:
            logger.error(f"Exception lors du scraping: {exc_type.__name__}: {exc_val}")
            return False
        return True

    def _setup_driver(self):
        """Configure et initialise le driver Selenium"""
        try:
            service = Service(ChromeDriverManager().install())
            self.driver = webdriver.Chrome(service=service, options=self.chrome_options)
            self.driver.implicitly_wait(10)
            logger.info("Driver Selenium initialisé avec succès")
            return True
        except WebDriverException as e:
            logger.error(f"Erreur lors de l'initialisation du driver: {str(e)}")
            return False

    def close(self):
        """Ferme le navigateur s'il est ouvert"""
        if self.driver:
            self.driver.quit()
            self.driver = None
            logger.info("Driver Selenium fermé")

    def _random_delay(self, min_seconds=2, max_seconds=5):
        """
        Ajoute un délai aléatoire pour simuler un comportement humain
        et éviter d'être détecté comme bot.
        """
        delay = random.uniform(min_seconds, max_seconds)
        time.sleep(delay)

    def _construct_search_url(self, destination, check_in_date, check_out_date):
        """
        Construit l'URL de recherche Airbnb.

        Args:
            destination: Nom de la destination (ex: "Paris,France")
            check_in_date: Date d'arrivée au format 'YYYY-MM-DD'
            check_out_date: Date de départ au format 'YYYY-MM-DD'

        Returns:
            URL formatée pour la recherche
        """
        # Formater la destination pour l'URL (remplacer les espaces par des tirets)
        formatted_dest = destination.replace(' ', '-').replace(',', '--')

        # Construire l'URL avec les paramètres de recherche
        search_url = f"{self.base_url}/s/{formatted_dest}/homes"
        search_url += f"?checkin={check_in_date}&checkout={check_out_date}"
        search_url += "&adults=2&children=0&infants=0&pets=0"

        logger.debug(f"URL de recherche construite: {search_url}")
        return search_url

    def _extract_prices(self):
        """
        Extrait les prix des hébergements de la page actuelle.

        Returns:
            Liste des prix extraits (en nombre flottant)
        """
        prices = []
        retry_count = 0

        while retry_count < self.max_retries and not prices:
            try:
                # Attendre que les éléments de prix soient chargés
                WebDriverWait(self.driver, self.timeout).until(
                    EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid='card-container']"))
                )

                # Faire défiler la page pour charger tous les résultats
                self._scroll_page()

                # Obtenir le HTML de la page et l'analyser avec BeautifulSoup
                html = self.driver.page_source
                soup = BeautifulSoup(html, 'html.parser')

                # Trouver tous les conteneurs de cartes d'hébergement
                listings = soup.find_all("div", attrs={"data-testid": "card-container"})
                logger.info(f"Nombre d'hébergements trouvés: {len(listings)}")

                # Extraire les prix
                for listing in listings:
                    # Chercher l'élément de prix (le sélecteur peut varier, donc plusieurs tentatives)
                    price_element = listing.select_one('span[data-testid="price-element"] span')

                    if not price_element:
                        price_element = listing.select_one('span._tyxjp1')  # Alternative CSS selector

                    if price_element:
                        price_text = price_element.get_text().strip()
                        # Nettoyer le texte du prix (supprimer la devise et les espaces)
                        price_text = price_text.replace('€', '').replace(' ', '').replace('\xa0', '')
                        try:
                            # Convertir en nombre (gérer la virgule comme séparateur décimal)
                            price = float(price_text.replace(',', '.'))
                            prices.append(price)
                        except ValueError:
                            logger.warning(f"Impossible de convertir le prix: {price_text}")

                logger.info(f"Extraction réussie de {len(prices)} prix")
                return prices

            except (TimeoutException, NoSuchElementException, StaleElementReferenceException) as e:
                retry_count += 1
                logger.warning(f"Tentative {retry_count}/{self.max_retries} échouée: {str(e)}")
                self._random_delay(3, 7)

        logger.error(f"Échec de l'extraction des prix après {self.max_retries} tentatives")
        return prices

    def _scroll_page(self):
        """Fait défiler la page pour charger tous les résultats"""
        last_height = self.driver.execute_script("return document.body.scrollHeight")

        while True:
            # Faire défiler jusqu'en bas
            self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")

            # Attendre le chargement
            self._random_delay(1, 2)

            # Calculer la nouvelle hauteur
            new_height = self.driver.execute_script("return document.body.scrollHeight")

            # Si la hauteur n'a pas changé, on a atteint le bas
            if new_height == last_height:
                break

            last_height = new_height

    def get_monthly_prices(self, destination, year=None, stay_duration=7):
        """
        Récupère les prix moyens pour chaque mois de l'année.

        Args:
            destination: Destination à rechercher (ex: "Paris,France")
            year: Année pour la recherche (si None, utilise l'année en cours)
            stay_duration: Durée du séjour en jours

        Returns:
            DataFrame pandas avec les prix moyens, médians, min et max par mois
        """
        if not year:
            year = datetime.now().year

        logger.info(f"Début du scraping des prix pour {destination} en {year}")

        if not self._setup_driver():
            logger.error("Impossible de configurer le driver Selenium, abandon du scraping")
            return None

        results = []

        # Pour chaque mois de l'année
        for month in range(1, 13):
            try:
                # Définir les dates de séjour (milieu du mois)
                check_in_date = datetime(year, month, 15)
                check_out_date = check_in_date + timedelta(days=stay_duration)

                # Formater les dates pour l'URL
                check_in_str = check_in_date.strftime('%Y-%m-%d')
                check_out_str = check_out_date.strftime('%Y-%m-%d')

                logger.info(f"Scraping du mois {month} ({check_in_str} à {check_out_str})")

                # Construire et visiter l'URL
                url = self._construct_search_url(destination, check_in_str, check_out_str)

                for attempt in range(self.max_retries):
                    try:
                        logger.info(f"Navigation vers {url}")
                        self.driver.get(url)
                        self._random_delay()

                        # Accepter les cookies si nécessaire
                        try:
                            WebDriverWait(self.driver, 10).until(
                                EC.element_to_be_clickable((By.CSS_SELECTOR, "button[data-testid='accept-btn']"))
                            ).click()
                            logger.info("Cookies acceptés")
                        except (TimeoutException, NoSuchElementException):
                            # Pas de popup de cookies ou déjà accepté
                            pass

                        # Extraire les prix
                        prices = self._extract_prices()

                        if prices:
                            month_name = check_in_date.strftime('%B')
                            avg_price = sum(prices) / len(prices) if prices else 0

                            month_data = {
                                'month': month,
                                'month_name': month_name,
                                'avg_price': avg_price,
                                'median_price': pd.Series(prices).median() if prices else 0,
                                'min_price': min(prices) if prices else 0,
                                'max_price': max(prices) if prices else 0,
                                'sample_size': len(prices),
                                'check_in': check_in_str,
                                'check_out': check_out_str
                            }

                            results.append(month_data)
                            logger.info(f"Mois {month_name}: prix moyen = {avg_price:.2f}€, {len(prices)} échantillons")
                            break

                    except WebDriverException as e:
                        logger.warning(f"Tentative {attempt+1}/{self.max_retries} échouée: {str(e)}")
                        if attempt < self.max_retries - 1:
                            self._random_delay(5, 10)  # Délai plus long entre les tentatives

                # Attendre entre chaque mois pour éviter de surcharger le site
                self._random_delay(8, 15)

            except Exception as e:
                logger.error(f"Erreur lors du scraping du mois {month}: {str(e)}")

        # Créer un DataFrame à partir des résultats
        if results:
            df = pd.DataFrame(results)

            # Sauvegarder les données brutes
            output_file = self.raw_data_dir / f"{destination.replace(',', '_')}_{year}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
            df.to_csv(output_file, index=False)
            logger.info(f"Données sauvegardées dans {output_file}")

            return df
        else:
            logger.warning("Aucun résultat obtenu pour la destination et l'année spécifiées")
            return None

    def run(self, destination, year=None, stay_duration=7):
        """
        Point d'entrée principal pour exécuter le scraping.

        Args:
            destination: Destination à rechercher
            year: Année pour la recherche (défaut: année courante)
            stay_duration: Durée du séjour en jours

        Returns:
            DataFrame des résultats ou None en cas d'échec
        """
        try:
            return self.get_monthly_prices(destination, year, stay_duration)
        except Exception as e:
            logger.error(f"Erreur fatale lors du scraping: {str(e)}", exc_info=True)
            return None
        finally:
            self.close()


# Fonction pour utilisation directe du module
def scrape_destination(destination, data_dir, year=None, stay_duration=7, headless=True):
    """
    Fonction utilitaire pour scraper une destination depuis un autre module.

    Args:
        destination: Destination à rechercher (ex: "Paris,France")
        data_dir: Répertoire de données
        year: Année pour la recherche
        stay_duration: Durée du séjour en jours
        headless: Si True, exécute le navigateur en mode headless

    Returns:
        DataFrame avec les résultats ou None en cas d'échec
    """
    from django.conf import settings

    base_url = settings.AIRBNB_BASE_URL
    max_retries = settings.MAX_RETRIES
    timeout = settings.REQUEST_TIMEOUT

    with AirbnbScraper(base_url, data_dir, headless, max_retries, timeout) as scraper:
        logger.info(f"Début du scraping pour {destination}")
        result = scraper.run(destination, year, stay_duration)
        if result is not None:
            logger.info(f"Scraping terminé avec succès pour {destination}")
        else:
            logger.error(f"Échec du scraping pour {destination}")
        return result


if __name__ == "__main__":
    # Point d'entrée pour exécution directe (tests)
    import sys
    from django.conf import settings

    logging.config.dictConfig(settings.LOGGING)

    destination = sys.argv[1] if len(sys.argv) > 1 else "Paris,France"
    data_dir = settings.DATA_DIR

    print(f"Scraping de {destination}...")
    result = scrape_destination(destination, data_dir, headless=False)

    if result is not None:
        print("\nRésultats:")
        print(result.sort_values('avg_price')[['month_name', 'avg_price', 'sample_size']])

        cheapest_month = result.loc[result['avg_price'].idxmin()]
        print(f"\nMois le moins cher: {cheapest_month['month_name']} "
              f"(moyenne: {cheapest_month['avg_price']:.2f}€)")
    else:
        print("Le scraping a échoué.")
''',

    # Analyzer
    'analyzer/__init__.py': '# Ce fichier est vide, simplement pour marquer le répertoire comme package Python\n',

    'analyzer/data_processor.py': '''import os
import glob
import logging
import pandas as pd
import numpy as np
from pathlib import Path
from datetime import datetime

# Configuration du logger
logger = logging.getLogger('analyzer')

class AirbnbDataProcessor:
    """
    Classe pour le traitement et l'analyse des données d'Airbnb collectées par le scraper.
    """

    def __init__(self, data_dir):
        """
        Initialise le processeur de données.

        Args:
            data_dir: Répertoire principal des données
        """
        self.raw_data_dir = Path(data_dir) / 'raw'
        self.processed_data_dir = Path(data_dir) / 'processed'

        # S'assurer que le répertoire de données traitées existe
        os.makedirs(self.processed_data_dir, exist_ok=True)

        logger.info("AirbnbDataProcessor initialisé avec succès")

    def get_latest_data(self, destination):
        """
        Récupère le fichier de données le plus récent pour une destination.

        Args:
            destination: Nom de la destination (ex: "Paris,France")

        Returns:
            Chemin du fichier CSV le plus récent ou None si aucun n'est trouvé
        """
        # Formater la destination pour correspondre au format des noms de fichiers
        formatted_dest = destination.replace(',', '_')

        # Trouver tous les fichiers correspondant au modèle
        pattern = f"{formatted_dest}_*.csv"
        files = glob.glob(str(self.raw_data_dir / pattern))

        if not files:
            logger.warning(f"Aucun fichier de données trouvé pour {destination}")
            return None

        # Trier par date de modification (le plus récent en premier)
        latest_file = max(files, key=os.path.getmtime)
        logger.info(f"Fichier le plus récent pour {destination}: {latest_file}")

        return latest_file

    def load_data(self, file_path):
        """
        Charge les données à partir d'un fichier CSV.

        Args:
            file_path: Chemin vers le fichier CSV

        Returns:
            DataFrame pandas ou None en cas d'erreur
        """
        try:
            df = pd.read_csv(file_path)
            logger.info(f"Données chargées avec succès: {df.shape[0]} lignes, {df.shape[1]} colonnes")
            return df
        except Exception as e:
            logger.error(f"Erreur lors du chargement des données: {str(e)}")
            return None

    def process_data(self, df):
        """
        Traite les données brutes pour les analyser.

        Args:
            df: DataFrame pandas contenant les données brutes

        Returns:
            DataFrame traité avec des colonnes et analyses supplémentaires
        """
        if df is None or df.empty:
            logger.warning("Aucune donnée à traiter")
            return None

        try:
            # Copier le DataFrame pour ne pas modifier l'original
            processed_df = df.copy()

            # S'assurer que les colonnes numériques sont du bon type
            numeric_cols = ['avg_price', 'median_price', 'min_price', 'max_price', 'sample_size']
            for col in numeric_cols:
                if col in processed_df.columns:
                    processed_df[col] = pd.to_numeric(processed_df[col], errors='coerce')

            # Ajouter une colonne pour l'écart-type des prix
            processed_df['price_range'] = processed_df['max_price'] - processed_df['min_price']

            # Ajouter une colonne pour le prix relatif (par rapport à la moyenne annuelle)
            annual_avg = processed_df['avg_price'].mean()
            processed_df['relative_price'] = processed_df['avg_price'] / annual_avg

            # Ajouter un indicateur de saison
            seasons = {
                12: 'Hiver', 1: 'Hiver', 2: 'Hiver',
                3: 'Printemps', 4: 'Printemps', 5: 'Printemps',
                6: 'Été', 7: 'Été', 8: 'Été',
                9: 'Automne', 10: 'Automne', 11: 'Automne'
            }
            processed_df['season'] = processed_df['month'].map(seasons)

            # Trouver le mois le moins cher
            cheapest_month_idx = processed_df['avg_price'].idxmin()
            processed_df['is_cheapest'] = False
            processed_df.loc[cheapest_month_idx, 'is_cheapest'] = True

            # Calculer le rang de prix (du moins cher au plus cher)
            processed_df['price_rank'] = processed_df['avg_price'].rank()

            # Calculer la différence en pourcentage par rapport au mois le plus cher
            most_expensive = processed_df['avg_price'].max()
            processed_df['pct_diff_from_max'] = (
                (processed_df['avg_price'] - most_expensive) / most_expensive * 100
            )

            # Calculer la différence en pourcentage par rapport au mois le moins cher
            cheapest = processed_df['avg_price'].min()
            processed_df['pct_diff_from_min'] = (
                (processed_df['avg_price'] - cheapest) / cheapest * 100
            )

            # Trier par mois pour une meilleure lisibilité
            processed_df = processed_df.sort_values('month')

            logger.info("Données traitées avec succès")
            return processed_df

        except Exception as e:
            logger.error(f"Erreur lors du traitement des données: {str(e)}")
            return df  # Retourner les données originales en cas d'erreur

    def calculate_statistics(self, df):
        """
        Calcule des statistiques supplémentaires sur les données.

        Args:
            df: DataFrame traité

        Returns:
            Dictionnaire contenant les statistiques calculées
        """
        if df is None or df.empty:
            logger.warning("Aucune donnée pour calculer les statistiques")
            return {}

        try:
            stats = {}

            # Informations sur le mois le moins cher
            cheapest_month = df.loc[df['avg_price'].idxmin()]
            stats['cheapest_month'] = {
                'name': cheapest_month['month_name'],
                'avg_price': round(cheapest_month['avg_price'], 2),
                'median_price': round(cheapest_month['median_price'], 2),
                'season': cheapest_month['season']
            }

            # Informations sur le mois le plus cher
            most_expensive_month = df.loc[df['avg_price'].idxmax()]
            stats['most_expensive_month'] = {
                'name': most_expensive_month['month_name'],
                'avg_price': round(most_expensive_month['avg_price'], 2),
                'median_price': round(most_expensive_month['median_price'], 2),
                'season': most_expensive_month['season']
            }

            # Économie potentielle
            potential_savings = most_expensive_month['avg_price'] - cheapest_month['avg_price']
            stats['potential_savings'] = round(potential_savings, 2)
            stats['savings_percentage'] = round(
                (potential_savings / most_expensive_month['avg_price']) * 100, 2
            )

            # Statistiques par saison
            season_stats = df.groupby('season').agg({
                'avg_price': ['mean', 'min', 'max'],
                'month_name': lambda x: ', '.join(x),
            }).reset_index()

            stats['season_analysis'] = {}
            for _, row in season_stats.iterrows():
                season = row['season']
                stats['season_analysis'][season] = {
                    'avg_price': round(row[('avg_price', 'mean')], 2),
                    'min_price': round(row[('avg_price', 'min')], 2),
                    'max_price': round(row[('avg_price', 'max')], 2),
                    'months': row[('month_name', '<lambda>')],
                }

            # Variation de prix annuelle
            stats['annual_variation'] = {
                'mean': round(df['avg_price'].mean(), 2),
                'median': round(df['avg_price'].median(), 2),
                'std': round(df['avg_price'].std(), 2),
                'min': round(df['avg_price'].min(), 2),
                'max': round(df['avg_price'].max(), 2),
                'coefficient_of_variation': round(
                    (df['avg_price'].std() / df['avg_price'].mean()) * 100, 2
                )
            }

            # Créer une liste de tous les mois ordonnés par prix
            price_ranking = df.sort_values('avg_price')[['month_name', 'avg_price', 'season']]
            stats['price_ranking'] = []

            for _, row in price_ranking.iterrows():
                stats['price_ranking'].append({
                    'month': row['month_name'],
                    'price': round(row['avg_price'], 2),
                    'season': row['season']
                })

            logger.info("Statistiques calculées avec succès")
            return stats

        except Exception as e:
            logger.error(f"Erreur lors du calcul des statistiques: {str(e)}")
            return {}

    def save_processed_data(self, df, destination):
        """
        Sauvegarde les données traitées dans un fichier CSV.

        Args:
            df: DataFrame à sauvegarder
            destination: Nom de la destination

        Returns:
            Chemin du fichier sauvegardé ou None en cas d'erreur
        """
        if df is None or df.empty:
            logger.warning("Aucune donnée à sauvegarder")
            return None

        try:
            # Formater la destination pour le nom de fichier
            formatted_dest = destination.replace(',', '_')
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

            # Créer le chemin de fichier
            file_path = self.processed_data_dir / f"{formatted_dest}_processed_{timestamp}.csv"

            # Sauvegarder le DataFrame
            df.to_csv(file_path, index=False)
            logger.info(f"Données traitées sauvegardées dans {file_path}")

            return file_path

        except Exception as e:
            logger.error(f"Erreur lors de la sauvegarde des données: {str(e)}")
            return None

    def get_or_process_data(self, destination):
        """
        Récupère et traite les données pour une destination.
        Si des données traitées récentes existent, les utilise.
        Sinon, charge les données brutes et les traite.

        Args:
            destination: Nom de la destination

        Returns:
            Tuple (DataFrame traité, statistiques, chemin du fichier)
        """
        # Chercher d'abord le fichier brut le plus récent
        latest_raw_file = self.get_latest_data(destination)

        if not latest_raw_file:
            logger.warning(f"Aucune donnée disponible pour {destination}")
            return None, {}, None

        # Charger les données brutes
        raw_df = self.load_data(latest_raw_file)

        if raw_df is None:
            return None, {}, None

        # Traiter les données
        processed_df = self.process_data(raw_df)

        # Calculer les statistiques
        stats = self.calculate_statistics(processed_df)

        # Sauvegarder les données traitées
        saved_file = self.save_processed_data(processed_df, destination)

        return processed_df, stats, saved_file


# Fonction pour utilisation directe du module
def process_data_for_destination(data_dir, destination):
    """
    Fonction utilitaire pour traiter les données d'une destination.

    Args:
        data_dir: Répertoire principal des données
        destination: Destination à analyser

    Returns:
        Tuple (DataFrame traité, statistiques)
    """
    processor = AirbnbDataProcessor(data_dir)
    df, stats, _ = processor.get_or_process_data(destination)
    return df, stats


if __name__ == "__main__":
    # Point d'entrée pour exécution directe (tests)
    import sys
    from django.conf import settings

    logging.config.dictConfig(settings.LOGGING)

    destination = sys.argv[1] if len(sys.argv) > 1 else "Paris,France"
    data_dir = settings.DATA_DIR

    print(f"Traitement des données pour {destination}...")
    processor = AirbnbDataProcessor(data_dir)
    df, stats, _ = processor.get_or_process_data(destination)

    if df is not None:
        print("\nAperçu des données traitées:")
        print(df[['month_name', 'avg_price', 'relative_price', 'season', 'price_rank']].head())

        print("\nMois le moins cher:")
        print(f"{stats['cheapest_month']['name']} ({stats['cheapest_month']['avg_price']}€)")

        print("\nÉconomie potentielle:")
        print(f"{stats['potential_savings']}€ ({stats['savings_percentage']}%)")
    else:
        print("Le traitement a échoué.")
''',

    'analyzer/statistics.py': '''"""
Fonctions pour calculer diverses statistiques sur les données de prix Airbnb.
"""

import logging
import numpy as np
import pandas as pd
from collections import defaultdict

# Configuration du logger
logger = logging.getLogger('analyzer')

def calculate_basic_stats(prices):
    """
    Calcule les statistiques de base pour une série de prix.

    Args:
        prices: Liste ou Series de prix

    Returns:
        Dictionnaire contenant les statistiques
    """
    if not prices or len(prices) == 0:
        logger.warning("Aucun prix fourni pour le calcul des statistiques")
        return {
            'mean': 0,
            'median': 0,
            'min': 0,
            'max': 0,
            'std': 0,
            'count': 0,
            'coefficient_of_variation': 0
        }

    prices_series = pd.Series(prices)

    stats = {
        'mean': prices_series.mean(),
        'median': prices_series.median(),
        'min': prices_series.min(),
        'max': prices_series.max(),
        'std': prices_series.std(),
        'count': len(prices_series),
        'coefficient_of_variation': prices_series.std() / prices_series.mean() * 100 if prices_series.mean() > 0 else 0
    }

    return stats

def calculate_monthly_statistics(df):
    """
    Calcule des statistiques supplémentaires pour les données mensuelles.

    Args:
        df: DataFrame pandas contenant les données mensuelles

    Returns:
        Dictionnaire contenant les statistiques
    """
    if df is None or df.empty:
        logger.warning("Aucune donnée pour calculer les statistiques mensuelles")
        return {}

    try:
        stats = {}

        # Informations sur le mois le moins cher
        cheapest_month = df.loc[df['avg_price'].idxmin()]
        stats['cheapest_month'] = {
            'name': cheapest_month['month_name'],
            'avg_price': round(cheapest_month['avg_price'], 2),
            'median_price': round(cheapest_month['median_price'], 2),
            'season': cheapest_month['season']
        }

        # Informations sur le mois le plus cher
        most_expensive_month = df.loc[df['avg_price'].idxmax()]
        stats['most_expensive_month'] = {
            'name': most_expensive_month['month_name'],
            'avg_price': round(most_expensive_month['avg_price'], 2),
            'median_price': round(most_expensive_month['median_price'], 2),
            'season': most_expensive_month['season']
        }

        # Économie potentielle
        potential_savings = most_expensive_month['avg_price'] - cheapest_month['avg_price']
        stats['potential_savings'] = round(potential_savings, 2)
        stats['savings_percentage'] = round(
            (potential_savings / most_expensive_month['avg_price']) * 100, 2
        ) if most_expensive_month['avg_price'] > 0 else 0

        # Statistiques par saison
        season_stats = df.groupby('season').agg({
            'avg_price': ['mean', 'min', 'max'],
            'month_name': lambda x: ', '.join(x),
        }).reset_index()

        stats['season_analysis'] = {}
        for _, row in season_stats.iterrows():
            season = row['season']
            stats['season_analysis'][season] = {
                'avg_price': round(row[('avg_price', 'mean')], 2),
                'min_price': round(row[('avg_price', 'min')], 2),
                'max_price': round(row[('avg_price', 'max')], 2),
                'months': row[('month_name', '<lambda>')],
            }

        # Variation de prix annuelle
        stats['annual_variation'] = {
            'mean': round(df['avg_price'].mean(), 2),
            'median': round(df['avg_price'].median(), 2),
            'std': round(df['avg_price'].std(), 2),
            'min': round(df['avg_price'].min(), 2),
            'max': round(df['avg_price'].max(), 2),
            'coefficient_of_variation': round(
                (df['avg_price'].std() / df['avg_price'].mean()) * 100, 2
            ) if df['avg_price'].mean() > 0 else 0
        }

        # Créer une liste de tous les mois ordonnés par prix
        price_ranking = df.sort_values('avg_price')[['month_name', 'avg_price', 'season']]
        stats['price_ranking'] = []

        for _, row in price_ranking.iterrows():
            stats['price_ranking'].append({
                'month': row['month_name'],
                'price': round(row['avg_price'], 2),
                'season': row['season']
            })

        logger.info("Statistiques mensuelles calculées avec succès")
        return stats

    except Exception as e:
        logger.error(f"Erreur lors du calcul des statistiques mensuelles: {str(e)}")
        return {}

def calculate_comparison_statistics(destinations_data):
    """
    Calcule des statistiques comparatives entre plusieurs destinations.

    Args:
        destinations_data: Dict avec les destinations comme clés et DataFrame comme valeurs

    Returns:
        Dictionnaire contenant les statistiques comparatives
    """
    if not destinations_data:
        logger.warning("Aucune donnée pour calculer les statistiques comparatives")
        return {}

    try:
        stats = {
            'cheapest_overall': {},
            'most_expensive_overall': {},
            'best_savings': {},
            'seasonal_comparison': defaultdict(list),
            'price_correlation': {},
            'avg_prices_by_destination': {},
        }

        # Calculer le prix moyen pour chaque destination
        for dest_name, df in destinations_data.items():
            if df is None or df.empty:
                continue

            avg_price = df['avg_price'].mean()
            stats['avg_prices_by_destination'][dest_name] = round(avg_price, 2)

            # Collecter les données par saison
            for season in df['season'].unique():
                season_avg = df[df['season'] == season]['avg_price'].mean()
                stats['seasonal_comparison'][season].append({
                    'destination': dest_name,
                    'avg_price': round(season_avg, 2)
                })

        # Trouver la destination la moins chère en général
        if stats['avg_prices_by_destination']:
            min_dest = min(stats['avg_prices_by_destination'].items(), key=lambda x: x[1])
            stats['cheapest_overall'] = {
                'destination': min_dest[0],
                'avg_price': min_dest[1]
            }

            # Trouver la destination la plus chère en général
            max_dest = max(stats['avg_prices_by_destination'].items(), key=lambda x: x[1])
            stats['most_expensive_overall'] = {
                'destination': max_dest[0],
                'avg_price': max_dest[1]
            }

        # Calculer les économies potentielles pour chaque destination
        savings_by_dest = {}
        for dest_name, df in destinations_data.items():
            if df is None or df.empty:
                continue

            min_price = df['avg_price'].min()
            max_price = df['avg_price'].max()
            savings = max_price - min_price
            percentage = (savings / max_price * 100) if max_price > 0 else 0

            savings_by_dest[dest_name] = {
                'amount': round(savings, 2),
                'percentage': round(percentage, 2)
            }

        # Trouver la destination avec les meilleures économies potentielles
        if savings_by_dest:
            best_savings_dest = max(savings_by_dest.items(), key=lambda x: x[1]['percentage'])
            stats['best_savings'] = {
                'destination': best_savings_dest[0],
                **best_savings_dest[1]
            }

        # Créer une matrice de corrélation si nous avons plusieurs destinations
        if len(destinations_data) > 1:
            # Créer un DataFrame combiné avec les prix moyens mensuels
            combined_df = pd.DataFrame()

            for dest_name, df in destinations_data.items():
                if df is None or df.empty:
                    continue

                # Ajouter une colonne avec les prix moyens mensuels pour cette destination
                combined_df[dest_name] = df.sort_values('month')['avg_price'].values

            # Calculer la matrice de corrélation
            if not combined_df.empty and combined_df.shape[1] > 1:
                corr_matrix = combined_df.corr()

                # Convertir la matrice en dictionnaire
                for dest1 in corr_matrix.index:
                    stats['price_correlation'][dest1] = {}
                    for dest2 in corr_matrix.columns:
                        stats['price_correlation'][dest1][dest2] = round(corr_matrix.loc[dest1, dest2], 2)

        logger.info("Statistiques comparatives calculées avec succès")
        return stats

    except Exception as e:
        logger.error(f"Erreur lors du calcul des statistiques comparatives: {str(e)}")
        return {}

def calculate_month_recommendation(df):
    """
    Fournit des recommandations pour le meilleur mois pour voyager.

    Args:
        df: DataFrame pandas contenant les données mensuelles

    Returns:
        Dictionnaire contenant les recommandations
    """
    if df is None or df.empty:
        logger.warning("Aucune donnée pour calculer les recommandations")
        return {}

    try:
        # Calculer le prix moyen annuel et l'écart-type
        avg_price = df['avg_price'].mean()
        std_price = df['avg_price'].std()

        # Classer les mois par prix croissant
        df_sorted = df.sort_values('avg_price')

        recommendations = {
            'best_value': [],
            'balanced': [],
            'avoid': []
        }

        # Les mois à moins de 0.85 * moyenne sont considérés comme "best_value"
        for _, row in df_sorted[df_sorted['avg_price'] < 0.85 * avg_price].iterrows():
            recommendations['best_value'].append({
                'month': row['month_name'],
                'price': round(row['avg_price'], 2),
                'saving': round(avg_price - row['avg_price'], 2),
                'saving_percentage': round((avg_price - row['avg_price']) / avg_price * 100, 1),
                'season': row['season']
            })

        # Les mois entre 0.85 et 1.15 * moyenne sont considérés comme "balanced"
        for _, row in df_sorted[(df_sorted['avg_price'] >= 0.85 * avg_price) &
                                (df_sorted['avg_price'] <= 1.15 * avg_price)].iterrows():
            recommendations['balanced'].append({
                'month': row['month_name'],
                'price': round(row['avg_price'], 2),
                'diff_from_avg': round(row['avg_price'] - avg_price, 2),
                'diff_percentage': round((row['avg_price'] - avg_price) / avg_price * 100, 1),
                'season': row['season']
            })

        # Les mois à plus de 1.15 * moyenne sont considérés comme "avoid"
        for _, row in df_sorted[df_sorted['avg_price'] > 1.15 * avg_price].iterrows():
            recommendations['avoid'].append({
                'month': row['month_name'],
                'price': round(row['avg_price'], 2),
                'premium': round(row['avg_price'] - avg_price, 2),
                'premium_percentage': round((row['avg_price'] - avg_price) / avg_price * 100, 1),
                'season': row['season']
            })

        logger.info("Recommandations calculées avec succès")
        return recommendations

    except Exception as e:
        logger.error(f"Erreur lors du calcul des recommandations: {str(e)}")
        return {}
''',

    # Dashboard
    'dashboard/__init__.py': '# Configuration de l\'application dashboard\ndefault_app_config = \'dashboard.apps.DashboardConfig\'\n',

    'dashboard/models.py': '''from django.db import models
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
    potential_savings = models.FloatField(help_text="Économies potentielles entre le mois le plus cher et le moins cher")
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
''',

    'dashboard/views.py': '''import os
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

        context.update({
            'price_data': price_data,
            'analysis': analysis,
            'chart_data': json.dumps(chart_data),
            'season_data': json.dumps(season_data),
            'form': ScrapingForm(initial={'destination': destination.id}),
        })

        return context


@method_decorator(login_required, name='dispatch')
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


@login_required
def run_scraper_view(request):
    """Vue pour déclencher un scraping manuel."""
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

            # Lancer le scraping en arrière-plan (dans un cas réel, utiliser Celery)
            # Pour simplifier, nous l'exécutons de manière synchrone ici
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

            for data in price_data:
                dest_data['months'][data.month] = {
                    'name': data.month_name,
                    'avg_price': data.avg_price,
                    'is_cheapest': data.is_cheapest
                }
                months_data[data.month] = data.month_name

            comparison_data.append(dest_data)

        except Destination.DoesNotExist:
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
            if month in dest_data['months']:
                dataset['data'].append(dest_data['months'][month]['avg_price'])
            else:
                dataset['data'].append(None)

        chart_data['datasets'].append(dataset)

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
        PriceData.objects.create(
            destination=destination,
            year=year,
            month=row['month'],
            month_name=row['month_name'],
            avg_price=row['avg_price'],
            median_price=row['median_price'],
            min_price=row['min_price'],
            max_price=row['max_price'],
            sample_size=row['sample_size'],
            season=row['season'],
            relative_price=row['relative_price'],
            price_rank=row['price_rank'],
            is_cheapest=row['is_cheapest']
        )

    # Créer l'analyse
    if stats:
        analysis = AnalysisResult(
            destination=destination,
            year=year,
            cheapest_month=stats['cheapest_month']['name'],
            cheapest_month_price=stats['cheapest_month']['avg_price'],
            most_expensive_month=stats['most_expensive_month']['name'],
            most_expensive_month_price=stats['most_expensive_month']['avg_price'],
            potential_savings=stats['potential_savings'],
            savings_percentage=stats['savings_percentage'],
            coefficient_of_variation=stats['annual_variation']['coefficient_of_variation']
        )
        analysis.statistics = stats
        analysis.save()

    logger.info(f"Résultats enregistrés pour {destination.name}")
''',

    'dashboard/urls.py': '''from django.urls import path
from . import views

urlpatterns = [
    # Pages principales
    path('', views.HomeView.as_view(), name='home'),
    path('dashboard/', views.dashboard_view, name='dashboard'),
    path('comparison/', views.price_comparison_view, name='price_comparison'),

    # Gestion des destinations
    path('destinations/add/', views.AddDestinationView.as_view(), name='add_destination'),
    path('destinations/<slug:slug>/', views.DestinationDetailView.as_view(), name='destination_detail'),
    path('destinations/<slug:slug>/update-data/', views.update_data_view, name='update_data'),

    # Actions de scraping
    path('run-scraper/', views.run_scraper_view, name='run_scraper'),
]
''',

    'dashboard/admin.py': '''from django.contrib import admin
from .models import Destination, PriceData, AnalysisResult, ScrapingJob

@admin.register(Destination)
class DestinationAdmin(admin.ModelAdmin):
    list_display = ('name', 'last_scraping', 'status', 'created_at')
    list_filter = ('status',)
    search_fields = ('name',)
    prepopulated_fields = {'slug': ('name',)}

@admin.register(PriceData)
class PriceDataAdmin(admin.ModelAdmin):
    list_display = ('destination', 'month_name', 'year', 'avg_price', 'is_cheapest')
    list_filter = ('year', 'month', 'season', 'is_cheapest')
    search_fields = ('destination__name',)

@admin.register(AnalysisResult)
class AnalysisResultAdmin(admin.ModelAdmin):
    list_display = ('destination', 'year', 'cheapest_month', 'cheapest_month_price',
                    'most_expensive_month', 'potential_savings')
    list_filter = ('year',)
    search_fields = ('destination__name',)

@admin.register(ScrapingJob)
class ScrapingJobAdmin(admin.ModelAdmin):
    list_display = ('destination', 'status', 'scheduled_time', 'started_at', 'completed_at')
    list_filter = ('status',)
    search_fields = ('destination__name',)
    readonly_fields = ('created_at', 'updated_at')
''',

    'dashboard/apps.py': '''from django.apps import AppConfig

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
''',

    'dashboard/forms.py': '''from django import forms
from django.utils.text import slugify
from .models import Destination, ScrapingJob


class DestinationForm(forms.ModelForm):
    """
    Formulaire pour créer ou modifier une destination.
    """
    class Meta:
        model = Destination
        fields = ['name']
        widgets = {
            'name': forms.TextInput(attrs={
                'class': 'form-control',
                'placeholder': 'Ex: Paris,France'
            }),
        }

    def clean_name(self):
        """Vérifie que le nom de la destination est correctement formaté."""
        name = self.cleaned_data['name']

        # Vérifier qu'il y a au moins une ville et un pays
        if ',' not in name:
            raise forms.ValidationError(
                "Le format doit être 'Ville,Pays' (ex: Paris,France)"
            )

        return name

    def save(self, commit=True):
        """Génère automatiquement le slug à partir du nom."""
        instance = super().save(commit=False)
        instance.slug = slugify(instance.name)

        if commit:
            instance.save()

        return instance


class ScrapingForm(forms.Form):
    """
    Formulaire pour lancer un scraping manuel.
    """
    destination = forms.ModelChoiceField(
        queryset=Destination.objects.all(),
        widget=forms.HiddenInput()
    )


class ScheduleScrapingForm(forms.ModelForm):
    """
    Formulaire pour planifier un scraping.
    """
    class Meta:
        model = ScrapingJob
        fields = ['destination', 'scheduled_time']
        widgets = {
            'destination': forms.Select(attrs={'class': 'form-select'}),
            'scheduled_time': forms.DateTimeInput(
                attrs={
                    'class': 'form-control',
                    'type': 'datetime-local'
                },
                format='%Y-%m-%dT%H:%M'
            ),
        }


class DestinationFilterForm(forms.Form):
    """
    Formulaire pour filtrer les destinations.
    """
    search = forms.CharField(
        required=False,
        widget=forms.TextInput(attrs={
            'class': 'form-control',
            'placeholder': 'Rechercher une destination...'
        })
    )

    sort_by = forms.ChoiceField(
        required=False,
        choices=[
            ('name', 'Nom (A-Z)'),
            ('-name', 'Nom (Z-A)'),
            ('-last_scraping', 'Dernière mise à jour'),
            ('cheapest_price', 'Prix le plus bas'),
        ],
        widget=forms.Select(attrs={'class': 'form-select'})
    )
''',

    'dashboard/signals.py': '''"""
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
''',

    'dashboard/management/commands/run_scraper.py': '''import logging
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
                self.style.WARNING("Veuillez spécifier une destination (--destination) ou utiliser --all pour toutes les destinations")
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
''',

    'dashboard/management/__init__.py': '# Ce fichier est vide, simplement pour marquer le répertoire comme package Python\n',
    'dashboard/management/commands/__init__.py': '# Ce fichier est vide, simplement pour marquer le répertoire comme package Python\n',
    'dashboard/migrations/__init__.py': '# Ce fichier est vide, simplement pour marquer le répertoire comme package Python\n',

    # Templates
    'dashboard/templates/dashboard/base.html': '''{% load static %}
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{% block title %}Tableau de bord Airbnb Analytics{% endblock %}</title>

    <!-- Bootstrap CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/css/bootstrap.min.css" rel="stylesheet">
    <!-- Font Awesome -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <!-- Chart.js -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>

    <!-- Custom CSS -->
    <style>
        :root {
            --primary-color: #FF5A5F;
            --secondary-color: #00A699;
            --dark-color: #484848;
            --light-color: #F7F7F7;
        }

        body {
            font-family: 'Circular', -apple-system, BlinkMacSystemFont, Roboto, Helvetica Neue, sans-serif;
            background-color: var(--light-color);
            color: var(--dark-color);
        }

        .navbar {
            background-color: white;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        }

        .navbar-brand {
            color: var(--primary-color);
            font-weight: bold;
        }

        .nav-link {
            color: var(--dark-color);
        }

        .nav-link:hover, .nav-link.active {
            color: var(--primary-color);
        }

        .btn-primary {
            background-color: var(--primary-color);
            border-color: var(--primary-color);
        }

        .btn-primary:hover {
            background-color: #e44e53;
            border-color: #e44e53;
        }

        .btn-secondary {
            background-color: var(--secondary-color);
            border-color: var(--secondary-color);
        }

        .btn-secondary:hover {
            background-color: #009489;
            border-color: #009489;
        }

        .card {
            border-radius: 12px;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
            border: none;
            transition: transform 0.3s;
        }

        .card:hover {
            transform: translateY(-5px);
        }

        .stats-card {
            background-color: white;
            border-left: 4px solid var(--primary-color);
        }

        .chart-container {
            position: relative;
            margin: auto;
            height: 300px;
        }

        .cheapest-badge {
            background-color: var(--secondary-color);
            color: white;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.8em;
        }

        .expensive-badge {
            background-color: var(--primary-color);
            color: white;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.8em;
        }

        footer {
            background-color: var(--dark-color);
            color: white;
            padding: 20px 0;
            margin-top: 50px;
        }

        .destination-list {
            list-style: none;
            padding: 0;
        }

        .destination-list li {
            padding: 10px 15px;
            border-left: 3px solid transparent;
            transition: all 0.3s;
        }

        .destination-list li:hover {
            background-color: #f8f9fa;
            border-left: 3px solid var(--primary-color);
        }

        .destination-list a {
            color: var(--dark-color);
            text-decoration: none;
        }

        .page-header {
            background-color: white;
            padding: 20px;
            margin-bottom: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .loading-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(255, 255, 255, 0.8);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 9999;
            visibility: hidden;
            opacity: 0;
            transition: visibility 0s, opacity 0.3s;
        }

        .loading-overlay.active {
            visibility: visible;
            opacity: 1;
        }

        .spinner {
            width: 50px;
            height: 50px;
            border: 5px solid #f3f3f3;
            border-top: 5px solid var(--primary-color);
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }

        .season-spring { color: #4CAF50; }
        .season-summer { color: #FF9800; }
        .season-autumn { color: #795548; }
        .season-winter { color: #2196F3; }

        .tooltip-inner {
            max-width: 200px;
            padding: 10px;
            background-color: var(--dark-color);
        }
    </style>

    {% block extra_css %}{% endblock %}
</head>
<body>
    <!-- Loading Overlay -->
    <div class="loading-overlay" id="loadingOverlay">
        <div class="spinner"></div>
    </div>

    <!-- Navigation -->
    <nav class="navbar navbar-expand-lg navbar-light sticky-top">
        <div class="container">
            <a class="navbar-brand" href="{% url 'home' %}">
                <i class="fa-solid fa-umbrella-beach me-2"></i>
                Airbnb Analytics
            </a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link {% if request.resolver_match.url_name == 'home' %}active{% endif %}" href="{% url 'home' %}">
                            <i class="fa-solid fa-house me-1"></i> Accueil
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link {% if request.resolver_match.url_name == 'dashboard' %}active{% endif %}" href="{% url 'dashboard' %}">
                            <i class="fa-solid fa-chart-line me-1"></i> Tableau de bord
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link {% if request.resolver_match.url_name == 'price_comparison' %}active{% endif %}" href="{% url 'price_comparison' %}">
                            <i class="fa-solid fa-scale-balanced me-1"></i> Comparaison de prix
                        </a>
                    </li>
                </ul>
                <div class="d-flex">
                    <a href="{% url 'add_destination' %}" class="btn btn-sm btn-primary">
                        <i class="fa-solid fa-plus me-1"></i> Nouvelle destination
                    </a>
                </div>
            </div>
        </div>
    </nav>

    <!-- Messages -->
    {% if messages %}
    <div class="container mt-3">
        {% for message in messages %}
        <div class="alert alert-{{ message.tags }} alert-dismissible fade show" role="alert">
            {{ message }}
            <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
        </div>
        {% endfor %}
    </div>
    {% endif %}

    <!-- Main Content -->
    <main class="container py-4">
        {% block content %}{% endblock %}
    </main>

    <!-- Footer -->
    <footer>
        <div class="container">
            <div class="row">
                <div class="col-md-6">
                    <h5>Airbnb Analytics</h5>
                    <p>Un outil pour analyser les prix des logements Airbnb tout au long de l'année et trouver le meilleur moment pour voyager.</p>
                </div>
                <div class="col-md-3">
                    <h5>Liens utiles</h5>
                    <ul class="list-unstyled">
                        <li><a href="{% url 'home' %}" class="text-white">Accueil</a></li>
                        <li><a href="{% url 'dashboard' %}" class="text-white">Tableau de bord</a></li>
                        <li><a href="{% url 'price_comparison' %}" class="text-white">Comparaison de prix</a></li>
                    </ul>
                </div>
                <div class="col-md-3">
                    <h5>Contact</h5>
                    <p>
                        <i class="fa-solid fa-envelope me-2"></i> contact@airbnbanalytics.fr<br>
                        <i class="fa-solid fa-code me-2"></i> v1.0.0
                    </p>
                </div>
            </div>
            <hr class="bg-white">
            <div class="text-center">
                <p>&copy; 2025 Airbnb Analytics. Tous droits réservés.</p>
            </div>
        </div>
    </footer>

    <!-- Bootstrap JS Bundle -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0-alpha1/dist/js/bootstrap.bundle.min.js"></script>

    <!-- Common JS -->
    <script>
        // Initialize tooltips
        const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
        const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl));

        // Loading overlay functions
        function showLoading() {
            document.getElementById('loadingOverlay').classList.add('active');
        }

        function hideLoading() {
            document.getElementById('loadingOverlay').classList.remove('active');
        }

        // Handle scraping form submission
        document.addEventListener('DOMContentLoaded', function() {
            const scrapingForms = document.querySelectorAll('.scraping-form');

            scrapingForms.forEach(form => {
                form.addEventListener('submit', function(e) {
                    showLoading();
                });
            });
        });
    </script>

    {% block extra_js %}{% endblock %}
</body>
</html>
''',

    'dashboard/templates/dashboard/home.html': '''{% extends 'dashboard/base.html' %}

{% block title %}Accueil - Airbnb Analytics{% endblock %}

{% block content %}
<div class="page-header">
    <h1><i class="fa-solid fa-house me-2"></i> Airbnb Analytics</h1>
</div>

<!-- Introduction -->
<div class="row mb-4">
    <div class="col-md-8">
        <div class="card h-100">
            <div class="card-body">
                <h2>Trouvez le meilleur moment pour voyager</h2>
                <p class="lead">
                    Airbnb Analytics vous aide à analyser les prix des logements Airbnb tout au long de l'année pour différentes destinations.
                </p>
                <p>
                    Notre outil collecte et analyse les données de prix pour vous aider à planifier votre voyage au moment le plus économique de l'année.
                    Vous pouvez comparer les prix entre les différents mois, analyser les tendances saisonnières et faire des économies substantielles.
                </p>
                <div class="mt-4">
                    <a href="{% url 'dashboard' %}" class="btn btn-primary">
                        <i class="fa-solid fa-chart-line me-1"></i> Voir le tableau de bord
                    </a>
                    <a href="{% url 'add_destination' %}" class="btn btn-outline-secondary ms-2">
                        <i class="fa-solid fa-plus me-1"></i> Ajouter une destination
                    </a>
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card h-100">
            <div class="card-header bg-white">
                <h5 class="mb-0">Statistiques</h5>
            </div>
            <div class="card-body">
                <div class="d-flex align-items-center mb-3">
                    <div class="display-3 me-3">{{ destination_count }}</div>
                    <div>
                        <h5 class="mb-0">Destinations</h5>
                        <p class="text-muted mb-0">analysées</p>
                    </div>
                </div>

                {% if cheapest_months %}
                <h6 class="mt-4">Mois les moins chers</h6>
                <ul class="list-group">
                    {% for dest, data in cheapest_months.items %}
                    <li class="list-group-item d-flex justify-content-between align-items-center">
                        {{ dest }}
                        <span class="cheapest-badge">{{ data.month }} ({{ data.price|floatformat:0 }}€)</span>
                    </li>
                    {% endfor %}
                </ul>
                {% endif %}
            </div>
        </div>
    </div>
</div>

<!-- Destinations -->
<div class="row mb-4">
    <div class="col-md-6">
        <div class="card h-100">
            <div class="card-header bg-white">
                <h5 class="mb-0">Destinations disponibles</h5>
            </div>
            <div class="card-body">
                {% if destinations %}
                <ul class="destination-list">
                    {% for dest in destinations %}
                    <li>
                        <a href="{% url 'destination_detail' slug=dest.slug %}">
                            <i class="fa-solid fa-location-dot me-1"></i> {{ dest.name }}

                            {% if dest.status == 'completed' %}
                            <span class="badge bg-success float-end">Données disponibles</span>
                            {% elif dest.status == 'running' %}
                            <span class="badge bg-warning float-end">Scraping en cours</span>
                            {% elif dest.status == 'failed' %}
                            <span class="badge bg-danger float-end">Échec</span>
                            {% else %}
                            <span class="badge bg-secondary float-end">Pas de données</span>
                            {% endif %}
                        </a>
                    </li>
                    {% endfor %}
                </ul>
                {% else %}
                <div class="text-center py-4">
                    <i class="fa-solid fa-map-location-dot fa-3x mb-3 text-muted"></i>
                    <p>Aucune destination n'a encore été ajoutée.</p>
                    <a href="{% url 'add_destination' %}" class="btn btn-primary">
                        <i class="fa-solid fa-plus me-1"></i> Ajouter une destination
                    </a>
                </div>
                {% endif %}
            </div>
            <div class="card-footer bg-white">
                <a href="{% url 'add_destination' %}" class="btn btn-sm btn-outline-primary">
                    <i class="fa-solid fa-plus me-1"></i> Ajouter une destination
                </a>
            </div>
        </div>
    </div>

    <div class="col-md-6">
        <div class="card h-100">
            <div class="card-header bg-white">
                <h5 class="mb-0">Mises à jour récentes</h5>
            </div>
            <div class="card-body">
                {% if recent_updates %}
                <div class="list-group">
                    {% for dest in recent_updates %}
                    <a href="{% url 'destination_detail' slug=dest.slug %}" class="list-group-item list-group-item-action">
                        <div class="d-flex w-100 justify-content-between">
                            <h6 class="mb-1">{{ dest.name }}</h6>
                            <small>{{ dest.last_scraping|date:"d/m/Y H:i" }}</small>
                        </div>
                        <p class="mb-1 text-muted">
                            Dernière mise à jour des données
                        </p>
                    </a>
                    {% endfor %}
                </div>
                {% else %}
                <div class="text-center py-4">
                    <i class="fa-solid fa-clock-rotate-left fa-3x mb-3 text-muted"></i>
                    <p>Aucune mise à jour récente.</p>
                </div>
                {% endif %}
            </div>
        </div>
    </div>
</div>

<!-- Comment ça marche -->
<div class="row mb-4">
    <div class="col-12">
        <div class="card">
            <div class="card-header bg-white">
                <h5 class="mb-0">Comment ça marche</h5>
            </div>
            <div class="card-body">
                <div class="row">
                    <div class="col-md-4 text-center mb-4">
                        <div class="display-5 mb-3">
                            <i class="fa-solid fa-magnifying-glass text-primary"></i>
                        </div>
                        <h5>1. Ajoutez une destination</h5>
                        <p>
                            Entrez le nom d'une ville ou d'une région que vous souhaitez analyser.
                            Notre système collectera les données de prix Airbnb pour cette destination.
                        </p>
                    </div>
                    <div class="col-md-4 text-center mb-4">
                        <div class="display-5 mb-3">
                            <i class="fa-solid fa-chart-column text-primary"></i>
                        </div>
                        <h5>2. Explorez les analyses</h5>
                        <p>
                            Consultez les graphiques et statistiques détaillées montrant l'évolution des prix tout au long de l'année.
                            Identifiez les mois les moins chers pour votre voyage.
                        </p>
                    </div>
                    <div class="col-md-4 text-center mb-4">
                        <div class="display-5 mb-3">
                            <i class="fa-solid fa-piggy-bank text-primary"></i>
                        </div>
                        <h5>3. Économisez sur votre réservation</h5>
                        <p>
                            Réservez votre séjour pendant la période la plus économique et réalisez des économies substantielles
                            par rapport aux mois les plus chers.
                        </p>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>
{% endblock %}
''',

    'dashboard/templates/dashboard/add_destination.html': '''{% extends 'dashboard/base.html' %}
{% load crispy_forms_tags %}

{% block title %}Ajouter une destination - Airbnb Analytics{% endblock %}

{% block content %}
<div class="page-header">
    <h1><i class="fa-solid fa-plus me-2"></i> Ajouter une destination</h1>
</div>

<div class="row">
    <div class="col-md-6">
        <div class="card">
            <div class="card-header bg-white">
                <h5 class="mb-0">Nouvelle destination</h5>
            </div>
            <div class="card-body">
                <form method="post">
                    {% csrf_token %}
                    {{ form|crispy }}
                    <div class="alert alert-info">
                        <i class="fa-solid fa-info-circle me-2"></i> Entrez le nom de la destination au format "Ville,Pays" (ex: Paris,France).
                    </div>
                    <button type="submit" class="btn btn-primary">
                        <i class="fa-solid fa-save me-1"></i> Enregistrer
                    </button>
                    <a href="{% url 'home' %}" class="btn btn-outline-secondary">
                        <i class="fa-solid fa-times me-1"></i> Annuler
                    </a>
                </form>
            </div>
        </div>
    </div>

    <div class="col-md-6">
        <div class="card">
            <div class="card-header bg-white">
                <h5 class="mb-0">Informations</h5>
            </div>
            <div class="card-body">
                <h6>Comment ça fonctionne ?</h6>
                <p>
                    Lorsque vous ajoutez une nouvelle destination, vous devrez ensuite lancer manuellement
                    une première collecte de données pour cette destination.
                </p>

                <h6>Exemples de destinations</h6>
                <ul>
                    <li>Paris,France</li>
                    <li>Londres,Royaume-Uni</li>
                    <li>Barcelone,Espagne</li>
                    <li>New York,États-Unis</li>
                    <li>Tokyo,Japon</li>
                </ul>

                <h6>Après l'ajout</h6>
                <p>
                    Une fois la destination ajoutée, vous serez redirigé vers sa page détaillée où vous pourrez
                    lancer le scraping en cliquant sur le bouton "Mettre à jour les données".
                </p>
                <p>
                    La collecte des données peut prendre plusieurs minutes. Vous pouvez quitter la page et revenir
                    plus tard pour consulter les résultats.
                </p>
            </div>
        </div>
    </div>
</div>
{% endblock %}
''',

    'dashboard/templates/dashboard/dashboard.html': '''{% extends 'dashboard/base.html' %}

{% block title %}Tableau de bord - Airbnb Analytics{% endblock %}

{% block content %}
<div class="page-header">
    <h1><i class="fa-solid fa-chart-line me-2"></i> Tableau de bord</h1>
</div>

<!-- Statistiques générales -->
<div class="row mb-4">
    <div class="col-md-3">
        <div class="card stats-card h-100">
            <div class="card-body">
                <h5 class="card-title text-muted">Destinations</h5>
                <div class="d-flex align-items-center">
                    <div class="display-4 me-3">{{ stats.destination_count }}</div>
                    <div>
                        <span class="text-muted">destinations analysées</span>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="card stats-card h-100">
            <div class="card-body">
                <h5 class="card-title text-muted">Économies moyennes</h5>
                <div class="d-flex align-items-center">
                    <div class="display-4 me-3">{{ stats.avg_savings }}%</div>
                    <div>
                        <span class="text-muted">en choisissant le bon mois</span>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="card stats-card h-100">
            <div class="card-body">
                <h5 class="card-title text-muted">Variation annuelle</h5>
                <div class="d-flex align-items-center">
                    <div class="display-4 me-3">{{ stats.avg_variation }}%</div>
                    <div>
                        <span class="text-muted">coefficient de variation moyen</span>
                    </div>
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-3">
        <div class="card stats-card h-100">
            <div class="card-body">
                <h5 class="card-title text-muted">Saison la moins chère</h5>
                <div class="d-flex align-items-center">
                    {% with max_season=stats.cheapest_seasons.items|dictsort:1|last %}
                    <div class="display-4 me-3">
                        {% if max_season.0 == 'Hiver' %}
                            <i class="fa-solid fa-snowflake season-winter"></i>
                        {% elif max_season.0 == 'Printemps' %}
                            <i class="fa-solid fa-seedling season-spring"></i>
                        {% elif max_season.0 == 'Été' %}
                            <i class="fa-solid fa-sun season-summer"></i>
                        {% elif max_season.0 == 'Automne' %}
                            <i class="fa-solid fa-leaf season-autumn"></i>
                        {% endif %}
                    </div>
                    <div>
                        <span class="fs-3">{{ max_season.0 }}</span><br>
                        <span class="text-muted">pour {{ max_season.1 }} destinations</span>
                    </div>
                    {% endwith %}
                </div>
            </div>
        </div>
    </div>
</div>

<div class="row mb-4">
    <!-- Prix moyens par destination -->
    <div class="col-md-8">
        <div class="card h-100">
            <div class="card-header bg-white">
                <h5 class="mb-0">Prix par destination</h5>
            </div>
            <div class="card-body">
                <div class="chart-container">
                    <canvas id="destinationPricesChart"></canvas>
                </div>
            </div>
        </div>
    </div>

    <!-- Prix moyens par saison -->
    <div class="col-md-4">
        <div class="card h-100">
            <div class="card-header bg-white">
                <h5 class="mb-0">Prix moyens par saison</h5>
            </div>
            <div class="card-body">
                <div class="chart-container">
                    <canvas id="seasonPricesChart"></canvas>
                </div>
            </div>
        </div>
    </div>
</div>

<div class="row mb-4">
    <!-- Économies potentielles -->
    <div class="col-md-6">
        <div class="card h-100">
            <div class="card-header bg-white">
                <h5 class="mb-0">Économies potentielles</h5>
            </div>
            <div class="card-body">
                <div class="chart-container">
                    <canvas id="savingsChart"></canvas>
                </div>
            </div>
        </div>
    </div>

    <!-- Destinations -->
    <div class="col-md-6">
        <div class="card h-100">
            <div class="card-header bg-white">
                <h5 class="mb-0">Destinations analysées</h5>
            </div>
            <div class="card-body">
                {% if destinations %}
                <div class="table-responsive">
                    <table class="table table-hover">
                        <thead>
                            <tr>
                                <th>Destination</th>
                                <th>Mois le moins cher</th>
                                <th>Dernier scraping</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% for dest in destinations %}
                            <tr>
                                <td>
                                    <a href="{% url 'destination_detail' slug=dest.slug %}">
                                        {{ dest.name }}
                                    </a>
                                </td>
                                <td>
                                    {% for result in dest.analysis_results.all %}
                                    {% if forloop.first %}
                                    <span class="cheapest-badge">{{ result.cheapest_month }}</span>
                                    {% endif %}
                                    {% empty %}
                                    <span class="text-muted">Non disponible</span>
                                    {% endfor %}
                                </td>
                                <td>
                                    {% if dest.last_scraping %}
                                    {{ dest.last_scraping|date:"d/m/Y H:i" }}
                                    {% else %}
                                    <span class="text-muted">Jamais</span>
                                    {% endif %}
                                </td>
                                <td>
                                    <a href="{% url 'destination_detail' slug=dest.slug %}" class="btn btn-sm btn-outline-primary">
                                        <i class="fa-solid fa-eye"></i>
                                    </a>
                                </td>
                            </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
                {% else %}
                <div class="text-center py-5">
                    <i class="fa-solid fa-map-location-dot fa-3x mb-3 text-muted"></i>
                    <p>Aucune destination n'a encore été analysée.</p>
                    <a href="{% url 'add_destination' %}" class="btn btn-primary">
                        <i class="fa-solid fa-plus me-1"></i> Ajouter une destination
                    </a>
                </div>
                {% endif %}
            </div>
        </div>
    </div>
</div>
{% endblock %}

{% block extra_js %}
<script>
    // Données pour les graphiques
    const destinationPrices = {{ destination_prices|safe }};
    const seasonData = {{ season_data|safe }};
    const savingsData = {{ savings_data|safe }};

    // Couleurs pour les saisons
    const seasonColors = {
        'Hiver': '#2196F3',
        'Printemps': '#4CAF50',
        'Été': '#FF9800',
        'Automne': '#795548'
    };

    document.addEventListener('DOMContentLoaded', function() {
        // Graphique des prix par destination
        if (destinationPrices.length > 0) {
            const destLabels = destinationPrices.map(item => item.name);
            const avgPrices = destinationPrices.map(item => item.avg_price);
            const minPrices = destinationPrices.map(item => item.min_price);
            const maxPrices = destinationPrices.map(item => item.max_price);

            const destChart = new Chart(
                document.getElementById('destinationPricesChart'),
                {
                    type: 'bar',
                    data: {
                        labels: destLabels,
                        datasets: [
                            {
                                label: 'Prix moyen',
                                data: avgPrices,
                                backgroundColor: '#36A2EB',
                                borderColor: '#36A2EB',
                                borderWidth: 1
                            },
                            {
                                label: 'Prix minimum',
                                data: minPrices,
                                backgroundColor: '#4BC0C0',
                                borderColor: '#4BC0C0',
                                borderWidth: 1
                            },
                            {
                                label: 'Prix maximum',
                                data: maxPrices,
                                backgroundColor: '#FF6384',
                                borderColor: '#FF6384',
                                borderWidth: 1
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        scales: {
                            y: {
                                beginAtZero: true,
                                title: {
                                    display: true,
                                    text: 'Prix (€)'
                                }
                            }
                        }
                    }
                }
            );
        }

        // Graphique des prix par saison
        const seasonLabels = Object.keys(seasonData);
        const seasonValues = [];
        const seasonBgColors = [];

        for (const season of seasonLabels) {
            // Calculer la moyenne pour chaque saison
            const prices = seasonData[season];
            const avgPrice = prices.length > 0
                ? prices.reduce((sum, price) => sum + price, 0) / prices.length
                : 0;

            seasonValues.push(avgPrice);
            seasonBgColors.push(seasonColors[season]);
        }

        const seasonChart = new Chart(
            document.getElementById('seasonPricesChart'),
            {
                type: 'doughnut',
                data: {
                    labels: seasonLabels,
                    datasets: [
                        {
                            data: seasonValues,
                            backgroundColor: seasonBgColors,
                            borderColor: 'white',
                            borderWidth: 2
                        }
                    ]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            position: 'bottom'
                        },
                        tooltip: {
                            callbacks: {
                                label: function(context) {
                                    const value = context.raw;
                                    return `${context.label}: ${value.toFixed(2)}€`;
                                }
                            }
                        }
                    }
                }
            }
        );

        // Graphique des économies potentielles
        if (savingsData.length > 0) {
            const savingsLabels = savingsData.map(item => item.name);
            const savingsValues = savingsData.map(item => item.savings);
            const savingsPercentages = savingsData.map(item => item.percentage);

            const savingsChart = new Chart(
                document.getElementById('savingsChart'),
                {
                    type: 'bar',
                    data: {
                        labels: savingsLabels,
                        datasets: [
                            {
                                label: 'Économie (€)',
                                data: savingsValues,
                                backgroundColor: '#FF9F40',
                                yAxisID: 'y',
                                order: 1
                            },
                            {
                                label: 'Économie (%)',
                                data: savingsPercentages,
                                backgroundColor: '#FF6384',
                                borderColor: '#FF6384',
                                type: 'line',
                                yAxisID: 'y1',
                                order: 0
                            }
                        ]
                    },
                    options: {
                        responsive: true,
                        maintainAspectRatio: false,
                        scales: {
                            y: {
                                beginAtZero: true,
                                position: 'left',
                                title: {
                                    display: true,
                                    text: 'Économie (€)'
                                }
                            },
                            y1: {
                                beginAtZero: true,
                                position: 'right',
                                title: {
                                    display: true,
                                    text: 'Économie (%)'
                                },
                                grid: {
                                    drawOnChartArea: false
                                }
                            }
                        }
                    }
                }
            );
        }
    });
</script>
{% endblock %}
''',

    'dashboard/templates/dashboard/destination_detail.html': '''{% extends 'dashboard/base.html' %}

{% block title %}{{ destination.name }} - Airbnb Analytics{% endblock %}

{% block content %}
<div class="page-header">
    <div>
        <h1>{{ destination.name }}</h1>
        <p class="text-muted">
            {% if destination.last_scraping %}
            <i class="fa-solid fa-calendar-check me-1"></i> Dernière mise à jour: {{ destination.last_scraping|date:"d/m/Y H:i" }}
            {% else %}
            <i class="fa-solid fa-calendar-xmark me-1"></i> Jamais mis à jour
            {% endif %}
        </p>
    </div>
    <div>
        <form class="scraping-form" method="post" action="{% url 'run_scraper' %}">
            {% csrf_token %}
            {{ form.destination }}
            <button type="submit" class="btn btn-primary">
                <i class="fa-solid fa-sync me-1"></i> Mettre à jour les données
            </button>
        </form>
    </div>
</div>

{% if not price_data %}
<div class="alert alert-info">
    <i class="fa-solid fa-info-circle me-2"></i> Aucune donnée disponible pour cette destination. Veuillez lancer une mise à jour des données.
</div>
{% else %}

<!-- Carte principale des statistiques -->
<div class="row mb-4">
    <div class="col-md-8">
        <div class="card">
            <div class="card-header bg-white">
                <h5 class="mb-0">Prix moyens mensuels pour {{ destination.name }}</h5>
            </div>
            <div class="card-body">
                <div class="chart-container">
                    <canvas id="priceChart"></canvas>
                </div>
            </div>
        </div>
    </div>

    <div class="col-md-4">
        <div class="card mb-4">
            <div class="card-header bg-white">
                <h5 class="mb-0">Mois le moins cher</h5>
            </div>
            <div class="card-body">
                <div class="d-flex align-items-center">
                    <div class="display-1 me-3 text-success">
                        <i class="fa-solid fa-piggy-bank"></i>
                    </div>
                    <div>
                        <h3>{{ analysis.cheapest_month }}</h3>
                        <h4 class="text-success">{{ analysis.cheapest_month_price }} €</h4>
                        <p class="mb-0 text-muted">
                            {% if analysis.season_analysis %}
                            <i class="fa-solid
                                {% if analysis.statistics.cheapest_month.season == 'Hiver' %}
                                fa-snowflake season-winter
                                {% elif analysis.statistics.cheapest_month.season == 'Printemps' %}
                                fa-seedling season-spring
                                {% elif analysis.statistics.cheapest_month.season == 'Été' %}
                                fa-sun season-summer
                                {% elif analysis.statistics.cheapest_month.season == 'Automne' %}
                                fa-leaf season-autumn
                                {% endif %}
                                me-1"></i>
                            Saison: {{ analysis.statistics.cheapest_month.season }}
                            {% endif %}
                        </p>
                    </div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-header bg-white">
                <h5 class="mb-0">Économies potentielles</h5>
            </div>
            <div class="card-body">
                <div class="d-flex align-items-center mb-3">
                    <div class="display-4 me-3 text-danger">{{ analysis.most_expensive_month_price }} €</div>
                    <div>
                        <h5 class="mb-0">{{ analysis.most_expensive_month }}</h5>
                        <p class="text-muted mb-0">Mois le plus cher</p>
                    </div>
                </div>

                <div class="text-center my-3">
                    <i class="fa-solid fa-arrow-down fa-2x"></i>
                </div>

                <div class="d-flex align-items-center">
                    <div class="display-4 me-3 text-success">{{ analysis.potential_savings }} €</div>
                    <div>
                        <h5 class="mb-0">{{ analysis.savings_percentage }}%</h5>
                        <p class="text-muted mb-0">d'économies potentielles</p>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Autres statistiques -->
<div class="row mb-4">
    <div class="col-md-4">
        <div class="card h-100">
            <div class="card-header bg-white">
                <h5 class="mb-0">Prix par saison</h5>
            </div>
            <div class="card-body">
                <div class="chart-container">
                    <canvas id="seasonChart"></canvas>
                </div>
            </div>
        </div>
    </div>

    <div class="col-md-8">
        <div class="card h-100">
            <div class="card-header bg-white">
                <h5 class="mb-0">Classement des mois</h5>
            </div>
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped">
                        <thead>
                            <tr>
                                <th>Rang</th>
                                <th>Mois</th>
                                <th>Prix moyen</th>
                                <th>Saison</th>
                                <th>Diff. avec min</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% for month in analysis.price_ranking %}
                            <tr {% if forloop.first %}class="table-success"{% endif %} {% if forloop.last %}class="table-danger"{% endif %}>
                                <td>{{ forloop.counter }}</td>
                                <td>{{ month.month }}</td>
                                <td>{{ month.price }} €</td>
                                <td>
                                    <span class="
                                        {% if month.season == 'Hiver' %}text-primary
                                        {% elif month.season == 'Printemps' %}text-success
                                        {% elif month.season == 'Été' %}text-warning
                                        {% elif month.season == 'Automne' %}text-brown
                                        {% endif %}
                                    ">
                                        {{ month.season }}
                                    </span>
                                </td>
                                <td>
                                    {% if forloop.first %}
                                    -
                                    {% else %}
                                    +{{ month.price|floatformat:2|cut:"-"|add:"-"|add:analysis.price_ranking.0.price|floatformat:2 }} €
                                    ({{ month.price|floatformat:2|cut:"-"|add:"-"|add:analysis.price_ranking.0.price|floatformat:2|cut:"-"|add:"-"|div:analysis.price_ranking.0.price|mul:100|floatformat:1 }}%)
                                    {% endif %}
                                </td>
                            </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Données détaillées -->
<div class="row mb-4">
    <div class="col-12">
        <div class="card">
            <div class="card-header bg-white">
                <h5 class="mb-0">Données détaillées</h5>
            </div>
            <div class="card-body">
                <div class="table-responsive">
                    <table class="table table-striped table-hover">
                        <thead>
                            <tr>
                                <th>Mois</th>
                                <th>Prix moyen</th>
                                <th>Prix médian</th>
                                <th>Prix min</th>
                                <th>Prix max</th>
                                <th>Échantillon</th>
                                <th>Saison</th>
                                <th>Prix relatif</th>
                            </tr>
                        </thead>
                        <tbody>
                            {% for data in price_data %}
                            <tr {% if data.is_cheapest %}class="table-success"{% endif %}>
                                <td>{{ data.month_name }}</td>
                                <td>{{ data.avg_price|floatformat:2 }} €</td>
                                <td>{{ data.median_price|floatformat:2 }} €</td>
                                <td>{{ data.min_price|floatformat:2 }} €</td>
                                <td>{{ data.max_price|floatformat:2 }} €</td>
                                <td>{{ data.sample_size }}</td>
                                <td>{{ data.season }}</td>
                                <td>{{ data.relative_price|floatformat:2 }}</td>
                            </tr>
                            {% endfor %}
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>
{% endif %}
{% endblock %}

{% block extra_js %}
{% if price_data %}
<script>
    // Données pour les graphiques
    const chartData = {{ chart_data|safe }};
    const seasonData = {{ season_data|safe }};

    // Couleurs pour les saisons
    const seasonColors = {
        'Hiver': '#2196F3',
        'Printemps': '#4CAF50',
        'Été': '#FF9800',
        'Automne': '#795548'
    };

    document.addEventListener('DOMContentLoaded', function() {
        // Graphique principal des prix
        const priceCtx = document.getElementById('priceChart').getContext('2d');
        const priceChart = new Chart(priceCtx, {
            type: 'bar',
            data: {
                labels: chartData.months,
                datasets: [
                    {
                        label: 'Prix moyen',
                        data: chartData.avg_prices,
                        backgroundColor: '#FF5A5F',
                        borderColor: '#FF5A5F',
                        borderWidth: 1,
                        order: 1
                    },
                    {
                        label: 'Prix médian',
                        data: chartData.median_prices,
                        backgroundColor: '#00A699',
                        borderColor: '#00A699',
                        borderWidth: 1,
                        order: 2
                    },
                    {
                        label: 'Fourchette de prix',
                        data: chartData.min_prices,
                        backgroundColor: 'rgba(0, 0, 0, 0)',
                        borderColor: 'rgba(0, 0, 0, 0)',
                        type: 'line',
                        order: 0,
                        pointStyle: false
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Prix (€)'
                        }
                    }
                },
                plugins: {
                    tooltip: {
                        callbacks: {
                            afterLabel: function(context) {
                                const dataIndex = context.dataIndex;
                                const min = chartData.min_prices[dataIndex];
                                const max = chartData.max_prices[dataIndex];
                                return `Min: ${min}€ - Max: ${max}€`;
                            }
                        }
                    }
                }
            }
        });

        // Graphique des saisons
        const seasonCtx = document.getElementById('seasonChart').getContext('2d');
        const seasonLabels = Object.keys(seasonData);
        const seasonValues = Object.values(seasonData);
        const seasonBgColors = seasonLabels.map(season => seasonColors[season]);

        const seasonChart = new Chart(seasonCtx, {
            type: 'pie',
            data: {
                labels: seasonLabels,
                datasets: [{
                    data: seasonValues,
                    backgroundColor: seasonBgColors,
                    borderWidth: 1,
                    borderColor: '#fff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom'
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const value = context.raw;
                                return `${context.label}: ${value.toFixed(2)}€`;
                            }
                        }
                    }
                }
            }
        });
    });
</script>
{% endif %}
{% endblock %}
''',

    'dashboard/templates/dashboard/price_comparison.html': '''{% extends 'dashboard/base.html' %}

{% block title %}Comparaison des prix - Airbnb Analytics{% endblock %}

{% block content %}
<div class="page-header">
    <h1><i class="fa-solid fa-scale-balanced me-2"></i> Comparaison des prix</h1>
</div>

<!-- Filtres -->
<div class="card mb-4">
    <div class="card-body">
        <form method="get" id="comparisonForm">
            <div class="row">
                <div class="col-md-6">
                    <label for="destinations" class="form-label">Destinations</label>
                    <select name="destinations" id="destinations" class="form-select" multiple size="5">
                        {% for dest in destinations %}
                        <option value="{{ dest.id }}" {% if dest.id in selected_destinations %}selected{% endif %}>
                            {{ dest.name }}
                        </option>
                        {% endfor %}
                    </select>
                    <div class="form-text">Maintenez Ctrl (ou Cmd) pour sélectionner plusieurs destinations</div>
                </div>
                <div class="col-md-4">
                    <label for="month" class="form-label">Mois spécifique (optionnel)</label>
                    <select name="month" id="month" class="form-select">
                        <option value="">Tous les mois</option>
                        {% for month_id, month_name in months %}
                        <option value="{{ month_id }}" {% if selected_month == month_id|stringformat:"i" %}selected{% endif %}>
                            {{ month_name }}
                        </option>
                        {% endfor %}
                    </select>
                </div>
                <div class="col-md-2 d-flex align-items-end">
                    <button type="submit" class="btn btn-primary w-100">
                        <i class="fa-solid fa-filter me-1"></i> Appliquer
                    </button>
                </div>
            </div>
        </form>
    </div>
</div>

{% if comparison_data %}
<!-- Graphique de comparaison -->
<div class="card mb-4">
    <div class="card-header bg-white">
        <h5 class="mb-0">Comparaison des prix mensuels</h5>
    </div>
    <div class="card-body">
        <div class="chart-container" style="height: 400px;">
            <canvas id="comparisonChart"></canvas>
        </div>
    </div>
</div>

<!-- Tableau de comparaison -->
<div class="card">
    <div class="card-header bg-white">
        <h5 class="mb-0">Tableau comparatif des prix</h5>
    </div>
    <div class="card-body">
        {% if selected_month %}
        <!-- Affichage pour un mois spécifique -->
        <div class="table-responsive">
            <table class="table table-striped">
                <thead>
                    <tr>
                        <th>Destination</th>
                        <th>Prix moyen</th>
                        <th>Est le moins cher</th>
                    </tr>
                </thead>
                <tbody>
                    {% for dest in comparison_data %}
                    <tr>
                        <td>{{ dest.name }}</td>
                        <td>
                            {% for month_id, month_data in dest.months.items %}
                            {% if month_id|stringformat:"i" == selected_month %}
                            {{ month_data.avg_price|floatformat:2 }} €
                            {% endif %}
                            {% endfor %}
                        </td>
                        <td>
                            {% for month_id, month_data in dest.months.items %}
                            {% if month_id|stringformat:"i" == selected_month and month_data.is_cheapest %}
                            <span class="badge bg-success"><i class="fa-solid fa-check me-1"></i> Oui</span>
                            {% endif %}
                            {% endfor %}
                        </td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
        {% else %}
        <!-- Affichage pour tous les mois -->
        <div class="table-responsive">
            <table class="table table-striped">
                <thead>
                    <tr>
                        <th>Mois</th>
                        {% for dest in comparison_data %}
                        <th>{{ dest.name }}</th>
                        {% endfor %}
                        <th>Différence max</th>
                    </tr>
                </thead>
                <tbody>
                    {% for month_id, month_name in months %}
                    <tr>
                        <td>{{ month_name }}</td>
                        {% for dest in comparison_data %}
                        <td {% if dest.months|get_item:month_id|get_item:'is_cheapest' %}class="table-success"{% endif %}>
                            {% if dest.months|get_item:month_id %}
                            {{ dest.months|get_item:month_id|get_item:'avg_price'|floatformat:2 }} €
                            {% else %}
                            -
                            {% endif %}
                        </td>
                        {% endfor %}
                        <td>
                            {% with prices=comparison_data|map_month_prices:month_id %}
                            {% if prices|length > 1 %}
                            {{ prices|max|subtract:prices|min|floatformat:2 }} €
                            ({{ prices|max|subtract:prices|min|divide:prices|min|multiply:100|floatformat:1 }}%)
                            {% else %}
                            -
                            {% endif %}
                            {% endwith %}
                        </td>
                    </tr>
                    {% endfor %}
                </tbody>
            </table>
        </div>
        {% endif %}
    </div>
</div>
{% else %}
<div class="alert alert-info">
    <i class="fa-solid fa-info-circle me-2"></i> Veuillez sélectionner au moins une destination pour afficher la comparaison.
</div>
{% endif %}
{% endblock %}

{% block extra_js %}
{% if comparison_data %}
<script>
    // Données pour le graphique
    const chartData = {{ chart_data|safe }};

    document.addEventListener('DOMContentLoaded', function() {
        const comparisonCtx = document.getElementById('comparisonChart').getContext('2d');

        const comparisonChart = new Chart(comparisonCtx, {
            type: 'line',
            data: chartData,
            options: {
                responsive: true,
                maintainAspectRatio: false,
                elements: {
                    line: {
                        tension: 0.3
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Prix moyen (€)'
                        }
                    },
                    x: {
                        title: {
                            display: true,
                            text: 'Mois'
                        }
                    }
                },
                plugins: {
                    legend: {
                        position: 'bottom'
                    },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                const value = context.raw;
                                if (value === null) {
                                    return `${context.dataset.label}: Données non disponibles`;
                                }
                                return `${context.dataset.label}: ${value.toFixed(2)}€`;
                            }
                        }
                    }
                }
            }
        });
    });
</script>
{% endif %}
{% endblock %}
''',

    # Ajouter une fonction pour écrire les fichiers
}

def write_file(file_path, content):
    """Écrit le contenu dans un fichier en créant les répertoires nécessaires."""
    try:
        # Créer le répertoire parent s'il n'existe pas
        os.makedirs(os.path.dirname(os.path.join(ROOT_DIR, file_path)), exist_ok=True)

        # Écrire le contenu dans le fichier
        with open(os.path.join(ROOT_DIR, file_path), 'w', encoding='utf-8') as f:
            f.write(content)

        print(f"✓ Fichier créé: {file_path}")
        return True
    except Exception as e:
        print(f"✕ Erreur lors de la création de {file_path}: {str(e)}")
        return False

# Écrire les fichiers
for file_path, content in FILES.items():
    write_file(file_path, content)

print("\nCréation des fichiers terminée!")