import 'package:flutter/foundation.dart';

/// Domain model for `public.tags` (also referenced via the `merchants_tags`
/// and `menu_items_tags` join tables, which carry no extra columns of their
/// own beyond the two foreign keys).
///
/// Rails audit/soft-delete bookkeeping columns (`created_at`, `created_by`,
/// `updated_at`, `updated_by`, `deleted_at`, `deleted_by`) are intentionally
/// left out — see design brief §1.5 "columnas clave".
@immutable
class Tag {
  const Tag({required this.id, required this.name});

  final int id;
  final String name;

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(id: json['id'] as int, name: json['name'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
