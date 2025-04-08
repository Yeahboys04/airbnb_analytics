from django import template
import logging

register = template.Library()
logger = logging.getLogger('django')


@register.filter
def get_item(dictionary, key):
    """Récupère une valeur d'un dictionnaire par sa clé"""
    if not dictionary:
        return None

    # Convertir la clé en chaîne pour correspondre à la façon dont les données sont stockées
    str_key = str(key)
    result = dictionary.get(str_key)

    # Débogage
    if result is None:
        # Afficher les clés disponibles
        available_keys = list(dictionary.keys()) if hasattr(dictionary, 'keys') else []
        logger.debug(f"get_item: Clé '{str_key}' non trouvée. Clés disponibles: {available_keys}")

    return result


@register.filter
def map_month_prices(destinations, month_id):
    """
    Extrait les prix pour un mois spécifique à partir des données de destination.

    Args:
        destinations: Liste des données de destination
        month_id: ID du mois

    Returns:
        Liste des prix moyens pour ce mois
    """
    prices = []
    month_str = str(month_id)

    try:
        for dest in destinations:
            if not dest.get('months'):
                continue

            # Essayer d'obtenir les données pour ce mois
            month_data = dest['months'].get(month_str)
            if month_data and 'avg_price' in month_data:
                price = month_data['avg_price']
                if price is not None:
                    prices.append(float(price))

        # Débogage
        logger.debug(
            f"map_month_prices: Mois {month_str}, Destinations: {len(destinations)}, Prix extraits: {len(prices)}")
        logger.debug(f"Prix pour le mois {month_str}: {prices}")

        return prices
    except Exception as e:
        logger.error(f"Erreur dans map_month_prices: {str(e)}")
        return []


@register.filter
def subtract(value, arg):
    """Soustrait arg de value"""
    try:
        return float(value) - float(arg)
    except (ValueError, TypeError) as e:
        logger.error(f"Erreur de soustraction: {str(e)}, value={value}, arg={arg}")
        return 0


@register.filter
def divide(value, arg):
    """Divise value par arg"""
    try:
        arg = float(arg)
        if arg == 0:
            return 0
        return float(value) / arg
    except (ValueError, TypeError) as e:
        logger.error(f"Erreur de division: {str(e)}, value={value}, arg={arg}")
        return 0


@register.filter
def multiply(value, arg):
    """Multiplie value par arg"""
    try:
        return float(value) * float(arg)
    except (ValueError, TypeError) as e:
        logger.error(f"Erreur de multiplication: {str(e)}, value={value}, arg={arg}")
        return 0


@register.filter
def min_value(values):
    """Retourne la valeur minimale d'une liste"""
    try:
        if not values or len(values) == 0:
            return 0

        # Filtrer les valeurs None et convertir en flottant
        valid_values = [float(x) for x in values if x is not None]
        if not valid_values:
            return 0

        return min(valid_values)
    except Exception as e:
        logger.error(f"Erreur dans min_value: {str(e)}, values={values}")
        return 0


@register.filter
def max_value(values):
    """Retourne la valeur maximale d'une liste"""
    try:
        if not values or len(values) == 0:
            return 0

        # Filtrer les valeurs None et convertir en flottant
        valid_values = [float(x) for x in values if x is not None]
        if not valid_values:
            return 0

        return max(valid_values)
    except Exception as e:
        logger.error(f"Erreur dans max_value: {str(e)}, values={values}")
        return 0


# Ajouter un filtre pour le débogage dans le template
@register.filter
def debug_print(value):
    """Affiche la valeur dans les logs pour le débogage"""
    logger.info(f"Debug template: {value}")
    return value


@register.filter
def price_difference(prices):
    """
    Calcule la différence entre le prix maximum et minimum

    Args:
        prices: Liste des prix

    Returns:
        Différence entre max et min
    """
    try:
        if not prices or len(prices) < 2:
            return 0

        # Filtrer les valeurs None et convertir en flottant
        valid_prices = [float(x) for x in prices if x is not None]
        if len(valid_prices) < 2:
            return 0

        max_price = max(valid_prices)
        min_price = min(valid_prices)

        return max_price - min_price
    except Exception as e:
        logger.error(f"Erreur dans price_difference: {str(e)}, prices={prices}")
        return 0


@register.filter
def price_difference_percent(prices):
    """
    Calcule le pourcentage de différence entre le prix maximum et minimum

    Args:
        prices: Liste des prix

    Returns:
        Pourcentage de différence
    """
    try:
        if not prices or len(prices) < 2:
            return 0

        # Filtrer les valeurs None et convertir en flottant
        valid_prices = [float(x) for x in prices if x is not None]
        if len(valid_prices) < 2:
            return 0

        max_price = max(valid_prices)
        min_price = min(valid_prices)

        if min_price == 0:
            return 0

        return ((max_price - min_price) / min_price) * 100
    except Exception as e:
        logger.error(f"Erreur dans price_difference_percent: {str(e)}, prices={prices}")
        return 0