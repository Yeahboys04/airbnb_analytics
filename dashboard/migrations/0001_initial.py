# Generated by Django 4.2.10 on 2025-04-08 18:58

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = [
    ]

    operations = [
        migrations.CreateModel(
            name='Destination',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(help_text='Nom de la destination (ex: Paris,France)', max_length=255, unique=True)),
                ('slug', models.SlugField(help_text='Slug pour les URLs', max_length=255, unique=True)),
                ('last_scraping', models.DateTimeField(blank=True, help_text='Date du dernier scraping', null=True)),
                ('status', models.CharField(default='pending', help_text='Statut du dernier scraping', max_length=50)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
        ),
        migrations.CreateModel(
            name='ScrapingJob',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('status', models.CharField(default='pending', help_text='Statut de la tâche', max_length=50)),
                ('scheduled_time', models.DateTimeField(help_text='Heure planifiée')),
                ('started_at', models.DateTimeField(blank=True, help_text='Heure de début', null=True)),
                ('completed_at', models.DateTimeField(blank=True, help_text='Heure de fin', null=True)),
                ('error_message', models.TextField(blank=True, help_text="Message d'erreur en cas d'échec", null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('destination', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='scraping_jobs', to='dashboard.destination')),
            ],
            options={
                'ordering': ['-scheduled_time'],
            },
        ),
        migrations.CreateModel(
            name='PriceData',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('year', models.IntegerField(help_text='Année des données')),
                ('month', models.IntegerField(help_text='Mois (1-12)')),
                ('month_name', models.CharField(help_text='Nom du mois', max_length=20)),
                ('avg_price', models.FloatField(help_text='Prix moyen')),
                ('median_price', models.FloatField(help_text='Prix médian')),
                ('min_price', models.FloatField(help_text='Prix minimum')),
                ('max_price', models.FloatField(help_text='Prix maximum')),
                ('sample_size', models.IntegerField(help_text="Nombre d'échantillons")),
                ('season', models.CharField(help_text='Saison', max_length=20)),
                ('relative_price', models.FloatField(help_text='Prix relatif par rapport à la moyenne annuelle')),
                ('price_rank', models.IntegerField(help_text='Rang du prix (du moins cher au plus cher)')),
                ('is_cheapest', models.BooleanField(default=False, help_text="Indique si c'est le mois le moins cher")),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('destination', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='price_data', to='dashboard.destination')),
            ],
            options={
                'ordering': ['month'],
                'unique_together': {('destination', 'year', 'month')},
            },
        ),
        migrations.CreateModel(
            name='AnalysisResult',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('year', models.IntegerField(help_text="Année de l'analyse")),
                ('cheapest_month', models.CharField(help_text='Mois le moins cher', max_length=20)),
                ('cheapest_month_price', models.FloatField(help_text='Prix moyen du mois le moins cher')),
                ('most_expensive_month', models.CharField(help_text='Mois le plus cher', max_length=20)),
                ('most_expensive_month_price', models.FloatField(help_text='Prix moyen du mois le plus cher')),
                ('potential_savings', models.FloatField(help_text='Économies potentielles entre le mois le plus cher et le moins cher')),
                ('savings_percentage', models.FloatField(help_text="Pourcentage d'économies")),
                ('coefficient_of_variation', models.FloatField(help_text='Coefficient de variation des prix (écart-type / moyenne)')),
                ('_statistics_json', models.TextField(db_column='statistics_json', help_text='Statistiques au format JSON')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('destination', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='analysis_results', to='dashboard.destination')),
            ],
            options={
                'unique_together': {('destination', 'year')},
            },
        ),
    ]
