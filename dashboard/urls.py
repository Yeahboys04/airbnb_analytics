from django.urls import path
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