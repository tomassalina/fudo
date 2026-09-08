import 'package:flutter/foundation.dart';

/// Domain model for `public.consumers` — the profile a user sees/edits about
/// themselves in the app.
///
/// Deliberately excluded (backend-only, per task spec):
/// - `password_hash`: bcrypt hash, never needed client-side.
/// - There is no OAuth column on `consumers` at all — the backend doesn't
///   support Google login, consistent with the design's "Continuar con
///   Google" button being purely decorative.
/// - `dni_encrypted` / `dni_bidx` (Lockbox-encrypted DNI + blind index): the
///   app never needs the real DNI value. [hasDniOnFile] is a boolean the
///   backend API is expected to compute and expose (e.g. `has_dni_on_file`)
///   instead of the encrypted column — it is NOT a literal `consumers`
///   column name.
/// - Rails audit/soft-delete bookkeeping columns (`created_at`, `created_by`,
///   `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) — see design
///   brief §1.5 "columnas clave".
@immutable
class Consumer {
  const Consumer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    required this.hasDniOnFile,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final bool hasDniOnFile;

  factory Consumer.fromJson(Map<String, dynamic> json) {
    return Consumer(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      hasDniOnFile: json['has_dni_on_file'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'has_dni_on_file': hasDniOnFile,
    };
  }
}
