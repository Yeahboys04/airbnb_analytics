"""
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