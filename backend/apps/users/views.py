"""Эндпоинты аутентификации и профиля пользователя."""

from typing import Any

from django.conf import settings
from django.core import signing
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema, extend_schema_view
from rest_framework import status
from rest_framework.exceptions import NotFound
from rest_framework.generics import GenericAPIView, ListAPIView, RetrieveUpdateDestroyAPIView
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.serializers import BaseSerializer
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from apps.common.audit import record_audit
from apps.common.exceptions import ApiValidationError
from apps.common.models import AuditLog
from apps.common.serializers import ErrorSerializer
from apps.users.kyc import read_file_token
from apps.users.models import IdentityVerification, User, VerificationStatus
from apps.users.permissions import CanReviewIdentity, IsProUser
from apps.users.serializers import (
    AuthTokensSerializer,
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
    UserMeSerializer,
    UserUpdateSerializer,
)
from apps.users.services import (
    anonymize_user,
    authenticate_pro,
    issue_otp,
    issue_tokens,
    latest_identity,
    register_pro,
    review_identity,
    submit_identity,
    verify_otp,
)
from apps.users.throttling import (
    KycSubmitThrottle,
    OtpIpThrottle,
    OtpPhoneHourlyThrottle,
    OtpPhoneResendThrottle,
    PasswordLoginIpThrottle,
    PasswordLoginPhoneThrottle,
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
            "создаётся автоматически — имя берётся из поля `name`.\n\n"
            "Неверный код: 400 «Неверный код» и `details.attempts_left`. "
            "После пяти неудачных попыток код сжигается."
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
    """POST /api/v1/auth/password/login/ — вход исполнителя по паролю."""

    permission_classes = [AllowAny]
    authentication_classes: list = []
    throttle_classes = [PasswordLoginPhoneThrottle, PasswordLoginIpThrottle]
    serializer_class = PasswordLoginSerializer

    @extend_schema(
        operation_id="auth_password_login",
        summary="Вход по паролю (только pro)",
        description=(
            "Доступен подтверждённым исполнителям. При неверных данных — 401 с общим "
            "сообщением: по ответу нельзя понять, зарегистрирован ли номер.\n\n"
            "Лимиты: 10 попыток в час на номер, 30 — с одного IP."
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

        user = authenticate_pro(
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
