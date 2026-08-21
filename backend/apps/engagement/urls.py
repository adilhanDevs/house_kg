"""URL-маршруты сохранённых фильтров и подборок."""

from django.urls import path

from apps.engagement.views import (
    CollectionListingsView,
    CollectionListView,
    FavouriteListView,
    FavouriteView,
    SavedFilterDetailView,
    SavedFilterListCreateView,
    SavedFilterListingsView,
    ViewHistoryView,
)

app_name = "engagement"

urlpatterns = [
    path("saved-filters/", SavedFilterListCreateView.as_view(), name="saved-filters"),
    path("saved-filters/<int:pk>/", SavedFilterDetailView.as_view(), name="saved-filter"),
    path(
        "saved-filters/<int:pk>/listings/",
        SavedFilterListingsView.as_view(),
        name="saved-filter-listings",
    ),
    path("favourites/", FavouriteListView.as_view(), name="favourites"),
    path(
        "listings/<slug:slug>/favourite/",
        FavouriteView.as_view(),
        name="listing-favourite",
    ),
    path("view-history/", ViewHistoryView.as_view(), name="view-history"),
    path("collections/", CollectionListView.as_view(), name="collections"),
    path(
        "collections/<slug:slug>/listings/",
        CollectionListingsView.as_view(),
        name="collection-listings",
    ),
]
