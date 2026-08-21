"""URL-маршруты каталога."""

from django.urls import path

from apps.catalog.views import (
    BuilderListView,
    CityListView,
    DistrictListView,
    FeaturedListingsView,
    FilterOptionsView,
    ListingCountView,
    ListingDetailView,
    ListingListView,
    ListingViewCounterView,
    SimilarListingsView,
)

app_name = "catalog"

urlpatterns = [
    path("catalog/cities/", CityListView.as_view(), name="cities"),
    path("catalog/districts/", DistrictListView.as_view(), name="districts"),
    path("catalog/builders/", BuilderListView.as_view(), name="builders"),
    path("catalog/filter-options/", FilterOptionsView.as_view(), name="filter-options"),
    # featured объявлен до <slug>, иначе «featured» будет принят за слаг.
    path("listings/featured/", FeaturedListingsView.as_view(), name="listings-featured"),
    path("listings/count/", ListingCountView.as_view(), name="listings-count"),
    path("listings/", ListingListView.as_view(), name="listings"),
    path("listings/<slug:slug>/", ListingDetailView.as_view(), name="listing-detail"),
    path("listings/<slug:slug>/view/", ListingViewCounterView.as_view(), name="listing-view"),
    path("listings/<slug:slug>/similar/", SimilarListingsView.as_view(), name="listing-similar"),
]
