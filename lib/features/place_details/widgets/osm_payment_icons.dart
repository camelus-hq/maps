import 'package:flutter/widgets.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

/// Phosphor icon for an OpenStreetMap `payment:*` method suffix.
///
/// The labels come from `OsmPaymentCatalog` (L0); the icons are a presentation
/// choice, so they live here in the feature layer. Unknown methods fall back to
/// a generic money icon — they are still shown, just without a bespoke glyph.
IconData osmPaymentIcon(String suffix) => switch (suffix) {
  'cash' => PhosphorIconsRegular.handCoins,
  'coins' => PhosphorIconsRegular.coins,
  'notes' => PhosphorIconsRegular.money,
  'cheque' => PhosphorIconsRegular.note,
  'cards' || 'debit_cards' => PhosphorIconsRegular.cards,
  'credit_cards' => PhosphorIconsRegular.creditCard,
  'contactless' ||
  'mastercard_contactless' => PhosphorIconsRegular.contactlessPayment,
  'qr_code' => PhosphorIconsRegular.qrCode,
  'membership_card' ||
  'account_cards' => PhosphorIconsRegular.identificationCard,
  'electronic_purses' || 'stored_value_card' => PhosphorIconsRegular.cardholder,
  'paypal' => PhosphorIconsRegular.paypalLogo,
  'apple_pay' ||
  'google_pay' ||
  'google_wallet' ||
  'samsung_pay' ||
  'amazon_pay' ||
  'venmo' ||
  'cash_app' ||
  'satispay' ||
  'app' => PhosphorIconsRegular.deviceMobile,
  // Bitcoin Lightning.
  'lightning' ||
  'lightning_contactless' ||
  'bitpay' => PhosphorIconsRegular.lightning,
  // Bitcoin / on-chain.
  'bitcoin' || 'bitcoincash' || 'onchain' => PhosphorIconsRegular.currencyBtc,
  // Chaumian ecash.
  'cashu' || 'ecash' || 'lightning_cashu' => PhosphorIconsRegular.coin,
  'ethereum' => PhosphorIconsRegular.currencyEth,
  'fuel_cards' ||
  'dkv' ||
  'uta' ||
  'routex' ||
  'euroshell' ||
  'fleetcor' => PhosphorIconsRegular.gasPump,
  // Card brands all read as a credit card.
  'visa' ||
  'mastercard' ||
  'american_express' ||
  'amex' ||
  'diners_club' ||
  'discover_card' ||
  'discover' ||
  'jcb' ||
  'unionpay' ||
  'unionpay_debit' ||
  'maestro' ||
  'girocard' ||
  'elo' ||
  'mir' ||
  'troy' ||
  'bancomat' ||
  'bancontact' ||
  'bankaxept' ||
  'cb' ||
  'dankort' ||
  'eftpos' ||
  'eps' ||
  'interac' ||
  'mastercard_debit' ||
  'multibanco' ||
  'multicaixa' ||
  'napas' ||
  'nets' ||
  'postfinance_card' ||
  'visa_debit' ||
  'visa_electron' ||
  'gpn_debit' ||
  'belkart' ||
  'dinacard' ||
  'forbrugsforeningen' ||
  'golden_crown' => PhosphorIconsRegular.creditCard,
  _ => PhosphorIconsRegular.money,
};
