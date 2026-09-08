import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../data_source.dart';
import '../models/business_hour.dart';
import '../models/consumer.dart';
import '../models/consumer_settings.dart';
import '../models/favorite.dart';
import '../models/gift.dart';
import '../models/loyalty_rule.dart';
import '../models/menu_item.dart';
import '../models/merchant.dart';
import '../models/search_history.dart';
import '../models/tag.dart';
import '../models/visit.dart';
import '../models/visit_summary.dart';

/// [DataSource] implementation backed by the JSON fixtures bundled under
/// `mobile/assets/fixtures/` (see `pubspec.yaml`'s `flutter.assets`).
///
/// Every fixture is loaded via `rootBundle.loadString` + `jsonDecode` at most
/// once per app run: each list is cached in memory the first time it's
/// requested, so repeated calls (e.g. re-rendering a screen) don't re-read
/// the asset bundle.
///
/// This is the Fase 2 implementation described in `docs/design-brief.md`
/// §1.5/§5 — a future `remote/remote_data_source.dart` implements the same
/// [DataSource] interface against the real backend API, and the swap
/// between the two is a one-line change in the Riverpod provider that
/// constructs the [DataSource] instance.
class LocalDataSource implements DataSource {
  static const _fixturesPath = 'assets/fixtures';

  List<Merchant>? _merchants;
  List<MenuItem>? _menuItems;
  List<BusinessHour>? _businessHours;
  List<LoyaltyRule>? _loyaltyRules;
  List<Tag>? _tags;
  List<({int merchantId, int tagId})>? _merchantTagLinks;
  List<({int menuItemId, int tagId})>? _menuItemTagLinks;
  Consumer? _consumer;
  ConsumerSettings? _consumerSettings;
  List<VisitSummary>? _visitSummaries;
  List<Visit>? _visits;
  List<Favorite>? _favorites;
  List<Gift>? _gifts;
  List<SearchHistory>? _searchHistory;

  Future<List<dynamic>> _loadJsonList(String fileName) async {
    final raw = await rootBundle.loadString('$_fixturesPath/$fileName');
    return jsonDecode(raw) as List<dynamic>;
  }

  @override
  Future<List<Merchant>> getMerchants() async {
    final cached = _merchants;
    if (cached != null) return cached;
    final raw = await _loadJsonList('merchants.json');
    final merchants = raw
        .map((e) => Merchant.fromJson(e as Map<String, dynamic>))
        .toList();
    _merchants = merchants;
    return merchants;
  }

  @override
  Future<Merchant?> getMerchant(int merchantId) async {
    final merchants = await getMerchants();
    for (final merchant in merchants) {
      if (merchant.id == merchantId) return merchant;
    }
    return null;
  }

  Future<List<MenuItem>> _allMenuItems() async {
    final cached = _menuItems;
    if (cached != null) return cached;
    final raw = await _loadJsonList('menu_items.json');
    final items = raw
        .map((e) => MenuItem.fromJson(e as Map<String, dynamic>))
        .toList();
    _menuItems = items;
    return items;
  }

  @override
  Future<List<MenuItem>> getMenuItems(int merchantId) async {
    final items = await _allMenuItems();
    return items.where((item) => item.merchantId == merchantId).toList();
  }

  Future<List<BusinessHour>> _allBusinessHours() async {
    final cached = _businessHours;
    if (cached != null) return cached;
    final raw = await _loadJsonList('business_hours.json');
    final hours = raw
        .map((e) => BusinessHour.fromJson(e as Map<String, dynamic>))
        .toList();
    _businessHours = hours;
    return hours;
  }

  @override
  Future<List<BusinessHour>> getBusinessHours(int merchantId) async {
    final hours = await _allBusinessHours();
    return hours.where((hour) => hour.merchantId == merchantId).toList();
  }

  Future<List<LoyaltyRule>> _allLoyaltyRules() async {
    final cached = _loyaltyRules;
    if (cached != null) return cached;
    final raw = await _loadJsonList('loyalty_rules.json');
    final rules = raw
        .map((e) => LoyaltyRule.fromJson(e as Map<String, dynamic>))
        .toList();
    _loyaltyRules = rules;
    return rules;
  }

  @override
  Future<List<LoyaltyRule>> getLoyaltyRules(int merchantId) async {
    final rules = await _allLoyaltyRules();
    return rules.where((rule) => rule.merchantId == merchantId).toList();
  }

  @override
  Future<List<Tag>> getTags() async {
    final cached = _tags;
    if (cached != null) return cached;
    final raw = await _loadJsonList('tags.json');
    final tags = raw.map((e) => Tag.fromJson(e as Map<String, dynamic>)).toList();
    _tags = tags;
    return tags;
  }

  Future<List<({int merchantId, int tagId})>> _allMerchantTagLinks() async {
    final cached = _merchantTagLinks;
    if (cached != null) return cached;
    final raw = await _loadJsonList('merchants_tags.json');
    final links = raw
        .map(
          (e) => (
            merchantId: (e as Map<String, dynamic>)['merchant_id'] as int,
            tagId: e['tag_id'] as int,
          ),
        )
        .toList();
    _merchantTagLinks = links;
    return links;
  }

  @override
  Future<List<Tag>> getTagsForMerchant(int merchantId) async {
    final tags = await getTags();
    final links = await _allMerchantTagLinks();
    final tagIds = links
        .where((link) => link.merchantId == merchantId)
        .map((link) => link.tagId)
        .toSet();
    return tags.where((tag) => tagIds.contains(tag.id)).toList();
  }

  @override
  Future<Map<int, Set<int>>> getMerchantTagIdsByMerchant() async {
    final links = await _allMerchantTagLinks();
    final result = <int, Set<int>>{};
    for (final link in links) {
      result.putIfAbsent(link.merchantId, () => <int>{}).add(link.tagId);
    }
    return result;
  }

  Future<List<({int menuItemId, int tagId})>> _allMenuItemTagLinks() async {
    final cached = _menuItemTagLinks;
    if (cached != null) return cached;
    final raw = await _loadJsonList('menu_items_tags.json');
    final links = raw
        .map(
          (e) => (
            menuItemId: (e as Map<String, dynamic>)['menu_item_id'] as int,
            tagId: e['tag_id'] as int,
          ),
        )
        .toList();
    _menuItemTagLinks = links;
    return links;
  }

  @override
  Future<List<Tag>> getTagsForMenuItem(int menuItemId) async {
    final tags = await getTags();
    final links = await _allMenuItemTagLinks();
    final tagIds = links
        .where((link) => link.menuItemId == menuItemId)
        .map((link) => link.tagId)
        .toSet();
    return tags.where((tag) => tagIds.contains(tag.id)).toList();
  }

  @override
  Future<Consumer> getCurrentConsumer() async {
    final cached = _consumer;
    if (cached != null) return cached;
    final raw = await _loadJsonList('consumers.json');
    if (raw.isEmpty) {
      throw StateError(
        'consumers.json fixture is empty — expected the demo consumer row.',
      );
    }
    final consumer = Consumer.fromJson(raw.first as Map<String, dynamic>);
    _consumer = consumer;
    return consumer;
  }

  @override
  Future<ConsumerSettings> getConsumerSettings() async {
    final cached = _consumerSettings;
    if (cached != null) return cached;
    final raw = await _loadJsonList('consumer_settings.json');
    if (raw.isEmpty) {
      throw StateError(
        'consumer_settings.json fixture is empty — expected the demo '
        "consumer's settings row.",
      );
    }
    final settings = ConsumerSettings.fromJson(
      raw.first as Map<String, dynamic>,
    );
    _consumerSettings = settings;
    return settings;
  }

  Future<List<VisitSummary>> _allVisitSummaries() async {
    final cached = _visitSummaries;
    if (cached != null) return cached;
    final raw = await _loadJsonList('visit_summaries.json');
    final summaries = raw
        .map((e) => VisitSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    _visitSummaries = summaries;
    return summaries;
  }

  @override
  Future<List<VisitSummary>> getVisitSummaries({int? merchantId}) async {
    final summaries = await _allVisitSummaries();
    if (merchantId == null) return summaries;
    return summaries
        .where((summary) => summary.merchantId == merchantId)
        .toList();
  }

  Future<List<Visit>> _allVisits() async {
    final cached = _visits;
    if (cached != null) return cached;
    final raw = await _loadJsonList('visits.json');
    final visits = raw
        .map((e) => Visit.fromJson(e as Map<String, dynamic>))
        .toList();
    _visits = visits;
    return visits;
  }

  @override
  Future<List<Visit>> getVisits({int? merchantId}) async {
    final visits = await _allVisits();
    if (merchantId == null) return visits;
    return visits.where((visit) => visit.merchantId == merchantId).toList();
  }

  @override
  Future<List<Favorite>> getFavorites() async {
    final cached = _favorites;
    if (cached != null) return cached;
    final raw = await _loadJsonList('favorites.json');
    final favorites = raw
        .map((e) => Favorite.fromJson(e as Map<String, dynamic>))
        .toList();
    _favorites = favorites;
    return favorites;
  }

  @override
  Future<List<Gift>> getGifts() async {
    final cached = _gifts;
    if (cached != null) return cached;
    final raw = await _loadJsonList('gifts.json');
    final gifts = raw.map((e) => Gift.fromJson(e as Map<String, dynamic>)).toList();
    _gifts = gifts;
    return gifts;
  }

  @override
  Future<List<SearchHistory>> getSearchHistory() async {
    final cached = _searchHistory;
    if (cached != null) return cached;
    final raw = await _loadJsonList('search_history.json');
    final history = raw
        .map((e) => SearchHistory.fromJson(e as Map<String, dynamic>))
        .toList();
    _searchHistory = history;
    return history;
  }
}
