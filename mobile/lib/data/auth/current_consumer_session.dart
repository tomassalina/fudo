import '../models/consumer.dart';

/// In-memory snapshot of the logged-in consumer for the current app session.
///
/// The real backend API has **no endpoint to fetch "my own consumer
/// profile"** (confirmed against the live OpenAPI doc at
/// `GET /api-docs/v1/swagger.yaml` — there is no `GET /me` or
/// `GET /consumers/me`). The only place a full `Consumer`-shaped object ever
/// comes back from the backend is the response body of `POST /sessions`
/// (login) or `POST /registrations` (register): `{"consumer": {...},
/// "token": "..."}`.
///
/// [AuthRepository] writes [consumer] right after either call succeeds;
/// [RemoteDataSource.getCurrentConsumer] reads it back instead of hitting a
/// nonexistent endpoint.
///
/// This in-memory field itself always starts `null` on a fresh app launch —
/// but it doesn't necessarily stay that way: `data/providers.dart`'s
/// `sessionRestoreProvider` runs once at startup and, if [TokenStorage] has
/// a durable token+consumer snapshot from a previous run, calls
/// [AuthRepository.restoreSession] to repopulate [consumer] here before the
/// UI's first real paint (see that provider's doc, and
/// `core/router/app_router.dart`'s loading gate while it resolves).
class CurrentConsumerSession {
  /// The logged-in consumer, or `null` if nobody has logged in yet this app
  /// session.
  Consumer? consumer;
}
