# Fudo Consumers — mobile

Flutter app for **Fudo Consumers**. See the root [`README.md`](../README.md)
for the full project pitch, stack table, and quickstart, and
[`AGENTS.md`](../AGENTS.md) for canonical conventions.

## Stack

Flutter, Dart, Riverpod (state management), go_router (navigation). See
`pubspec.yaml` for exact versions.

## Running

```bash
cd mobile
flutter pub get
flutter run
```

By default this runs entirely against local fixtures
(`mobile/assets/fixtures/*.json`), no backend required. To connect to the
real backend, see the root [`README.md`](../README.md#mobile) quickstart
section.

## Layout

`lib/{core,features,shared}` — see [`AGENTS.md`](../AGENTS.md) and the root
[`README.md`](../README.md#estructura-del-repo) for the full repo structure.

## Flutter resources

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Flutter documentation](https://docs.flutter.dev/)
