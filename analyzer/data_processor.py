import os
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
            ) if most_expensive_month['avg_price'] > 0 else 0

            # Statistiques par saison - CORRECTION ICI
            # Assurons-nous que la colonne 'season' contient des valeurs hashables (str)
            df['season'] = df['season'].astype(str)

            # Approche simplifiée: traiter chaque groupe séparément sans fusion
            stats['season_analysis'] = {}

            for season, group in df.groupby('season'):
                month_names = ', '.join(group['month_name'].tolist())
                avg_price = group['avg_price'].mean()
                min_price = group['avg_price'].min()
                max_price = group['avg_price'].max()

                stats['season_analysis'][season] = {
                    'avg_price': round(avg_price, 2),
                    'min_price': round(min_price, 2),
                    'max_price': round(max_price, 2),
                    'months': month_names,
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