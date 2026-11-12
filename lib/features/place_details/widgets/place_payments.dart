import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/osm_payments.dart';
import 'osm_payment_icons.dart';

/// A tooltip describing an accepted payment method, including OSM's qualifiers
/// (`only`, or an `opening_hours` interval).
String osmPaymentTooltip(OsmPaymentMethod method) {
  final String value = method.value.toLowerCase();
  if (value == 'yes' || value.isEmpty) {
    return method.label;
  }
  if (value == 'only') {
    return '${method.label} (only)';
  }
  return '${method.label} · ${method.value}';
}

/// The Overview "Payment" section: accepted `payment:*` methods as icons, or a
/// note when OpenStreetMap has no accepted methods listed.
class OsmPaymentMethods extends StatelessWidget {
  const OsmPaymentMethods({
    super.key,
    required this.methods,
    required this.tags,
  });

  final List<OsmPaymentMethod> methods;
  final Map<String, String> tags;

  bool get hasContent => methods.isNotEmpty || _notAcceptedCards.isNotEmpty;

  static const Map<String, String> _cardMethodLabels = <String, String>{
    'payment:cards': 'Cards',
    'payment:credit_cards': 'Credit cards',
    'payment:debit_cards': 'Debit cards',
  };

  List<String> get _notAcceptedCards => _cardMethodLabels.entries
      .where(
        (MapEntry<String, String> entry) =>
            tags.containsKey(entry.key) &&
            !OsmPaymentCatalog.isAccepted(tags[entry.key]),
      )
      .map((MapEntry<String, String> entry) => entry.value)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    if (!hasContent) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<String> notAcceptedCards = _notAcceptedCards;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.payments_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text('Payment', style: theme.textTheme.bodyLarge),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (methods.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md + 20),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final OsmPaymentMethod method in methods)
                    _PaymentIcon(method: method),
                ],
              ),
            )
          else if (notAcceptedCards.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md + 20),
              child: Text(
                'Payment options not listed',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (notAcceptedCards.isNotEmpty)
            _NotAcceptedCardMethods(methods: notAcceptedCards),
        ],
      ),
    );
  }
}

class _NotAcceptedCardMethods extends StatelessWidget {
  const _NotAcceptedCardMethods({required this.methods});

  final List<String> methods;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md + 20,
        top: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.credit_card_off, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Not accepted: ${methods.join(', ')}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single accepted payment method: a bordered tile with its icon and a
/// tooltip naming the method.
class _PaymentIcon extends StatelessWidget {
  const _PaymentIcon({required this.method});

  final OsmPaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: osmPaymentTooltip(method),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Icon(
          osmPaymentIcon(method.suffix),
          size: 22,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The crypto payment badges the sheet promotes below the overall review:
/// Bitcoin Lightning (`payment:lightning`, `payment:lightning_contactless`) and
/// Chaumian ecash (`payment:cashu`, `payment:ecash`).
class OsmCryptoBadges extends StatelessWidget {
  const OsmCryptoBadges({super.key, required this.methods});

  final List<OsmPaymentMethod> methods;

  @override
  Widget build(BuildContext context) {
    if (methods.isEmpty) {
      return const SizedBox.shrink();
    }
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final OsmPaymentMethod method in methods)
            Tooltip(
              message: osmPaymentTooltip(method),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.xs + 1,
                ),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      osmPaymentIcon(method.suffix),
                      size: 16,
                      color: scheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      method.label,
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
