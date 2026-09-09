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
/// Deliberately **session-scoped, not persisted**: a fresh app launch (even
/// with a still-valid token in [TokenStorage]) starts with [consumer] as
/// `null` until the user logs in again in that process — there is no
/// "restore session on cold start" flow wired up yet, consistent with there
/// being no login screen in the app today.
class CurrentConsumerSession {
  /// The logged-in consumer, or `null` if nobody has logged in yet this app
  /// session.
  Consumer? consumer;
}
