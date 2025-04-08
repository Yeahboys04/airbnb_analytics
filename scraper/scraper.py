import os
import time
import random
import json
import logging
import traceback
import pandas as pd
from datetime import datetime, timedelta
from pathlib import Path
import re

# Selenium imports
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

# Web utilities
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

        # Créer le répertoire de données s'il n'existe pas
        os.makedirs(self.raw_data_dir, exist_ok=True)

        # Configurer les options du navigateur
        self.chrome_options = Options()
        if headless:
            self.chrome_options.add_argument("--headless")

        # Arguments pour améliorer la stabilité
        self.chrome_options.add_argument("--window-size=1920,1080")
        self.chrome_options.add_argument("--disable-notifications")
        self.chrome_options.add_argument("--disable-infobars")
        self.chrome_options.add_argument("--disable-extensions")
        self.chrome_options.add_argument("--disable-gpu")
        self.chrome_options.add_argument("--no-sandbox")
        self.chrome_options.add_argument("--disable-dev-shm-usage")

        # Ajouter un user agent réaliste
        self.chrome_options.add_argument(
            "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Safari/537.36")

        # Initialiser le driver à None
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
            # Chemins possibles pour le ChromeDriver
            possible_paths = [
                os.path.join(os.getcwd(), 'chromedriver-win64', 'chromedriver.exe'),
                os.path.join(os.path.dirname(__file__), '..', 'chromedriver-win64', 'chromedriver.exe')
            ]

            # Trouver le chemin du ChromeDriver
            chromedriver_path = None
            for path in possible_paths:
                if os.path.exists(path):
                    chromedriver_path = path
                    break

            # Si aucun chemin n'est trouvé, utiliser ChromeDriverManager
            if not chromedriver_path:
                chromedriver_path = ChromeDriverManager().install()

            # Configurer le service
            service = Service(chromedriver_path)

            # Créer le driver
            self.driver = webdriver.Chrome(service=service, options=self.chrome_options)
            self.driver.implicitly_wait(10)

            logger.info(f"Driver Selenium initialisé avec succès. Chemin: {chromedriver_path}")
            return True
        except Exception as e:
            logger.error(f"Erreur lors de l'initialisation du driver: {str(e)}")
            logger.error(traceback.format_exc())
            return False

    def close(self):
        """Ferme le navigateur s'il est ouvert"""
        if self.driver:
            try:
                self.driver.quit()
            except Exception as e:
                logger.warning(f"Erreur lors de la fermeture du driver: {e}")
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
                listings = soup.find_all('div', {'data-testid': "card-container"})
                logger.info(f"Nombre d'hébergements trouvés: {len(listings)}")


                # Extraire les prix
                for listing in listings:
                    # Chercher l'élément de prix (le sélecteur peut varier, donc plusieurs tentatives)
                    price_element = listing.find('span', class_="_hb913q") or listing.find('span', class_="_tyxjp1")

                    if not price_element:
                        continue

                    price = re.sub(r"\D", "", price_element.text)

                    if price.isdigit():
                        prices.append(int(price))

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
                        logger.warning(f"Tentative {attempt + 1}/{self.max_retries} échouée: {str(e)}")
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

    scraper = AirbnbScraper(base_url, data_dir, headless, max_retries, timeout)
    logger.info(f"Début du scraping pour {destination}")

    try:
        result = scraper.run(destination, year, stay_duration)

        if result is not None:
            logger.info(f"Scraping terminé avec succès pour {destination}")
        else:
            logger.error(f"Échec du scraping pour {destination}")

        return result
    finally:
        scraper.close()


if __name__ == "__main__":
    # Point d'entrée pour exécution directe (tests)
    import sys
    import logging
    from django.conf import settings

    # Configuration du logging
    logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

    # Configuration spécifique pour le scraper
    logger = logging.getLogger('scraper')
    logger.setLevel(logging.INFO)

    # Destination par défaut si aucune n'est spécifiée
    destination = sys.argv[1] if len(sys.argv) > 1 else "Paris,France"

    # Utiliser le répertoire de données de Django
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