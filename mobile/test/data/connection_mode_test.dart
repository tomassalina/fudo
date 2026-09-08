// Tests for `data/connection_mode.dart` and the `dataSourceProvider` wiring
// in `data/providers.dart`.
//
// `connectionMode` is resolved at *compile* time via
// `String.fromEnvironment('CONNECTION_MODE', ...)`. No `flutter test` run in
// this suite ever passes `--dart-define=CONNECTION_MODE=remote`, so these
// tests only ever see the default — which is exactly the guarantee this
// task needs to lock in: without the flag, the app stays on `local` and
// `LocalDataSource`. There is no test here (and there should never be one)
// that flips `CONNECTION_MODE=remote` and hits a real network — nothing at
// `/api/v1/*` responds on any reachable backend today (see
// `data/remote/remote_data_source.dart`'s doc comment).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/connection_mode.dart';
import 'package:mobile/data/local/local_data_source.dart';
import 'package:mobile/data/providers.dart';

void main() {
  test('connectionMode defaults to local without the CONNECTION_MODE flag', () {
    expect(connectionMode, ConnectionMode.local);
  });

  test('dataSourceProvider returns a LocalDataSource by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final dataSource = container.read(dataSourceProvider);

    expect(dataSource, isA<LocalDataSource>());
  });
}
