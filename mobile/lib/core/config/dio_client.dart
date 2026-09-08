import 'package:dio/dio.dart';

/// Base Dio client for the app. No base URL or interceptors are configured
/// yet — this is scaffold only, wired up once the API contract is defined.
class DioClient {
  DioClient._();

  static final Dio instance = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
}
