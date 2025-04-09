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
from concurrent.futures import ThreadPoolExecutor, as_completed

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

    def __init__(self, base_url, data_dir, headless=True, max_retries=3, timeout=15):
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

        # Créer un répertoire pour le cache
        self.cache_dir = Path(data_dir) / 'cache'
        os.makedirs(self.cache_dir, exist_ok=True)

        # Configurer les options du navigateur
        self.chrome_options = Options()
        if headless:
            self.chrome_options.add_argument("--headless=new")

        # Arguments pour améliorer la stabilité et la performance
        self.chrome_options.add_argument("--window-size=1920,1080")
        self.chrome_options.add_argument("--disable-notifications")
        self.chrome_options.add_argument("--disable-infobars")
        self.chrome_options.add_argument("--disable-extensions")
        self.chrome_options.add_argument("--disable-gpu")
        self.chrome_options.add_argument("--no-sandbox")
        self.chrome_options.add_argument("--disable-dev-shm-usage")
        self.chrome_options.add_argument("--log-level=3")

        # Options pour améliorer la vitesse
        self.chrome_options.add_argument("--disable-images")
        self.chrome_options.add_argument("--blink-settings=imagesEnabled=false")
        self.chrome_options.add_argument("--disable-animations")
        self.chrome_options.add_experimental_option("prefs", {
            "profile.managed_default_content_settings.images": 2,
        })

        # Ajouter un user agent réaliste
        self.chrome_options.add_argument(
            "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")

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
            self.driver.implicitly_wait(5)  # Réduit le temps d'attente implicite

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

    def _random_delay(self, min_seconds=0.5, max_seconds=1.5):
        """
        Ajoute un délai aléatoire réduit pour simuler un comportement humain
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

                # Extraire les prix - mise à jour des sélecteurs basée sur l'extrait HTML
                for listing in listings:
                    # Différentes classes possibles pour l'élément de prix
                    price_selectors = [
                        'span._hb913q', 'span.u1y3vocb', 'span._4dhrua',
                        'span[data-testid="price-element"] span'
                    ]

                    price_text = None
                    for selector in price_selectors:
                        element = soup.select_one(selector)
                        if element:
                            price_text = element.text
                            break

                    # Si aucun élément trouvé avec les sélecteurs, essayer des class_
                    if not price_text:
                        price_element = (
                                listing.find('span', class_="_hb913q") or
                                listing.find('span', class_="u1y3vocb") or
                                listing.find('span', class_="_4dhrua")
                        )
                        if price_element:
                            price_text = price_element.text

                    if not price_text:
                        continue

                    # Extraire les chiffres avec regex
                    price = re.sub(r"\D", "", price_text)
                    if price.isdigit():
                        prices.append(int(price))

                if not prices:
                    # Si aucun prix trouvé, essayer avec un sélecteur plus général
                    all_prices = re.findall(r'(\d+)\s*€', html)
                    prices = [int(p) for p in all_prices if p]

                logger.info(f"Extraction réussie de {len(prices)} prix")
                return prices

            except (TimeoutException, NoSuchElementException, StaleElementReferenceException) as e:
                retry_count += 1
                logger.warning(f"Tentative {retry_count}/{self.max_retries} échouée: {str(e)}")
                self._random_delay(1, 3)  # Délai réduit entre les tentatives

        logger.error(f"Échec de l'extraction des prix après {self.max_retries} tentatives")
        return prices

    def _scroll_page(self):
        """Fait défiler la page pour charger tous les résultats - méthode optimisée"""
        try:
            # Scroll en 3 étapes pour charger le contenu progressivement
            for _ in range(3):
                self.driver.execute_script("window.scrollBy(0, 1000);")
                time.sleep(0.5)

            # Un dernier scroll jusqu'en bas
            self.driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
            time.sleep(0.8)
        except Exception as e:
            logger.warning(f"Erreur pendant le scroll: {str(e)}")

    def _get_cache_key(self, destination, year, month):
        """Génère une clé de cache unique pour la destination et la date"""
        return os.path.join(
            str(self.cache_dir),
            f"{destination.replace(',', '_').replace(' ', '_')}_{year}_{month}.json"
        )

    def _get_from_cache(self, cache_key):
        """Récupère les données depuis le cache si elles existent"""
        if os.path.exists(cache_key):
            try:
                with open(cache_key, 'r') as f:
                    data = json.load(f)
                logger.info(f"Données récupérées depuis le cache: {cache_key}")
                return data
            except Exception as e:
                logger.warning(f"Erreur lors de la lecture du cache: {str(e)}")
        return None

    def _save_to_cache(self, cache_key, data):
        """Sauvegarde les données dans le cache"""
        try:
            with open(cache_key, 'w') as f:
                json.dump(data, f)
            logger.info(f"Données sauvegardées dans le cache: {cache_key}")
        except Exception as e:
            logger.warning(f"Erreur lors de la sauvegarde dans le cache: {str(e)}")

    def _scrape_month(self, destination, year, month, stay_duration=7):
        """
        Scrape les prix pour un mois spécifique.

        Args:
            destination: Destination à rechercher (ex: "Paris,France")
            year: Année pour la recherche
            month: Mois à scraper (1-12)
            stay_duration: Durée du séjour en jours

        Returns:
            Dictionnaire avec les données du mois ou None en cas d'échec
        """
        # Vérifier si les données sont dans le cache
        cache_key = self._get_cache_key(destination, year, month)
        cached_data = self._get_from_cache(cache_key)

        # Si force_refresh=True dans les paramètres, ignorer le cache
        if cached_data:
            logger.info(f"Utilisation des données en cache pour {destination}, mois {month}, année {year}")
            return cached_data

        # Initialiser un nouveau navigateur pour chaque mois (évite les problèmes de réutilisation)
        driver = None
        try:
            # Configuration des options
            options = Options()
            options.add_argument("--headless=new")
            options.add_argument("--window-size=1920,1080")
            options.add_argument("--disable-notifications")
            options.add_argument("--disable-infobars")
            options.add_argument("--disable-extensions")
            options.add_argument("--disable-gpu")
            options.add_argument("--no-sandbox")
            options.add_argument("--disable-dev-shm-usage")
            options.add_argument("--disable-images")
            options.add_argument("--blink-settings=imagesEnabled=false")
            options.add_argument("--disable-animations")
            options.add_experimental_option("prefs", {
                "profile.managed_default_content_settings.images": 2,
            })
            options.add_argument(
                "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            )

            # Chemins possibles pour le ChromeDriver - Utiliser la même logique que dans _setup_driver()
            possible_paths = [
                os.path.join(os.getcwd(), 'chromedriver-win64', 'chromedriver.exe'),
                os.path.join(os.path.dirname(__file__), '..', 'chromedriver-win64', 'chromedriver.exe')
            ]

            # Trouver le chemin du ChromeDriver
            chromedriver_path = None
            for path in possible_paths:
                if os.path.exists(path):
                    chromedriver_path = path
                    logger.info(f"Utilisation du ChromeDriver à l'emplacement: {chromedriver_path}")
                    break

            # Si aucun chemin n'est trouvé, utiliser ChromeDriverManager
            if not chromedriver_path:
                chromedriver_path = ChromeDriverManager().install()
                logger.info(f"ChromeDriver installé à: {chromedriver_path}")

            # Initialiser le driver pour ce mois avec le chemin explicite
            service = Service(chromedriver_path)
            driver = webdriver.Chrome(service=service, options=options)
            driver.implicitly_wait(5)

            # Définir les dates de séjour (milieu du mois)
            check_in_date = datetime(year, month, 15)
            check_out_date = check_in_date + timedelta(days=stay_duration)

            # Formater les dates pour l'URL
            check_in_str = check_in_date.strftime('%Y-%m-%d')
            check_out_str = check_out_date.strftime('%Y-%m-%d')

            logger.info(f"Scraping du mois {month} ({check_in_str} à {check_out_str})")

            # Construire l'URL de recherche
            formatted_dest = destination.replace(' ', '-').replace(',', '--')
            url = f"{self.base_url}/s/{formatted_dest}/homes?checkin={check_in_str}&checkout={check_out_str}&adults=2&children=0&infants=0&pets=0"

            for attempt in range(self.max_retries):
                try:
                    logger.info(f"Navigation vers {url}")
                    driver.get(url)
                    time.sleep(random.uniform(1, 2))

                    # Accepter les cookies si nécessaire
                    try:
                        WebDriverWait(driver, 5).until(
                            EC.element_to_be_clickable((By.CSS_SELECTOR, "button[data-testid='accept-btn']"))
                        ).click()
                        logger.info("Cookies acceptés")
                    except (TimeoutException, NoSuchElementException):
                        pass

                    # Faire défiler la page
                    for _ in range(3):
                        driver.execute_script("window.scrollBy(0, 1000);")
                        time.sleep(0.5)
                    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
                    time.sleep(1)

                    # Extraire les prix
                    prices = []

                    # Attendre que les éléments de prix soient chargés
                    WebDriverWait(driver, 15).until(
                        EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid='card-container']"))
                    )

                    # Obtenir le HTML et l'analyser
                    html = driver.page_source
                    soup = BeautifulSoup(html, 'html.parser')

                    # Trouver les conteneurs d'hébergement
                    listings = soup.find_all('div', {'data-testid': "card-container"})
                    logger.info(f"Mois {month}: {len(listings)} hébergements trouvés")

                    # Récupérer les classes utilisées pour les prix dans la page actuelle
                    price_classes = []
                    test_selectors = ['._hb913q', '.u1y3vocb', '._4dhrua']
                    for selector in test_selectors:
                        if len(soup.select(selector)) > 0:
                            price_classes.append(selector.lstrip('.'))

                    # Si des classes ont été identifiées, les utiliser pour l'extraction
                    if price_classes:
                        for listing in listings:
                            for cls in price_classes:
                                price_element = listing.find('span', class_=cls)
                                if price_element:
                                    price_text = price_element.text
                                    price = re.sub(r"\D", "", price_text)
                                    if price.isdigit():
                                        prices.append(int(price))
                                    break

                    # Si l'extraction basée sur les classes échoue, essayer une approche plus générale
                    if not prices:
                        price_spans = soup.select('span[data-testid="price-element"] span')
                        for span in price_spans:
                            price = re.sub(r"\D", "", span.text)
                            if price.isdigit():
                                prices.append(int(price))

                    # Si toujours pas de prix, utiliser une regex sur toute la page
                    if not prices:
                        all_prices = re.findall(r'(\d+)\s*€', html)
                        for p in all_prices:
                            if p.isdigit() and int(p) > 10 and int(p) < 10000:  # Filtrer les valeurs improbables
                                prices.append(int(p))

                    # Vérifier qu'on a trouvé des prix
                    if prices:
                        month_name = check_in_date.strftime('%B')
                        avg_price = sum(prices) / len(prices)
                        median_price = sorted(prices)[len(prices) // 2] if prices else 0  # Calcul simple de la médiane

                        # Créer le dictionnaire de résultats
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

                        # Sauvegarder dans le cache
                        self._save_to_cache(cache_key, month_data)

                        logger.info(f"Mois {month_name}: prix moyen = {avg_price:.2f}€, {len(prices)} échantillons")
                        return month_data
                    else:
                        logger.warning(f"Aucun prix trouvé pour le mois {month} (tentative {attempt + 1})")
                        if attempt < self.max_retries - 1:
                            time.sleep(random.uniform(2, 4))

                except Exception as e:
                    logger.warning(f"Erreur lors du scraping du mois {month} (tentative {attempt + 1}): {str(e)}")
                    if attempt < self.max_retries - 1:
                        time.sleep(random.uniform(2, 4))

            logger.error(f"Échec du scraping pour le mois {month} après {self.max_retries} tentatives")
            return None

        except Exception as e:
            logger.error(f"Erreur lors du scraping du mois {month}: {str(e)}")
            return None
        finally:
            # Fermer le navigateur
            if driver:
                try:
                    driver.quit()
                except:
                    pass

    def get_monthly_prices_parallel(self, destination, year=None, stay_duration=7, max_workers=3, force_refresh=False):
        """
        Récupère les prix moyens pour chaque mois de l'année en parallèle.

        Args:
            destination: Destination à rechercher (ex: "Paris,France")
            year: Année pour la recherche (si None, utilise l'année en cours)
            stay_duration: Durée du séjour en jours
            max_workers: Nombre maximum de workers pour la parallélisation
            force_refresh: Si True, ignore le cache et force la récupération de nouvelles données

        Returns:
            DataFrame pandas avec les prix moyens, médians, min et max par mois
        """
        if not year:
            year = datetime.now().year

        logger.info(f"Début du scraping parallèle des prix pour {destination} en {year}")

        # Assurez-vous que le driver principal est configuré (pour valider le chemin du ChromeDriver)
        success = self._setup_driver()
        if not success:
            logger.error("Impossible d'initialiser le driver principal")
            return None

        # Fermer le driver principal, puisque chaque worker aura son propre driver
        self.close()

        try:
            # Liste de tous les mois à scraper
            months = list(range(1, 13))
            results = []

            # Exécuter le scraping en parallèle avec au maximum max_workers threads
            with ThreadPoolExecutor(max_workers=max_workers) as executor:
                # Créer les tâches pour chaque mois
                future_to_month = {
                    executor.submit(self._scrape_month, destination, year, month, stay_duration): month
                    for month in months
                }

                # Récupérer les résultats au fur et à mesure qu'ils sont disponibles
                for future in as_completed(future_to_month):
                    month = future_to_month[future]
                    try:
                        result = future.result()
                        if result:
                            results.append(result)
                            logger.info(f"Résultat récupéré pour le mois {month}")
                        else:
                            logger.warning(f"Pas de résultat pour le mois {month}")
                    except Exception as e:
                        logger.error(f"Exception pour le mois {month}: {str(e)}")

            # Créer un DataFrame à partir des résultats
            if results:
                df = pd.DataFrame(results)

                # Trier par mois pour une meilleure lisibilité
                df = df.sort_values('month')

                # Sauvegarder les données brutes
                timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
                output_file = self.raw_data_dir / f"{destination.replace(',', '_')}_{year}_{timestamp}.csv"
                df.to_csv(output_file, index=False)
                logger.info(f"Données sauvegardées dans {output_file}")

                return df
            else:
                logger.warning("Aucun résultat obtenu pour la destination et l'année spécifiées")
                return None

        except Exception as e:
            logger.error(f"Erreur lors du scraping parallèle: {str(e)}")
            return None

    def run(self, destination, year=None, stay_duration=7, max_workers=3, force_refresh=False):
        """
        Point d'entrée principal pour exécuter le scraping.

        Args:
            destination: Destination à rechercher
            year: Année pour la recherche (défaut: année courante)
            stay_duration: Durée du séjour en jours
            max_workers: Nombre maximum de workers pour la parallélisation
            force_refresh: Si True, ignore le cache et force la récupération de nouvelles données

        Returns:
            DataFrame des résultats ou None en cas d'échec
        """
        try:
            # S'assurer que le driver principal fonctionne avant de commencer
            # Cette étape valide le chemin du ChromeDriver
            success = self._setup_driver()
            if not success:
                logger.error("Échec de l'initialisation du driver principal")
                return None

            # Fermer le driver principal car get_monthly_prices_parallel va le reconfigurer
            self.close()

            return self.get_monthly_prices_parallel(
                destination, year, stay_duration, max_workers, force_refresh
            )
        except Exception as e:
            logger.error(f"Erreur fatale lors du scraping: {str(e)}", exc_info=True)
            return None


# Fonction pour utilisation directe du module
def scrape_destination(destination, data_dir, year=None, stay_duration=7, headless=True, max_workers=3,
                       force_refresh=False):
    """
    Fonction utilitaire pour scraper une destination depuis un autre module.

    Args:
        destination: Destination à rechercher (ex: "Paris,France")
        data_dir: Répertoire de données
        year: Année pour la recherche
        stay_duration: Durée du séjour en jours
        headless: Si True, exécute le navigateur en mode headless
        max_workers: Nombre de workers parallèles (max 3 recommandé)
        force_refresh: Si True, ignore le cache et force la récupération de nouvelles données

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
        result = scraper.run(destination, year, stay_duration, max_workers, force_refresh)

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

    # Si vous êtes dans un environnement Django
    try:
        from django.conf import settings

        data_dir = settings.DATA_DIR
    except:
        # Fallback pour les tests hors Django
        data_dir = "./data"
        os.makedirs(data_dir, exist_ok=True)

    # Configuration du logging
    logging.basicConfig(level=logging.INFO,
                        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')

    # Configuration spécifique pour le scraper
    logger = logging.getLogger('scraper')
    logger.setLevel(logging.INFO)

    # Destination par défaut si aucune n'est spécifiée
    destination = sys.argv[1] if len(sys.argv) > 1 else "Paris,France"
    force_refresh = "--force" in sys.argv

    print(f"Scraping de {destination}..." + (" (refresh forcé)" if force_refresh else ""))

    # Instancier le scraper directement
    base_url = "https://www.airbnb.fr"
    scraper = AirbnbScraper(base_url, data_dir, headless=False, max_retries=2, timeout=15)

    # Lancer le scraping
    result = scraper.run(
        destination,
        year=None,  # Année courante
        stay_duration=7,
        max_workers=3,
        force_refresh=force_refresh
    )

    if result is not None:
        print("\nRésultats:")
        print(result.sort_values('avg_price')[
                  ['month_name', 'avg_price', 'median_price', 'min_price', 'max_price', 'sample_size']])

        cheapest_month = result.loc[result['avg_price'].idxmin()]
        print(f"\nMois le moins cher: {cheapest_month['month_name']} "
              f"(moyenne: {cheapest_month['avg_price']:.2f}€)")
    else:
        print("Le scraping a échoué.")