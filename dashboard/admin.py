from django.contrib import admin
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