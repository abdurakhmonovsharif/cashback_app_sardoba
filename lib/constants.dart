import 'package:flutter/material.dart';
import 'package:form_field_validator/form_field_validator.dart';

import 'navigation/app_nav_bar_layout.dart';

// clolors that we use in our app
const titleColor = Color(0xFF010F07);
const primaryColor = Color(0xFF0B5E3C);
const accentColor = Color(0xFFEF9920);
const bodyTextColor = Color(0xFF4B5563);
const inputColor = Color(0xFFFBFBFB);
const screenBackgroundColor = Color(0xFFF3F5F9);
const appBorderColor = Color(0xFFE2E8E4);

/// Deeper brand greens used on high-contrast loyalty surfaces.
abstract final class AppBrandColors {
  static const deepGreen = primaryColor;
  static const deepGreenShade = Color(0xFF064E3B);
}

/// Shared shape scale: inset controls, content cards, and large panels.
abstract final class AppRadius {
  static const double control = 16;
  static const double card = 16;
  static const double panel = 24;
}

const double defaultPadding = 16;

abstract final class AppSpacing {
  static const double related = 8;
  static const double section = 12;
}

/// Product Detail uses the existing brand scale with a compact menu hierarchy.
abstract final class ProductDetailTokens {
  static const surface = Colors.white;
  static const double titleSize = 20;
  static const double priceSize = 22;
  static const double currencySize = 16;
  static const double cardTitleSize = 14;
  static const double cardPriceSize = 16;
  static const double cardWidth = 152;
  static const double cardAspectRatio = 508 / 392;
  static const int cardDecodeWidth = 508;
  static const double touchTarget = 48;
  static const double sectionGap = 20;
  static const double pressedScale = 0.98;
}

/// Wallet presentation roles; existing app colors and spacing remain unchanged.
abstract final class WalletTokens {
  static const surface = Colors.white;
  static const debit = Color(0xFF9F3434);
  static const double balanceRadius = 20;
  static const double balanceSize = 28;
  static const double titleSize = 14;
  static const double amountSize = 16;
  static const double dateSize = 12;
  static const double rowHeight = 76;
  static const double iconSize = 40;
  static const double iconGlyph = 20;
  static const double sectionGap = 24;
  static const double cardPadding = 20;
  static const double progressHeight = 4;
}

/// QR wallet dimensions; the code remains large enough to scan on compact phones.
abstract final class QrWalletTokens {
  static const double cardRadius = 20;
  static const double maxContentWidth = 380;
  static const double instructionSize = 18;
  static const double statusCardPadding = 20;
  static const double statusIconContainerSize = 64;
  static const double statusIconSize = 32;
  // Size of the black module area, excluding the white quiet zone.
  static const double regularQrSize = 280;
  static const double quietZone = 28;
  static const int quietZoneModules = 4;
  static const double loginButtonWidth = 200;
}

abstract final class SearchTokens {
  static const double resultThumbSize = 64;
  static const double resultRowMinHeight = 88;
  static const double resultHeaderHeight = 52;
  static const double resultPanelMaxHeight = 520;
}

const BoxShadow appCardShadow = BoxShadow(
  color: Color(0x10010F07),
  blurRadius: 14,
  offset: Offset(0, 4),
);

const double floatingNavBarHeight = AppNavBarLayout.minimumHeight;
const Duration kDefaultDuration = Duration(milliseconds: 250);

// Accounts for the floating nav bar height + safe-area inset.
double navAwareBottomPadding(BuildContext context, {double extra = 0}) {
  final layout = AppNavBarLayout.of(context);
  return layout.height + layout.padding.bottom + extra;
}

const TextStyle kButtonTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 14,
  fontWeight: FontWeight.bold,
);

const EdgeInsets kTextFieldPadding = EdgeInsets.symmetric(
  horizontal: defaultPadding,
  vertical: defaultPadding,
);

// Text Field Decoration
const OutlineInputBorder kDefaultOutlineInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(6)),
  borderSide: BorderSide(
    color: Color(0xFFF3F2F2),
  ),
);

const InputDecoration otpInputDecoration = InputDecoration(
  contentPadding: EdgeInsets.zero,
  counterText: "",
  errorStyle: TextStyle(height: 0),
);

const kErrorBorderSide = BorderSide(color: Colors.red, width: 1);

// Validator
final passwordValidator = MultiValidator([
  RequiredValidator(errorText: 'Password is required'),
  MinLengthValidator(8, errorText: 'Password must be at least 8 digits long'),
  PatternValidator(r'(?=.*?[#?!@$%^&*-/])',
      errorText: 'Passwords must have at least one special character')
]);

final emailValidator = MultiValidator([
  RequiredValidator(errorText: 'Email is required'),
  EmailValidator(errorText: 'Enter a valid email address')
]);

final requiredValidator =
    RequiredValidator(errorText: 'This field is required');
final matchValidator = MatchValidator(errorText: 'passwords do not match');

final phoneNumberValidator = MinLengthValidator(10,
    errorText: 'Phone Number must be at least 10 digits long');
const defaultPhoneInputPrefix = '+998 ';

// Common Text
final Center kOrText = Center(
    child:
        Text("Or", style: TextStyle(color: titleColor.withValues(alpha: 0.7))));
