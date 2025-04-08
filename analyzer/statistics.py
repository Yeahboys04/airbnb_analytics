"""
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