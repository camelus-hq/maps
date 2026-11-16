import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/osm_payments.dart';
import '../../design/play.dart';
import 'osm_payment_icons.dart';

/// A label describing an accepted payment method, including OSM's qualifiers
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
    final PlayColors colors = PlayColors.of(context);
    final List<String> notAcceptedCards = _notAcceptedCards;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                PhosphorIconsRegular.money,
                size: 20,
                color: colors.inkMuted,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Payment',
                  style: PlayType.body.copyWith(color: colors.ink),
                ),
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
                style: PlayType.body.copyWith(color: colors.inkMuted),
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
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md + 20,
        top: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            PhosphorIconsRegular.creditCard,
            size: 18,
            color: colors.inkMuted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Not accepted: ${methods.join(', ')}',
              style: PlayType.body.copyWith(color: colors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single accepted payment method: a bordered tile with its icon and a
/// semantic label naming the method.
class _PaymentIcon extends StatelessWidget {
  const _PaymentIcon({required this.method});

  final OsmPaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final PlayColors colors = PlayColors.of(context);
    return Semantics(
      container: true,
      label: osmPaymentTooltip(method),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(PlayRadii.xs),
          border: Border.all(color: colors.line),
        ),
        alignment: Alignment.center,
        child: Icon(
          osmPaymentIcon(method.suffix),
          size: 22,
          color: colors.inkMuted,
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
    final PlayColors colors = PlayColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final OsmPaymentMethod method in methods)
            Semantics(
              container: true,
              label: osmPaymentTooltip(method),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.xs + 1,
                ),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      osmPaymentIcon(method.suffix),
                      size: 16,
                      color: colors.onPrimarySoft,
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      method.label,
                      style: TextStyle(
                        color: colors.onPrimarySoft,
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
