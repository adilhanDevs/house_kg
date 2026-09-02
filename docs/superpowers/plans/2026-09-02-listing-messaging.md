# Listing Messaging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить полностью интегрированную текстовую переписку покупателя с продавцом по объявлению, список диалогов, непрочитанные сообщения, уведомления и рабочий звонок.

**Architecture:** Django-приложение `apps.messaging` хранит диалоги и сообщения, а REST API разделяет выборки (`selectors.py`) и транзакционную бизнес-логику (`services.py`). Flutter использует типизированные модели, `MessagingRepository` и независимый от транспорта `ChatController`; первый релиз получает новые сообщения polling-запросом, а позже тот же контроллер сможет принимать WebSocket-события.

**Tech Stack:** Django 5, Django REST Framework, PostgreSQL 16, pytest/pytest-django/factory-boy, Flutter/Dart, `http`, `uuid`, `url_launcher`, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-02-listing-messaging-design.md`

## Global Constraints

- Все API-маршруты находятся под `/api/v1/`, используют snake_case и единый error envelope проекта.
- Все messaging endpoint'ы требуют JWT; чужой диалог всегда отвечает `404`.
- Бизнес-логика находится в `services.py`, оптимизированные выборки — в `selectors.py`, не во views.
- Списки используют cursor pagination и не создают N+1 запросы.
- Текст сообщения после `trim` содержит от 1 до 2000 символов.
- Повторный POST с тем же `(sender, client_message_id)` не создаёт второе сообщение или уведомление.
- Первый релиз поддерживает только текст; вложения, WebSocket и онлайн-статусы не добавляются.
- Существующие production-настройки сервера не меняются вне необходимых app/throttle регистраций.
- Любое изменение поведения выполняется RED → GREEN → REFACTOR.
- Backend коммитится и пушится из `backend/`; Flutter и общая документация — из корневого репозитория.

---

### Task 1: Модели диалогов и миграция

**Files:**
- Create: `backend/apps/messaging/__init__.py`
- Create: `backend/apps/messaging/apps.py`
- Create: `backend/apps/messaging/models.py`
- Create: `backend/apps/messaging/admin.py`
- Create: `backend/apps/messaging/migrations/__init__.py`
- Create: `backend/apps/messaging/migrations/0001_initial.py`
- Modify: `backend/config/settings.py`
- Modify: `backend/tests/factories.py`
- Create: `backend/tests/test_messaging_models.py`

**Interfaces:**
- Produces: `Conversation`, `Message`, `ConversationFactory`, `MessageFactory`.
- `Conversation` exposes `peer_for(user)` and `read_at_for(user)`; both reject non-participants.

- [ ] **Step 1: Write failing model tests**

```python
def test_one_conversation_per_buyer_and_listing(db):
    conversation = ConversationFactory()
    with pytest.raises(IntegrityError):
        ConversationFactory(
            listing=conversation.listing,
            buyer=conversation.buyer,
            seller=conversation.seller,
        )


def test_client_message_id_is_unique_per_sender(db):
    message = MessageFactory()
    with pytest.raises(IntegrityError):
        MessageFactory(
            conversation=message.conversation,
            sender=message.sender,
            client_message_id=message.client_message_id,
        )
```

- [ ] **Step 2: Verify RED**

Run: `cd backend && python -m pytest tests/test_messaging_models.py -v --no-cov`

Expected: collection fails because `apps.messaging` does not exist.

- [ ] **Step 3: Implement minimal models**

Use `UUIDModel, TimeStampedModel` and define these constraints/indexes:

```python
class Conversation(UUIDModel, TimeStampedModel):
    listing = models.ForeignKey(
        "catalog.Listing", null=True, blank=True, on_delete=models.SET_NULL,
        related_name="conversations",
    )
    buyer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                              related_name="buyer_conversations")
    seller = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                               related_name="seller_conversations")
    listing_slug = models.SlugField(max_length=220)
    listing_title = models.CharField(max_length=255)
    listing_price = models.DecimalField(max_digits=12, decimal_places=2)
    listing_currency = models.CharField(max_length=3)
    listing_cover_url = models.CharField(max_length=500, blank=True)
    last_message_at = models.DateTimeField(db_index=True)
    buyer_last_read_at = models.DateTimeField(null=True, blank=True)
    seller_last_read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["listing", "buyer", "seller"],
                name="messaging_unique_listing_participants",
            ),
            models.CheckConstraint(
                condition=~models.Q(buyer=models.F("seller")),
                name="messaging_buyer_is_not_seller",
            ),
        ]
        indexes = [
            models.Index(fields=["buyer", "-last_message_at"], name="msg_buyer_recent_idx"),
            models.Index(fields=["seller", "-last_message_at"], name="msg_seller_recent_idx"),
        ]


class Message(UUIDModel, TimeStampedModel):
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE,
                                     related_name="messages")
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                               related_name="sent_messages")
    text = models.CharField(max_length=2000)
    client_message_id = models.UUIDField()

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=["sender", "client_message_id"],
                name="messaging_unique_client_message",
            )
        ]
        indexes = [
            models.Index(fields=["conversation", "-created_at"], name="msg_conv_recent_idx")
        ]
```

Set `last_message_at=timezone.now` as a callable default, register `apps.messaging` in
`LOCAL_APPS`, create the migration with `makemigrations messaging`, and add read-only
admin pages with no message text in `list_display` or search fields.

- [ ] **Step 4: Verify GREEN and migration integrity**

Run:

```bash
cd backend
python manage.py makemigrations --check
python manage.py migrate --plan
python -m pytest tests/test_messaging_models.py -v --no-cov
```

Expected: no uncommitted migrations; model tests pass.

- [ ] **Step 5: Commit backend model layer**

```bash
cd backend
git add apps/messaging config/settings.py tests/factories.py tests/test_messaging_models.py
git commit -m "feat(messaging): добавить модели диалогов"
```

---

### Task 2: Открытие диалога и список разговоров

**Files:**
- Create: `backend/apps/messaging/selectors.py`
- Create: `backend/apps/messaging/services.py`
- Create: `backend/apps/messaging/serializers.py`
- Create: `backend/apps/messaging/pagination.py`
- Create: `backend/apps/messaging/views.py`
- Create: `backend/apps/messaging/urls.py`
- Modify: `backend/config/urls.py`
- Create: `backend/tests/test_conversations_api.py`

**Interfaces:**
- Produces: `open_conversation(*, user, listing_slug) -> tuple[Conversation, bool]`.
- Produces: `conversations_for(user) -> QuerySet[Conversation]` and
  `conversation_for_participant(*, user, conversation_id) -> Conversation`.
- API: `POST/GET /api/v1/conversations/`, `GET /api/v1/conversations/{uuid}/`.

- [ ] **Step 1: Write failing API tests**

Cover anonymous `401`, active listing `201`, repeated open `200` with same UUID,
self-chat `409`, inactive listing `404`, stranger detail `404`, both participants detail
`200`, newest-first ordering, correct peer/snapshot/unread fields, and query stability.

```python
def test_opening_same_listing_returns_existing_conversation(client_for):
    listing = ListingFactory(status=ListingStatus.ACTIVE)
    buyer = UserFactory()
    client = client_for(buyer)
    first = client.post(reverse("messaging:conversation-list"), {"listing_slug": listing.slug})
    second = client.post(reverse("messaging:conversation-list"), {"listing_slug": listing.slug})
    assert first.status_code == 201
    assert second.status_code == 200
    assert first.data["id"] == second.data["id"]
    assert Conversation.objects.count() == 1
```

- [ ] **Step 2: Verify RED**

Run: `cd backend && python -m pytest tests/test_conversations_api.py -v --no-cov`

Expected: reverse lookup for `messaging:conversation-list` fails.

- [ ] **Step 3: Implement selectors and transactional service**

`open_conversation` must fetch only an `ACTIVE` listing, reject `listing.owner_id == user.id`
with `ConflictError("Нельзя написать самому себе.")`, snapshot title/price/currency/cover,
and use `transaction.atomic()` plus `get_or_create`. On a concurrent `IntegrityError`, fetch
the winning row instead of returning `500`.

`conversations_for` must use one queryset with participant filter, `select_related` for
buyer/seller/listing, `Prefetch`/subquery for the latest message, and an unread annotation
relative to the participant's own read timestamp.

- [ ] **Step 4: Implement serializers and views**

```python
class ConversationCreateSerializer(serializers.Serializer):
    listing_slug = serializers.SlugField(max_length=220)


class ConversationListCreateView(ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    pagination_class = ConversationCursorPagination

    def post(self, request):
        incoming = ConversationCreateSerializer(data=request.data)
        incoming.is_valid(raise_exception=True)
        conversation, created = open_conversation(
            user=request.user,
            listing_slug=incoming.validated_data["listing_slug"],
        )
        return Response(
            ConversationSerializer(conversation, context={"request": request}).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )
```

Use `ConversationCursorPagination.ordering = "-last_message_at"`. The serializer chooses
the peer from `request.user`, never accepts participant IDs from input, and emits only the
snapshot fields needed by Flutter.

- [ ] **Step 5: Verify GREEN and query count**

Run: `cd backend && python -m pytest tests/test_conversations_api.py -v --no-cov`

Expected: all conversation tests pass; adding ten conversations does not increase the
number of list queries.

- [ ] **Step 6: Commit conversation API**

```bash
cd backend
git add apps/messaging config/urls.py tests/test_conversations_api.py
git commit -m "feat(messaging): добавить API диалогов"
```

---

### Task 3: Отправка, polling и прочтение сообщений

**Files:**
- Modify: `backend/apps/messaging/services.py`
- Modify: `backend/apps/messaging/selectors.py`
- Modify: `backend/apps/messaging/serializers.py`
- Modify: `backend/apps/messaging/views.py`
- Modify: `backend/apps/messaging/urls.py`
- Modify: `backend/apps/common/throttling.py`
- Modify: `backend/config/settings.py`
- Create: `backend/tests/test_messages_api.py`
- Modify: `backend/tests/test_security.py`

**Interfaces:**
- Produces: `send_message(*, user, conversation, text, client_message_id) -> tuple[Message, bool]`.
- Produces: `mark_conversation_read(*, user, conversation, last_message_id) -> int`.
- API: GET/POST messages and POST read exactly as defined in the spec.

- [ ] **Step 1: Write failing message tests**

Cover blank/2001-character validation, both participants, stranger `404`, sender not matching
the authenticated user, duplicate client UUID, chronological incremental polling, pagination,
`last_message_at`, unread count, read-up-to semantics, and throttle registration.

```python
def test_retry_does_not_duplicate_message_or_side_effects(client_for):
    conversation = ConversationFactory()
    client = client_for(conversation.buyer)
    payload = {"text": "Когда можно посмотреть?", "client_message_id": str(uuid.uuid4())}
    first = client.post(messages_url(conversation), payload)
    second = client.post(messages_url(conversation), payload)
    assert first.status_code == 201
    assert second.status_code == 200
    assert first.data["id"] == second.data["id"]
    assert conversation.messages.count() == 1
```

- [ ] **Step 2: Verify RED**

Run: `cd backend && python -m pytest tests/test_messages_api.py tests/test_security.py::test_every_throttle_scope_has_a_rate -v --no-cov`

- [ ] **Step 3: Implement transactional message services**

Lock the conversation with `select_for_update`, verify membership, normalize text with
`.strip()`, then `get_or_create(sender=user, client_message_id=...)`. Update
`last_message_at` only for a newly created message. For `read`, lock the conversation,
verify that `last_message_id` belongs to it, and set the participant's read timestamp to
`max(current_value, message.created_at)`.

For `after=<uuid>`, resolve the reference inside the participant's conversation and return
messages with `created_at__gte=reference.created_at`, excluding the reference itself. This
may safely resend a same-microsecond sibling but must never omit one; Flutter deduplicates by ID.

- [ ] **Step 4: Add message throttle and API views**

```python
class MessageSendThrottle(UserScopedThrottle):
    scope = "message_send"
```

Add `"message_send": env.str("MESSAGE_SEND_THROTTLE", default="30/min")` to DRF rates
and attach the throttle only to POST message requests. Do not throttle GET polling with this
scope.

- [ ] **Step 5: Verify GREEN**

Run: `cd backend && python -m pytest tests/test_messages_api.py tests/test_security.py::test_every_throttle_scope_has_a_rate -v --no-cov`

- [ ] **Step 6: Commit messaging behavior**

```bash
cd backend
git add apps/messaging apps/common/throttling.py config/settings.py tests/test_messages_api.py tests/test_security.py
git commit -m "feat(messaging): добавить сообщения и прочтение"
```

---

### Task 4: Уведомления о новых сообщениях

**Files:**
- Modify: `backend/apps/notifications/models.py`
- Modify: `backend/apps/notifications/serializers.py`
- Create: `backend/apps/notifications/migrations/0004_new_message_notifications.py`
- Modify: `backend/apps/messaging/services.py`
- Create: `backend/tests/test_message_notifications.py`
- Modify: `backend/tests/test_notifications.py`

**Interfaces:**
- Adds `NotificationType.NEW_MESSAGE = "new_message"`.
- Adds `NotificationSettings.new_message_enabled` and mapping in `TYPE_FIELDS`.
- A newly stored message creates exactly one notification for the peer.

- [ ] **Step 1: Write failing notification tests**

```python
def test_new_message_notifies_peer_once(client_for, django_capture_on_commit_callbacks):
    conversation = ConversationFactory()
    payload = {"text": "Здравствуйте", "client_message_id": str(uuid.uuid4())}
    with django_capture_on_commit_callbacks(execute=False):
        first = client_for(conversation.buyer).post(messages_url(conversation), payload)
        second = client_for(conversation.buyer).post(messages_url(conversation), payload)
    assert first.status_code == 201
    assert second.status_code == 200
    notification = Notification.objects.get(user=conversation.seller)
    assert notification.type == NotificationType.NEW_MESSAGE
    assert notification.payload["conversation_id"] == str(conversation.id)
```

Also assert that a push-enqueue failure after commit does not roll back the message or its
notification row, and that `new_message_enabled=False` prevents push according to the existing
notification task contract. A database failure while creating the notification is not swallowed.

- [ ] **Step 2: Verify RED**

Run: `cd backend && python -m pytest tests/test_message_notifications.py -v --no-cov`

- [ ] **Step 3: Implement notification type and migration**

Add the enum, settings field, serializer field and `TYPE_FIELDS` mapping. In `send_message`,
call `notifications.services.notify` only when `created is True`, after the database writes
are valid. Payload:

```python
{
    "conversation_id": str(conversation.id),
    "listing_slug": conversation.listing_slug,
    "sender_id": user.pk,
}
```

Title is the sender's non-empty name or `"Новое сообщение"`; body is truncated to 140
characters for the notification preview. Catch and log only the push-enqueue boundary already
handled by `notify`; do not hide database errors creating the notification.

- [ ] **Step 4: Verify GREEN and migration**

Run:

```bash
cd backend
python manage.py makemigrations --check
python -m pytest tests/test_message_notifications.py tests/test_notifications.py -v --no-cov
```

- [ ] **Step 5: Commit notification integration**

```bash
cd backend
git add apps/notifications apps/messaging/services.py tests/test_message_notifications.py tests/test_notifications.py
git commit -m "feat(messaging): уведомлять о новых сообщениях"
```

---

### Task 5: Backend contract and regression verification

**Files:**
- Modify: `backend/apps/messaging/views.py`
- Modify: `backend/apps/messaging/serializers.py`
- Create: `backend/tests/test_messaging_schema.py`

**Interfaces:**
- Produces complete drf-spectacular schema for all six routes.
- No production behavior beyond schema metadata.

- [ ] **Step 1: Add failing schema assertions**

Assert that generated OpenAPI contains all messaging paths, JWT security, request schemas,
`200/201/400/401/404/409/429` responses where applicable, and UUID path parameters.

- [ ] **Step 2: Verify RED**

Run: `cd backend && python -m pytest tests/test_messaging_schema.py -v --no-cov`

- [ ] **Step 3: Add explicit `extend_schema` declarations and response serializers**

Do not use anonymous inline dictionaries where a named serializer is reused by Flutter's
contract tests. Keep the runtime response unchanged.

- [ ] **Step 4: Verify backend slice and lint**

Run:

```bash
cd backend
python manage.py check
python manage.py makemigrations --check
python -m pytest tests/test_messaging_models.py tests/test_conversations_api.py tests/test_messages_api.py tests/test_message_notifications.py tests/test_messaging_schema.py -v --no-cov
ruff check apps/messaging apps/notifications tests/test_messaging*.py tests/test_conversations_api.py tests/test_messages_api.py tests/test_message_notifications.py
```

- [ ] **Step 5: Commit schema coverage**

```bash
cd backend
git add apps/messaging tests/test_messaging_schema.py
git commit -m "test(messaging): зафиксировать API контракт"
```

---

### Task 6: Flutter domain models and repository

**Files:**
- Create: `flutter_app/lib/data/messaging_models.dart`
- Create: `flutter_app/lib/data/messaging_repository.dart`
- Modify: `flutter_app/lib/data/api_client.dart`
- Create: `flutter_app/test/messaging_models_test.dart`
- Create: `flutter_app/test/messaging_repository_test.dart`

**Interfaces:**
- Produces immutable `ChatPeer`, `ListingSnapshot`, `ConversationSummary`, `ChatMessage`.
- Produces `MessagingRepository` methods matching every backend route.
- `sendMessage` accepts caller-provided `clientMessageId`; repository never regenerates it.

- [ ] **Step 1: Write failing JSON model tests**

Test complete JSON, nullable listing FK with preserved snapshot, missing avatar, decimal price
as string, UTC dates, last message absent, unread count and equality by UUID.

- [ ] **Step 2: Verify RED**

Run: `cd flutter_app && flutter test test/messaging_models_test.dart`

- [ ] **Step 3: Implement immutable models**

Each `fromJson` validates required IDs and dates but tolerates optional peer/avatar/listing
fields. Keep network state out of `ChatMessage`; add a separate UI-only pending type in Task 7.

- [ ] **Step 4: Write failing repository contract tests**

Use `MockClient` to assert method, path, Authorization propagation, JSON fields, cursor/after
query parameters, and parsing for:

```dart
Future<ConversationSummary> openConversation(String listingSlug);
Future<ConversationPage> getConversations({String? cursor});
Future<ConversationSummary> getConversation(String id);
Future<MessagePage> getMessages(String conversationId, {String? cursor, String? after});
Future<ChatMessage> sendMessage(String conversationId,
    {required String text, required String clientMessageId});
Future<int> markRead(String conversationId, String lastMessageId);
Future<String> revealListingPhone(String listingSlug);
```

- [ ] **Step 5: Verify RED, implement repository, verify GREEN**

Run before and after implementation:

```bash
cd flutter_app
flutter test test/messaging_repository_test.dart
```

Repository converts existing `ApiException`/`NetworkException`; it does not catch and replace
their status/code/message.

- [ ] **Step 6: Commit Flutter data layer**

```bash
git add flutter_app/lib/data/api_client.dart flutter_app/lib/data/messaging_models.dart flutter_app/lib/data/messaging_repository.dart flutter_app/test/messaging_models_test.dart flutter_app/test/messaging_repository_test.dart
git commit -m "feat(messaging): добавить Flutter API переписки"
```

---

### Task 7: ChatController with optimistic send and polling lifecycle

**Files:**
- Create: `flutter_app/lib/app/chat_controller.dart`
- Create: `flutter_app/test/chat_controller_test.dart`

**Interfaces:**
- Produces `ChatController extends ChangeNotifier`.
- Constructor accepts `MessagingRepository`, conversation ID, `Uuid` and injectable polling
  interval/timer factory for deterministic tests.
- Exposes immutable messages, load/send/read states, `start()`, `stop()`, `send(text)`,
  `retry(localId)`, `loadOlder()`.

- [ ] **Step 1: Write failing controller tests**

Cover initial load, deduplication by server UUID, optimistic pending bubble, successful replace,
failed state, retry with the exact same `client_message_id`, no overlapping poll requests,
five-second polling only while started, cancellation on dispose, and read receipt for the latest
peer message.

```dart
test('retry uses the same client message id', () async {
  repository.failNextSend = true;
  await controller.send('Когда можно посмотреть?');
  final failed = controller.messages.single;
  await controller.retry(failed.localId);
  expect(repository.sentClientIds, [failed.clientMessageId, failed.clientMessageId]);
});
```

- [ ] **Step 2: Verify RED**

Run: `cd flutter_app && flutter test test/chat_controller_test.dart`

- [ ] **Step 3: Implement minimal controller**

Use `Timer.periodic` behind an injected scheduler, guard polling with `_pollInFlight`, merge by
server ID, and keep pending objects in a private UI model with `sending/sent/failed`. `dispose`
must cancel the timer before `super.dispose()`.

- [ ] **Step 4: Verify GREEN**

Run: `cd flutter_app && flutter test test/chat_controller_test.dart`

- [ ] **Step 5: Commit controller**

```bash
git add flutter_app/lib/app/chat_controller.dart flutter_app/test/chat_controller_test.dart
git commit -m "feat(messaging): добавить контроллер чата"
```

---

### Task 8: Экраны списка диалогов и чата

**Files:**
- Create: `flutter_app/lib/ui/pages/messages_page.dart`
- Create: `flutter_app/lib/ui/pages/chat_page.dart`
- Create: `flutter_app/lib/ui/widgets/chat_bubble.dart`
- Create: `flutter_app/lib/ui/widgets/conversation_tile.dart`
- Create: `flutter_app/lib/ui/widgets/chat_listing_header.dart`
- Create: `flutter_app/test/messages_page_test.dart`
- Create: `flutter_app/test/chat_page_test.dart`

**Interfaces:**
- `MessagesPage(repository: ...)` displays loading/empty/error/content and cursor loading.
- `ChatPage(args: ChatPageArgs, repository: ...)` owns and disposes `ChatController`.
- Widget files depend on view data, not directly on `ListingApiClient`.

- [ ] **Step 1: Write failing MessagesPage widget tests**

Assert Russian empty state, retry after network error, peer name/avatar fallback, listing title,
last-message preview, unread badge, date formatting, tap navigation and no overflow at 320px
width with text scale 1.5.

- [ ] **Step 2: Verify RED and implement MessagesPage**

Run before and after: `cd flutter_app && flutter test test/messages_page_test.dart`

Use existing House KGZ page/accent colors and `SafeArea`; do not copy pixel-positioned Figma
stage code into the dynamic list.

- [ ] **Step 3: Write failing ChatPage widget tests**

Assert listing header, own/peer bubble alignment, multiline wrapping, composer disabled for
blank text, keyboard inset, send loading, failed bubble with «Повторить», pagination at top,
controller start on route visibility and stop/dispose on exit.

- [ ] **Step 4: Verify RED and implement ChatPage/widgets**

Run before and after: `cd flutter_app && flutter test test/chat_page_test.dart`

Use `SafeArea(top: false)`, bottom padding from `MediaQuery.viewInsets.bottom`, `ListView`
with stable keys by server/local ID, and a 2000-character input limit.

- [ ] **Step 5: Commit Flutter UI**

```bash
git add flutter_app/lib/ui/pages/messages_page.dart flutter_app/lib/ui/pages/chat_page.dart flutter_app/lib/ui/widgets/chat_bubble.dart flutter_app/lib/ui/widgets/conversation_tile.dart flutter_app/lib/ui/widgets/chat_listing_header.dart flutter_app/test/messages_page_test.dart flutter_app/test/chat_page_test.dart
git commit -m "feat(messaging): добавить экраны переписки"
```

---

### Task 9: Интеграция объявления, авторизации, звонка, профиля и уведомлений

**Files:**
- Modify: `flutter_app/lib/app/routes.dart`
- Modify: `flutter_app/lib/app/app.dart`
- Modify: `flutter_app/lib/app/app_state.dart`
- Modify: `flutter_app/lib/ui/pages/listing_page.dart`
- Modify: `flutter_app/lib/ui/pages/profile_page.dart`
- Modify: `flutter_app/lib/ui/pages/pro_profile_page.dart`
- Modify: `flutter_app/lib/ui/pages/notifications_page.dart`
- Create: `flutter_app/lib/ui/widgets/listing_contact_bar.dart`
- Create: `flutter_app/test/listing_contact_flow_test.dart`
- Create: `flutter_app/test/messaging_navigation_test.dart`

**Interfaces:**
- Adds `Routes.messages` and `Routes.chat` plus typed `ChatPageArgs`.
- `AppState` stores one in-memory `PendingAuthAction` and consumes it exactly once after login.
- `ListingContactBar` accepts callbacks and owner/auth/loading state; it does not call API itself.

- [ ] **Step 1: Write failing navigation and auth-resume tests**

Cover authenticated open-chat, guest redirect to welcome, continuation after password/OTP login,
one-time intent consumption, owner suppression, profile links for buyer and pro, notification
payload navigation, and back behavior.

- [ ] **Step 2: Verify RED**

Run: `cd flutter_app && flutter test test/messaging_navigation_test.dart`

- [ ] **Step 3: Implement typed routes and pending auth action**

Represent the action explicitly:

```dart
sealed class PendingAuthAction {
  const PendingAuthAction();
}

final class OpenListingChatAfterAuth extends PendingAuthAction {
  const OpenListingChatAfterAuth(this.listingSlug);
  final String listingSlug;
}
```

After `_saveTokens`, UI consumes the pending action and uses `pushNamedAndRemoveUntil` only as
needed to avoid duplicate welcome/code pages. Never persist the action or conversation content
to SharedPreferences.

- [ ] **Step 4: Write failing contact-bar and phone tests**

Assert «Написать» and call semantics, loading lock, API contact endpoint, `tel:` URI, unavailable
launcher error Snackbar, anonymous auth gate, and absence for the listing owner.

- [ ] **Step 5: Verify RED and implement contact integration**

Run before and after: `cd flutter_app && flutter test test/listing_contact_flow_test.dart`

Replace `_onCallPressed` placeholder with `revealListingPhone` followed by
`launchUrl(Uri(scheme: 'tel', path: phone))`. Catch `ApiException`/`NetworkException` and show
their useful Russian message. Disable both buttons while an action is running.

- [ ] **Step 6: Run focused Flutter suite**

```bash
cd flutter_app
flutter test test/messaging_models_test.dart test/messaging_repository_test.dart test/chat_controller_test.dart test/messages_page_test.dart test/chat_page_test.dart test/listing_contact_flow_test.dart test/messaging_navigation_test.dart
flutter analyze
```

- [ ] **Step 7: Commit integration**

```bash
git add flutter_app/lib/app flutter_app/lib/ui/pages/listing_page.dart flutter_app/lib/ui/pages/profile_page.dart flutter_app/lib/ui/pages/pro_profile_page.dart flutter_app/lib/ui/pages/notifications_page.dart flutter_app/lib/ui/widgets/listing_contact_bar.dart flutter_app/test/listing_contact_flow_test.dart flutter_app/test/messaging_navigation_test.dart
git commit -m "feat(messaging): связать чат с объявлениями"
```

---

### Task 10: Полная проверка, push и production rollout

**Files:**
- No new product files expected.
- Update only tests or implementation directly responsible for a reproduced regression.

**Interfaces:**
- Produces pushed commits in both repositories and migrated production database.
- Existing rows are preserved; rollout only creates messaging tables and notification setting.

- [ ] **Step 1: Verify local repository boundaries**

Run:

```bash
git status --short
git -C backend status --short
git diff --check
git -C backend diff --check
```

Stage only messaging-related paths; preserve all unrelated user changes already present in the
dirty parent worktree.

- [ ] **Step 2: Run complete local verification**

```bash
cd backend
python manage.py check
python manage.py makemigrations --check
python -m pytest --no-cov
ruff check apps tests config

cd ../flutter_app
flutter test
flutter analyze
```

If an unrelated pre-existing failure remains, record its exact test and prove the messaging
slice passes; do not weaken assertions or skip tests.

- [ ] **Step 3: Push in deployment order**

```bash
cd backend
git push origin main
cd ..
git push origin main
```

Backend is pushed first so a newly built client never targets missing endpoints.

- [ ] **Step 4: Snapshot server state and pull**

```bash
ssh root@139.59.224.34 'cd /root/house-backend && git status --short --branch && git log -1 --oneline'
ssh root@139.59.224.34 'cd /root/house-backend && git pull --ff-only origin main'
```

Stop if the server worktree is dirty or pull is not fast-forward; do not reset production files.

- [ ] **Step 5: Validate and migrate existing database**

```bash
ssh root@139.59.224.34 'cd /root/house-backend && /root/venv/bin/python manage.py check && /root/venv/bin/python manage.py showmigrations messaging notifications && /root/venv/bin/python manage.py migrate --plan'
ssh root@139.59.224.34 'cd /root/house-backend && /root/venv/bin/python manage.py migrate --noinput'
```

Then verify migration rows and counts without exposing message text or user phones.

- [ ] **Step 6: Run server tests and restart safely**

Temporarily grant only the DB permission required by pytest to create its test database, run the
focused messaging tests, then revoke it even if tests fail:

```bash
ssh root@139.59.224.34 'sudo -u postgres psql -c "ALTER ROLE quantum_user CREATEDB;"'
ssh root@139.59.224.34 'cd /root/house-backend && /root/venv/bin/python -m pytest tests/test_messaging_models.py tests/test_conversations_api.py tests/test_messages_api.py tests/test_message_notifications.py tests/test_messaging_schema.py -v --no-cov'
ssh root@139.59.224.34 'sudo -u postgres psql -c "ALTER ROLE quantum_user NOCREATEDB;"'
ssh root@139.59.224.34 'systemctl restart gunicorn && systemctl is-active gunicorn'
```

- [ ] **Step 7: Smoke-test production API**

Without credentials, verify auth boundaries and public health remain correct:

```bash
curl -i http://139.59.224.34/api/v1/conversations/
curl -i http://139.59.224.34/api/v1/listings/
curl -i http://139.59.224.34/api/v1/schema/
```

Expected: conversations `401`, listings/schema `200`. With a dedicated test account, create a
dialog and two messages, verify unread/read and duplicate client UUID, then remove only those
test records through Django shell using their recorded UUIDs.

- [ ] **Step 8: Final evidence**

Report exact backend and parent commit hashes, migration names, local/server test totals,
Gunicorn status, smoke HTTP codes, and any pre-existing unrelated failures. Do not claim the
feature complete without this evidence.
