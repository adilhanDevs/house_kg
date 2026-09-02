"""Эндпоинты аутентификации и профиля пользователя."""

from typing import Any

from django.conf import settings
from django.core import signing
from django.db.models import QuerySet
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import status
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.generics import GenericAPIView, ListAPIView, RetrieveUpdateDestroyAPIView
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.serializers import BaseSerializer
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from apps.catalog.enums import ListingStatus
from apps.catalog.filters import ListingFilterSet
from apps.catalog.models import Listing
from apps.catalog.serializers import ListingListSerializer
from apps.catalog.views import (
    ALLOWED_LISTING_ORDERINGS,
    DEFAULT_LISTING_ORDERING,
    ListingCursorPagination,
)
from apps.common.audit import client_ip, record_audit
from apps.common.exceptions import ApiValidationError
from apps.common.models import AuditLog
from apps.common.pagination import DefaultCursorPagination
from apps.common.serializers import ErrorSerializer
from apps.users.kyc import read_file_token
from apps.users.models import (
    DataExport,
    IdentityVerification,
    Review,
    SellerVerification,
    User,
    VerificationStatus,
)
from apps.users.permissions import CanReviewIdentity, IsProUser
from apps.users.privacy import (
    read_export_token,
    record_consent,
    request_data_export,
)
from apps.users.sellers import (
    create_review,
    delete_review,
    get_seller_profile,
    public_sellers,
    published_reviews,
    reveal_contact,
    seller_card,
    seller_listings,
    submit_seller_verification,
    update_review,
)
from apps.users.serializers import (
    AuthTokensSerializer,
    ConsentRequestSerializer,
    ContactRevealSerializer,
    DataExportSerializer,
    IdentityQueueItemSerializer,
    IdentityReviewSerializer,
    IdentityStatusSerializer,
    IdentitySubmitSerializer,
    IdentitySubmittedSerializer,
    LogoutSerializer,
    OtpRequestResponseSerializer,
    OtpRequestSerializer,
    OtpVerifySerializer,
    PasswordLoginSerializer,
    ProRegisterResponseSerializer,
    ProRegisterSerializer,
    ReviewCreateSerializer,
    ReviewSerializer,
    ReviewUpdateSerializer,
    SellerCardSerializer,
    SellerProfileSerializer,
    SellerVerificationRequestSerializer,
    SellerVerificationSerializer,
    UserConsentSerializer,
    UserMeSerializer,
    UserUpdateSerializer,
)
from apps.users.services import (
    anonymize_user,
    authenticate_by_password,
    issue_otp,
    issue_tokens,
    latest_identity,
    register_pro,
    review_identity,
    submit_identity,
    verify_otp,
)
from apps.users.throttling import (
    ContactRevealThrottle,
    KycSubmitThrottle,
    OtpIpThrottle,
    OtpPhoneHourlyThrottle,
    OtpPhoneResendThrottle,
    PasswordLoginIpThrottle,
    PasswordLoginPhoneThrottle,
    ReviewCreateThrottle,
)


class OtpRequestView(GenericAPIView):
    """POST /api/v1/auth/otp/request/ — выслать код подтверждения."""

    permission_classes = [AllowAny]
    authentication_classes: list = []
    throttle_classes = [OtpPhoneResendThrottle, OtpPhoneHourlyThrottle, OtpIpThrottle]
    serializer_class = OtpRequestSerializer

    @extend_schema(
        operation_id="auth_otp_request",
        summary="Запросить SMS-код",
        description=(
            "Создаёт 4-значный код и отправляет его SMS-провайдеру.\n\n"
            "Лимиты: не чаще одного кода в минуту и не больше пяти в час на номер, "
            "не больше двадцати в час с одного IP. Превышение — 429 с `retry_after`.\n\n"
            "Код в ответе не возвращается никогда."
        ),
        responses={
            status.HTTP_200_OK: OtpRequestResponseSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_429_TOO_MANY_REQUESTS: ErrorSerializer,
        },
        auth=[],
    )
    def post(self, request: Request) -> Response:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        _, is_new_user = issue_otp(
            serializer.validated_data["phone"],
            serializer.validated_data["purpose"],
        )

        return Response(
            {
                "expires_in": settings.OTP_CODE_TTL_SECONDS,
                "resend_after": settings.OTP_RESEND_AFTER_SECONDS,
                "is_new_user": is_new_user,
            }
        )


class OtpVerifyView(GenericAPIView):
    """POST /api/v1/auth/otp/verify/ — обменять код на пару JWT."""

    permission_classes = [AllowAny]
    authentication_classes: list = []
    serializer_class = OtpVerifySerializer

    @extend_schema(
        operation_id="auth_otp_verify",
        summary="Подтвердить код и войти",
        description=(
            "Проверяет последний неиспользованный код номера. Новый пользователь "
            "создаётся автоматически — имя берётся из поля `name`, пароль из "
            "`password`. Пароль существующего аккаунта этим запросом не меняется: "
            "код подтверждает владение номером, но не даёт права переписать "
            "учётные данные.\n\n"
            "Неверный код: 400 «Неверный код» и `details.attempts_left`. "
            "После пяти неудачных попыток код сжигается.\n\n"
            "Для нового пользователя обязателен `accepted_terms_version` — "
            "версия принятого соглашения об обработке персональных данных. "
            "Без него регистрация отклоняется с 400."
        ),
        responses={
            status.HTTP_200_OK: AuthTokensSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
        },
        auth=[],
    )
    def post(self, request: Request) -> Response:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        user, is_new_user = verify_otp(
            phone=data["phone"],
            code=data["code"],
            name=data.get("name", ""),
            purpose=data["purpose"],
            accepted_terms_version=data.get("accepted_terms_version", ""),
            password=data.get("password", ""),
            request=request,
        )

        return Response(
            {
                **issue_tokens(user),
                "user": UserMeSerializer(user, context=self.get_serializer_context()).data,
                "is_new_user": is_new_user,
            }
        )


class ProRegisterView(GenericAPIView):
    """POST /api/v1/auth/pro/register/ — заявка на регистрацию исполнителя."""

    permission_classes = [AllowAny]
    authentication_classes: list = []
    # Запрос высылает SMS — те же лимиты, что и у обычного запроса кода.
    throttle_classes = [OtpPhoneResendThrottle, OtpPhoneHourlyThrottle, OtpIpThrottle]
    serializer_class = ProRegisterSerializer

    @extend_schema(
        operation_id="auth_pro_register",
        summary="Регистрация исполнителя (pro)",
        description=(
            "Создаёт или дозаполняет аккаунт и высылает код с `purpose=pro_register`. "
            "Флаг `is_pro` включается только после подтверждения кода через "
            "`/auth/otp/verify/`.\n\n"
            "Второй аккаунт на тот же телефон не создаётся. Если у номера уже указан "
            "другой ИИН или ИИН занят другим аккаунтом — 409."
        ),
        responses={
            status.HTTP_200_OK: ProRegisterResponseSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
            status.HTTP_429_TOO_MANY_REQUESTS: ErrorSerializer,
        },
        auth=[],
    )
    def post(self, request: Request) -> Response:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        register_pro(
            phone=data["phone"],
            name=data["name"],
            password=data["password"],
            iin=data["iin"],
            whatsapp=data.get("whatsapp", ""),
        )

        return Response(
            {
                "expires_in": settings.OTP_CODE_TTL_SECONDS,
                "resend_after": settings.OTP_RESEND_AFTER_SECONDS,
            }
        )


class PasswordLoginView(GenericAPIView):
    """POST /api/v1/auth/password/login/ — вход по паролю."""

    permission_classes = [AllowAny]
    authentication_classes: list = []
    # Основной вход в приложение: без ограничения попыток пароль подбирается
    # перебором. Сами значения лимитов задаются переменными окружения
    # PASSWORD_LOGIN_PHONE_THROTTLE и PASSWORD_LOGIN_IP_THROTTLE.
    throttle_classes = [PasswordLoginPhoneThrottle, PasswordLoginIpThrottle]
    serializer_class = PasswordLoginSerializer

    @extend_schema(
        operation_id="auth_password_login",
        summary="Вход по паролю",
        description=(
            "Основной способ входа: пароль задаётся при регистрации, после "
            "подтверждения кода из SMS. При неверных данных — 401 с общим "
            "сообщением: по ответу нельзя понять, зарегистрирован ли номер.\n\n"
            "Аккаунты без пароля войти так не могут — им нужна регистрация "
            "или вход по коду."
        ),
        responses={
            status.HTTP_200_OK: AuthTokensSerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
            status.HTTP_429_TOO_MANY_REQUESTS: ErrorSerializer,
        },
        auth=[],
    )
    def post(self, request: Request) -> Response:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = authenticate_by_password(
            serializer.validated_data["phone"],
            serializer.validated_data["password"],
        )

        return Response(
            {
                **issue_tokens(user),
                "user": UserMeSerializer(user, context=self.get_serializer_context()).data,
                "is_new_user": False,
            }
        )


class LogoutView(GenericAPIView):
    """POST /api/v1/auth/logout/ — отозвать refresh-токен."""

    permission_classes = [IsAuthenticated]
    serializer_class = LogoutSerializer

    @extend_schema(
        operation_id="auth_logout",
        summary="Выйти из аккаунта",
        description="Кладёт переданный refresh-токен в blacklist. Access живёт до истечения.",
        responses={
            status.HTTP_204_NO_CONTENT: None,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
        },
    )
    def post(self, request: Request) -> Response:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            RefreshToken(serializer.validated_data["refresh"]).blacklist()
        except TokenError as exc:
            raise ApiValidationError("Некорректный или уже отозванный refresh-токен.") from exc

        return Response(status=status.HTTP_204_NO_CONTENT)


@extend_schema_view(
    get=extend_schema(
        operation_id="users_me_retrieve",
        summary="Профиль текущего пользователя",
        responses={
            status.HTTP_200_OK: UserMeSerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
        },
    ),
    patch=extend_schema(
        operation_id="users_me_update",
        summary="Изменить профиль",
        description=(
            "Менять можно только `name` и `avatar`. Поля `phone`, `is_pro`, `iin`, "
            "`is_staff` доступны только на чтение — если их передать, они молча "
            "игнорируются."
        ),
        request=UserUpdateSerializer,
        responses={
            status.HTTP_200_OK: UserMeSerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
        },
    ),
    delete=extend_schema(
        operation_id="users_me_delete",
        summary="Удалить аккаунт",
        description=(
            "Мягкое удаление: аккаунт деактивируется, персональные данные стираются, "
            "объявления уходят в архив. Строка в БД остаётся — на неё ссылаются "
            "объявления и операции по кошельку."
        ),
        responses={
            status.HTTP_204_NO_CONTENT: None,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
        },
    ),
)
class UserMeView(RetrieveUpdateDestroyAPIView):
    """GET / PATCH / DELETE /api/v1/users/me/."""

    permission_classes = [IsAuthenticated]
    http_method_names = ["get", "patch", "delete", "head", "options"]

    def get_object(self) -> User:
        return self.request.user

    def get_serializer_class(self) -> type[BaseSerializer]:
        if self.request.method == "PATCH":
            return UserUpdateSerializer
        return UserMeSerializer

    def update(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        """После сохранения отдаём полный профиль, а не усечённый ответ формы."""
        super().update(request, *args, **kwargs)
        user = self.get_object()
        user.refresh_from_db()
        return Response(UserMeSerializer(user, context=self.get_serializer_context()).data)

    def destroy(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        anonymize_user(self.get_object())
        return Response(status=status.HTTP_204_NO_CONTENT)


class IdentityVerificationView(GenericAPIView):
    """POST — подать документы, GET — узнать статус своей заявки."""

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    serializer_class = IdentitySubmitSerializer

    def get_permissions(self) -> list:
        # Подавать документы может только исполнитель, смотреть статус — любой
        # авторизованный (после мягкого удаления pro-флага статус ещё нужен).
        if self.request.method == "POST":
            return [IsAuthenticated(), IsProUser()]
        return [IsAuthenticated()]

    def get_throttles(self) -> list:
        # Лимит на подачу документов, а не на опрос статуса.
        return [KycSubmitThrottle()] if self.request.method == "POST" else []

    @extend_schema(
        operation_id="verification_identity_status",
        summary="Статус своей заявки на верификацию",
        description=(
            "Возвращает статус последней заявки. Ссылок на загруженные файлы "
            "не содержит — они доступны только модератору по подписанной ссылке."
        ),
        responses={
            status.HTTP_200_OK: IdentityStatusSerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
        },
    )
    def get(self, request: Request) -> Response:
        verification = latest_identity(request.user)

        if verification is None:
            payload = {
                "status": "not_submitted",
                "reject_reason": "",
                "reviewed_at": None,
                "can_resubmit": True,
            }
        else:
            payload = {
                "status": verification.status,
                "reject_reason": verification.reject_reason,
                "reviewed_at": verification.reviewed_at,
                "can_resubmit": verification.can_resubmit,
            }

        return Response(IdentityStatusSerializer(payload).data)

    @extend_schema(
        operation_id="verification_identity_submit",
        summary="Подать документы на верификацию",
        description=(
            "Селфи и фото документа. Файлы попадают в приватное хранилище, "
            "EXIF вычищается фоновой задачей.\n\n"
            "409 — если предыдущая заявка ещё на проверке. Лимит: 3 подачи в сутки."
        ),
        request=IdentitySubmitSerializer,
        responses={
            status.HTTP_201_CREATED: IdentitySubmittedSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
            status.HTTP_429_TOO_MANY_REQUESTS: ErrorSerializer,
        },
    )
    def post(self, request: Request) -> Response:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        verification = submit_identity(
            request.user,
            selfie=data["selfie"],
            document_front=data.get("document_front"),
            document_back=data.get("document_back"),
            document_type=data["document_type"],
        )

        return Response(
            {
                "id": verification.pk,
                "status": verification.status,
                "submitted_at": verification.created_at,
            },
            status=status.HTTP_201_CREATED,
        )


class IdentityQueueView(ListAPIView):
    """GET /api/v1/verification/queue/ — очередь модерации."""

    permission_classes = [IsAuthenticated, CanReviewIdentity]
    serializer_class = IdentityQueueItemSerializer

    def get_queryset(self):
        requested = self.request.query_params.get("status", VerificationStatus.PENDING)
        queryset = IdentityVerification.objects.select_related("user")
        if requested in VerificationStatus.values:
            queryset = queryset.filter(status=requested)
        return queryset.order_by("-created_at")

    @extend_schema(
        operation_id="verification_queue",
        summary="Очередь заявок на верификацию",
        description=(
            "Только для сотрудников с правом `users.can_review_identity`.\n\n"
            "Для каждой заявки отдаются подписанные ссылки на файлы со сроком жизни "
            "10 минут. Каждая выдача ссылки пишется в журнал аудита."
        ),
        parameters=[
            OpenApiParameter(
                "status",
                str,
                description="Фильтр по статусу, по умолчанию pending.",
            )
        ],
        responses={
            status.HTTP_200_OK: IdentityQueueItemSerializer(many=True),
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
        },
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class IdentityReviewView(GenericAPIView):
    """POST /api/v1/verification/identity/{id}/review/ — решение по заявке."""

    permission_classes = [IsAuthenticated, CanReviewIdentity]
    serializer_class = IdentityReviewSerializer
    queryset = IdentityVerification.objects.select_related("user")

    @extend_schema(
        operation_id="verification_identity_review",
        summary="Принять решение по заявке",
        description=(
            "`approve` подтверждает личность (профиль продавца получает "
            "`is_verified`), `reject` — отклоняет с причиной. В обоих случаях "
            "файлы будут удалены через 30 дней."
        ),
        responses={
            status.HTTP_200_OK: IdentityStatusSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request, pk: int) -> Response:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        verification = self.get_object()

        review_identity(
            verification,
            staff=request.user,
            action=serializer.validated_data["action"],
            reason=serializer.validated_data.get("reason", ""),
            comment=serializer.validated_data.get("comment", ""),
            request=request,
        )

        return Response(
            IdentityStatusSerializer(
                {
                    "status": verification.status,
                    "reject_reason": verification.reject_reason,
                    "reviewed_at": verification.reviewed_at,
                    "can_resubmit": verification.can_resubmit,
                }
            ).data
        )


class IdentityFileView(APIView):
    """GET /api/v1/verification/files/{token}/ — файл по подписанной ссылке.

    Используется, когда приватное хранилище не умеет подписывать ссылки само
    (локальная разработка, файловая система). Токен живёт 10 минут и привязан
    к конкретному сотруднику: переслать ссылку коллеге не получится.
    """

    permission_classes = [IsAuthenticated, CanReviewIdentity]

    @extend_schema(exclude=True)
    def get(self, request: Request, token: str) -> FileResponse:
        try:
            payload = read_file_token(token)
        except signing.BadSignature as exc:
            raise NotFound("Ссылка недействительна или истекла.") from exc

        if payload.get("staff") != request.user.pk:
            raise NotFound("Ссылка недействительна или истекла.")

        verification = get_object_or_404(IdentityVerification, pk=payload["pk"])
        field_name = payload["field"]
        if field_name not in IdentityVerification.FILE_FIELDS:
            raise NotFound("Ссылка недействительна или истекла.")

        file_field = getattr(verification, field_name)
        if not file_field:
            raise NotFound("Файл уже удалён.")

        record_audit(
            action=AuditLog.Action.KYC_FILE_DOWNLOADED,
            request=request,
            actor=request.user,
            target_user=verification.user,
            obj=verification,
            extra={"field": field_name},
        )

        return FileResponse(file_field.open("rb"), content_type="application/octet-stream")


class SellerDetailView(APIView):
    """GET /api/v1/sellers/{user_id}/ — публичная карточка продавца."""

    permission_classes = [AllowAny]

    @extend_schema(
        operation_id="sellers_detail",
        summary="Профиль продавца",
        description=(
            "Контакты отдаются полностью только авторизованному пользователю; "
            "анониму телефон приходит замаскированным, как в карточке "
            "объявления."
        ),
        responses={
            status.HTTP_200_OK: SellerCardSerializer,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
    )
    def get(self, request: Request, user_id: int) -> Response:
        seller = get_object_or_404(public_sellers(), pk=user_id)
        card = seller_card(seller, request.user)
        return Response(SellerCardSerializer(card, context={"request": request}).data)


class SellerListingsView(ListAPIView):
    """GET /api/v1/sellers/{user_id}/listings/ — активные объявления продавца."""

    permission_classes = [AllowAny]
    serializer_class = ListingListSerializer
    pagination_class = ListingCursorPagination
    filterset_class = ListingFilterSet
    queryset = Listing.objects.none()  # для генератора схемы

    def get_ordering(self, request: Request) -> str:
        """Тот же набор сортировок, что и в каталоге."""
        requested = request.query_params.get("ordering")
        return requested if requested in ALLOWED_LISTING_ORDERINGS else DEFAULT_LISTING_ORDERING

    def get_queryset(self) -> QuerySet[Listing]:
        seller = get_object_or_404(public_sellers(), pk=self.kwargs["user_id"])
        return seller_listings(seller, self.request.user)

    @extend_schema(
        operation_id="sellers_listings",
        summary="Объявления продавца",
        description="Фильтры и пагинация — те же, что в каталоге.",
        responses={status.HTTP_200_OK: ListingListSerializer(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)


class SellerMeView(APIView):
    """GET/PATCH /api/v1/sellers/me/ — свой профиль продавца."""

    permission_classes = [IsAuthenticated, IsProUser]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    @extend_schema(
        operation_id="sellers_me",
        summary="Мой профиль продавца",
        responses={
            status.HTTP_200_OK: SellerProfileSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
        },
    )
    def get(self, request: Request) -> Response:
        profile = get_seller_profile(request.user)
        return Response(SellerProfileSerializer(profile, context={"request": request}).data)

    @extend_schema(
        operation_id="sellers_me_update",
        summary="Изменить профиль продавца",
        description=(
            "Редактируются все поля, кроме `rating`, `reviews_count` и "
            "`is_verified`: рейтинг — агрегат отзывов, а значок проверенного "
            "ставит модератор."
        ),
        request=SellerProfileSerializer,
        responses={
            status.HTTP_200_OK: SellerProfileSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
        },
    )
    def patch(self, request: Request) -> Response:
        profile = get_seller_profile(request.user)
        serializer = SellerProfileSerializer(
            profile, data=request.data, partial=True, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class SellerReviewsView(ListAPIView):
    """GET/POST /api/v1/sellers/{user_id}/reviews/"""

    serializer_class = ReviewSerializer
    pagination_class = DefaultCursorPagination
    queryset = Review.objects.none()  # для генератора схемы

    def get_permissions(self) -> list[Any]:
        if self.request.method == "POST":
            return [IsAuthenticated()]
        return [AllowAny()]

    def get_throttles(self) -> list[Any]:
        return [ReviewCreateThrottle()] if self.request.method == "POST" else []

    def get_seller(self) -> User:
        return get_object_or_404(public_sellers(), pk=self.kwargs["user_id"])

    def get_queryset(self) -> QuerySet[Review]:
        return published_reviews(self.get_seller())

    @extend_schema(
        operation_id="sellers_reviews",
        summary="Отзывы о продавце",
        description="Только опубликованные: отзывы на модерации публика не видит.",
        responses={status.HTTP_200_OK: ReviewSerializer(many=True)},
    )
    def get(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        return super().get(request, *args, **kwargs)

    @extend_schema(
        operation_id="sellers_reviews_create",
        summary="Оставить отзыв",
        description=(
            "Отзыв создаётся со статусом `pending` и уходит в очередь "
            "модерации. Один отзыв на продавца от пользователя; чтобы "
            "изменить — PATCH своего отзыва."
        ),
        request=ReviewCreateSerializer,
        responses={
            status.HTTP_201_CREATED: ReviewSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request, *args: Any, **kwargs: Any) -> Response:
        seller = self.get_seller()

        form = ReviewCreateSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        listing = None
        slug = form.validated_data.get("listing")
        if slug:
            listing = Listing.objects.filter(slug=slug, owner=seller).first()

        review = create_review(
            seller=seller,
            author=request.user,
            rating=form.validated_data["rating"],
            text=form.validated_data.get("text", ""),
            listing=listing,
        )
        return Response(ReviewSerializer(review).data, status=status.HTTP_201_CREATED)


class MyReviewView(APIView):
    """PATCH/DELETE /api/v1/reviews/{review_id}/ — свой отзыв."""

    permission_classes = [IsAuthenticated]

    def get_review(self, review_id: int, user: User) -> Review:
        review = get_object_or_404(Review.objects.select_related("seller"), pk=review_id)
        if review.author_id != user.pk:
            raise PermissionDenied("Изменять отзыв может только его автор.")
        return review

    @extend_schema(
        operation_id="reviews_update",
        summary="Изменить свой отзыв",
        description="Изменённый отзыв возвращается на модерацию.",
        request=ReviewUpdateSerializer,
        responses={
            status.HTTP_200_OK: ReviewSerializer,
            status.HTTP_403_FORBIDDEN: ErrorSerializer,
        },
    )
    def patch(self, request: Request, review_id: int) -> Response:
        review = self.get_review(review_id, request.user)

        form = ReviewUpdateSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        updated = update_review(
            review,
            rating=form.validated_data.get("rating"),
            text=form.validated_data.get("text"),
        )
        return Response(ReviewSerializer(updated).data)

    @extend_schema(
        operation_id="reviews_delete",
        summary="Удалить свой отзыв",
        responses={status.HTTP_204_NO_CONTENT: None},
    )
    def delete(self, request: Request, review_id: int) -> Response:
        delete_review(self.get_review(review_id, request.user))
        return Response(status=status.HTTP_204_NO_CONTENT)


class SellerVerificationView(APIView):
    """GET/POST /api/v1/sellers/me/verification/ — документы агентства."""

    permission_classes = [IsAuthenticated, IsProUser]
    parser_classes = [MultiPartParser, FormParser]

    @extend_schema(
        operation_id="sellers_verification_status",
        summary="Статус проверки продавца",
        responses={status.HTTP_200_OK: SellerVerificationSerializer(many=True)},
    )
    def get(self, request: Request) -> Response:
        applications = SellerVerification.objects.filter(seller=request.user)
        return Response(SellerVerificationSerializer(applications, many=True).data)

    @extend_schema(
        operation_id="sellers_verification_submit",
        summary="Подать документы агентства",
        description=(
            "Загружает документы юрлица и заводит заявку модератору. "
            "Имена файлов в хранилище не сохраняются."
        ),
        request=SellerVerificationRequestSerializer,
        responses={
            status.HTTP_201_CREATED: SellerVerificationSerializer,
            status.HTTP_400_BAD_REQUEST: ErrorSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request) -> Response:
        form = SellerVerificationRequestSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        verification = submit_seller_verification(request.user, form.validated_data["documents"])
        return Response(
            SellerVerificationSerializer(verification).data,
            status=status.HTTP_201_CREATED,
        )


class ListingContactView(APIView):
    """POST /api/v1/listings/{slug}/contact/ — раскрытие телефона продавца."""

    permission_classes = [IsAuthenticated]
    throttle_classes = [ContactRevealThrottle]

    @extend_schema(
        operation_id="listings_contact",
        summary="Показать контакты продавца",
        description=(
            "Отдаёт телефон целиком, засчитывает показ в статистику объявления "
            "и пишет событие для антифрода. Ограничение — 30 раскрытий в час "
            "на пользователя."
        ),
        request=None,
        responses={
            status.HTTP_200_OK: ContactRevealSerializer,
            status.HTTP_401_UNAUTHORIZED: ErrorSerializer,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
            status.HTTP_429_TOO_MANY_REQUESTS: ErrorSerializer,
        },
    )
    def post(self, request: Request, slug: str) -> Response:
        listing = get_object_or_404(
            Listing.objects.select_related("owner", "owner__seller_profile").filter(
                status=ListingStatus.ACTIVE
            ),
            slug=slug,
        )
        contacts = reveal_contact(listing, request.user, client_ip(request))
        return Response(ContactRevealSerializer(contacts).data)


class DataExportView(APIView):
    """POST/GET /api/v1/users/me/export/ — выгрузка персональных данных."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="users_me_export_status",
        summary="Статус выгрузки данных",
        responses={status.HTTP_200_OK: DataExportSerializer(many=True)},
    )
    def get(self, request: Request) -> Response:
        exports = DataExport.objects.filter(user=request.user)[:10]
        return Response(DataExportSerializer(exports, many=True, context={"request": request}).data)

    @extend_schema(
        operation_id="users_me_export",
        summary="Запросить выгрузку своих данных",
        description=(
            "Собирает профиль, объявления, избранное, историю просмотров и "
            "операции по кошельку в один JSON. Файл лежит в приватном "
            "хранилище и доступен по подписанной ссылке 24 часа. "
            "Не чаще одной выгрузки в сутки."
        ),
        request=None,
        responses={
            status.HTTP_202_ACCEPTED: DataExportSerializer,
            status.HTTP_409_CONFLICT: ErrorSerializer,
        },
    )
    def post(self, request: Request) -> Response:
        export = request_data_export(request.user, request)
        return Response(
            DataExportSerializer(export, context={"request": request}).data,
            status=status.HTTP_202_ACCEPTED,
        )


class DataExportFileView(APIView):
    """GET /api/v1/users/me/export/{token}/ — скачивание выгрузки."""

    permission_classes = [AllowAny]
    authentication_classes: list = []

    @extend_schema(
        operation_id="users_me_export_file",
        summary="Скачать выгрузку по подписанной ссылке",
        description="Ссылка живёт 24 часа и привязана к пользователю, который её запросил.",
        responses={
            (status.HTTP_200_OK, "application/json"): OpenApiTypes.BINARY,
            status.HTTP_404_NOT_FOUND: ErrorSerializer,
        },
        auth=[],
    )
    def get(self, request: Request, token: str) -> FileResponse:
        try:
            payload = read_export_token(token)
        except signing.BadSignature as exc:
            raise NotFound("Ссылка недействительна или истекла.") from exc

        export = get_object_or_404(
            DataExport.objects.select_related("user"),
            pk=payload["export"],
            user_id=payload["user"],
        )
        if not export.is_ready:
            raise NotFound("Выгрузка ещё не готова.")

        record_audit(
            action=AuditLog.Action.DATA_EXPORTED,
            request=request,
            actor=export.user,
            target_user=export.user,
            obj=export,
            extra={"downloaded": True},
        )
        return FileResponse(
            export.file.open("rb"),
            as_attachment=True,
            filename=f"house-kgz-export-{export.pk}.json",
            content_type="application/json",
        )


class ConsentView(APIView):
    """GET/POST /api/v1/users/me/consents/ — согласия пользователя."""

    permission_classes = [IsAuthenticated]

    @extend_schema(
        operation_id="users_me_consents",
        summary="Мои согласия",
        responses={status.HTTP_200_OK: UserConsentSerializer(many=True)},
    )
    def get(self, request: Request) -> Response:
        return Response(UserConsentSerializer(request.user.consents.all(), many=True).data)

    @extend_schema(
        operation_id="users_me_consent_grant",
        summary="Дать или отозвать согласие",
        description=(
            "Каждое решение — новая запись с версией документа, временем и "
            "адресом: закон требует уметь показать, какую именно редакцию "
            "человек принял."
        ),
        request=ConsentRequestSerializer,
        responses={status.HTTP_201_CREATED: UserConsentSerializer},
    )
    def post(self, request: Request) -> Response:
        form = ConsentRequestSerializer(data=request.data)
        form.is_valid(raise_exception=True)

        consent = record_consent(
            request.user,
            document_version=form.validated_data["document_version"],
            consent_type=form.validated_data["consent_type"],
            granted=form.validated_data["granted"],
            request=request,
        )
        return Response(UserConsentSerializer(consent).data, status=status.HTTP_201_CREATED)
