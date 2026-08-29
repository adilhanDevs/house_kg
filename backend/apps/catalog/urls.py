"""URL-маршруты каталога."""

from django.urls import path

from apps.catalog.views import (
    BuilderListView,
    CityListView,
    DistrictListView,
    FeaturedListingsView,
    FilterOptionsView,
    ListingArchiveView,
    ListingBumpView,
    ListingCountView,
    ListingDetailView,
    ListingDraftView,
    ListingListView,
    ListingMarkSoldView,
    ListingMediaCoverView,
    ListingMediaItemView,
    ListingMediaReorderView,
    ListingMediaUploadView,
    ListingPublishView,
    ListingReelsView,
    ListingReportView,
    ListingRestoreView,
    ListingViewCounterView,
    ModerationApproveView,
    ModerationAssignView,
    ModerationQueueView,
    ModerationRejectView,
    MyListingsView,
    RejectReasonListView,
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
    path("listings/draft/", ListingDraftView.as_view(), name="listing-draft"),
    path("listings/reels/", ListingReelsView.as_view(), name="listings-reels"),
    path("users/me/listings/", MyListingsView.as_view(), name="my-listings"),
    path("listings/", ListingListView.as_view(), name="listings"),
    path("listings/<slug:slug>/", ListingDetailView.as_view(), name="listing-detail"),
    path("listings/<slug:slug>/view/", ListingViewCounterView.as_view(), name="listing-view"),
    path("listings/<slug:slug>/similar/", SimilarListingsView.as_view(), name="listing-similar"),
    path("listings/<slug:slug>/publish/", ListingPublishView.as_view(), name="listing-publish"),
    path("listings/<slug:slug>/archive/", ListingArchiveView.as_view(), name="listing-archive"),
    path("listings/<slug:slug>/restore/", ListingRestoreView.as_view(), name="listing-restore"),
    path(
        "listings/<slug:slug>/mark-sold/",
        ListingMarkSoldView.as_view(),
        name="listing-mark-sold",
    ),
    path("listings/<slug:slug>/bump/", ListingBumpView.as_view(), name="listing-bump"),
    path(
        "listings/<slug:slug>/media/",
        ListingMediaUploadView.as_view(),
        name="listing-media",
    ),
    # reorder объявлен до <int:media_id>, хотя конвертер их и так не спутает.
    path(
        "listings/<slug:slug>/media/reorder/",
        ListingMediaReorderView.as_view(),
        name="listing-media-reorder",
    ),
    path(
        "listings/<slug:slug>/media/<int:media_id>/",
        ListingMediaItemView.as_view(),
        name="listing-media-item",
    ),
    path(
        "listings/<slug:slug>/media/<int:media_id>/set-cover/",
        ListingMediaCoverView.as_view(),
        name="listing-media-cover",
    ),
    path("listings/<slug:slug>/report/", ListingReportView.as_view(), name="listing-report"),
    # Модерация. reject-reasons объявлен до <int:task_id>, чтобы путь не
    # был принят за идентификатор задачи.
    path("moderation/queue/", ModerationQueueView.as_view(), name="moderation-queue"),
    path(
        "moderation/reject-reasons/",
        RejectReasonListView.as_view(),
        name="moderation-reject-reasons",
    ),
    path(
        "moderation/<int:task_id>/assign/",
        ModerationAssignView.as_view(),
        name="moderation-assign",
    ),
    path(
        "moderation/<int:task_id>/approve/",
        ModerationApproveView.as_view(),
        name="moderation-approve",
    ),
    path(
        "moderation/<int:task_id>/reject/",
        ModerationRejectView.as_view(),
        name="moderation-reject",
    ),
]
