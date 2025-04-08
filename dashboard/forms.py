from django import forms
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