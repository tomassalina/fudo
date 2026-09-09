import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/providers.dart';

/// Home/landing view for the "Buscar" tab (design-brief §2.1): headline,
/// floating search card with a typewriter-style animated placeholder, and an
/// optional "CONTINUAR BÚSQUEDA" block surfacing the consumer's last search.
class SearchHomeView extends ConsumerStatefulWidget {
  const SearchHomeView({required this.onSearch, super.key});

  /// Called with the submitted query text — either typed by the user or the
  /// "continuar búsqueda" shortcut.
  final ValueChanged<String> onSearch;

  @override
  ConsumerState<SearchHomeView> createState() => _SearchHomeViewState();
}

class _SearchHomeViewState extends ConsumerState<SearchHomeView> {
  static const _hints = [
    'Algo picante y barato cerca mío',
    'Café tranquilo para laburar en Palermo',
    'Parrilla para ir con amigos esta noche',
    'Opción sin TACC para almorzar',
    'Sushi que no sea carísimo',
  ];

  static const _typeDelay = Duration(milliseconds: 45);
  static const _deleteDelay = Duration(milliseconds: 25);
  static const _pauseAfterTyped = Duration(milliseconds: 1400);
  static const _pauseAfterDeleted = Duration(milliseconds: 300);

  final TextEditingController _controller = TextEditingController();
  String _displayedHint = '';
  int _hintIndex = 0;
  int _charCount = 0;
  bool _deleting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scheduleTick(_typeDelay);
  }

  void _onTextChanged() => setState(() {});

  /// Drives the typewriter placeholder with a self-rescheduling [Timer]
  /// (types a hint character by character, pauses, deletes it, moves to the
  /// next hint) instead of a package. Using a real, cancelable `Timer` (kept
  /// in [_timer]) rather than a chain of `Future.delayed` calls matters here:
  /// widget tests fail their "no pending timers" invariant if a delayed
  /// future is still in flight when the widget is disposed, even if a
  /// `mounted` check would have made it a no-op — an explicit `_timer
  /// ?.cancel()` in [dispose] avoids that entirely.
  void _scheduleTick(Duration delay) {
    _timer = Timer(delay, _tick);
  }

  void _tick() {
    if (!mounted) return;
    final phrase = _hints[_hintIndex];
    setState(() {
      if (!_deleting) {
        if (_charCount < phrase.length) {
          _charCount++;
          _displayedHint = phrase.substring(0, _charCount);
          _scheduleTick(_typeDelay);
        } else {
          _deleting = true;
          _scheduleTick(_pauseAfterTyped);
        }
      } else {
        if (_charCount > 0) {
          _charCount--;
          _displayedHint = phrase.substring(0, _charCount);
          _scheduleTick(_deleteDelay);
        } else {
          _deleting = false;
          _hintIndex = (_hintIndex + 1) % _hints.length;
          _scheduleTick(_pauseAfterDeleted);
        }
      }
    });
  }

  void _submit() {
    final text = _controller.text.trim().isEmpty
        ? _displayedHint
        : _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSearch(text);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchHistory = ref.watch(searchHistoryProvider).value;
    final lastQuery = (searchHistory != null && searchHistory.isNotEmpty)
        ? searchHistory.last.queryText
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: AppTheme.headline,
              children: [
                const TextSpan(text: 'Encontrá dónde comer.\n'),
                TextSpan(
                  text: 'Ganá descuentos',
                  style: AppTheme.headline.copyWith(
                    fontStyle: FontStyle.italic,
                    color: AppTheme.accent,
                  ),
                ),
                const TextSpan(text: ' por cada visita.'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _SearchCard(
            controller: _controller,
            displayedHint: _displayedHint,
            onSubmit: _submit,
          ),
          if (lastQuery != null) ...[
            const SizedBox(height: 24),
            _ContinueSearchBlock(
              query: lastQuery,
              onTap: () => widget.onSearch(lastQuery),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.displayedHint,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String displayedHint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusHeroLarge),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow,
            blurRadius: 50,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                if (controller.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      text: TextSpan(
                        style: AppTheme.body.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                        children: [
                          TextSpan(text: displayedHint),
                          const TextSpan(text: '|'),
                        ],
                      ),
                    ),
                  ),
                TextField(
                  controller: controller,
                  style: AppTheme.body,
                  onSubmitted: (_) => onSubmit(),
                  decoration: const InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SubmitButton(onTap: onSubmit),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppTheme.ctaGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.38),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Symbols.search, color: Colors.white),
        ),
      ),
    );
  }
}

class _ContinueSearchBlock extends StatelessWidget {
  const _ContinueSearchBlock({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCardLarge),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSecondary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Symbols.history,
                  color: AppTheme.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTINUAR BÚSQUEDA',
                      style: AppTheme.body.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      query,
                      style: AppTheme.body.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Symbols.arrow_forward,
                color: AppTheme.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
