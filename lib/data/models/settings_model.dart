class ShopSettings {
  final String shopName;
  final String address;
  final String phone;
  final String email;
  final String gstNumber;
  final String logoUrl;
  final String footerMessage;

  ShopSettings({
    this.shopName = 'PrintPro Xerox & Stationery',
    this.address = '123 College Road, Campus Corner',
    this.phone = '+91 98765 43210',
    this.email = 'contact@printproerp.com',
    this.gstNumber = '33AAAAA0000A1Z5',
    this.logoUrl = '',
    this.footerMessage = 'Thank you for your business! Visit again.',
  });

  factory ShopSettings.fromJson(Map<String, dynamic> json) {
    return ShopSettings(
      shopName: json['shop_name'] as String? ?? 'PrintPro Xerox & Stationery',
      address: json['address'] as String? ?? '123 College Road, Campus Corner',
      phone: json['phone'] as String? ?? '+91 98765 43210',
      email: json['email'] as String? ?? 'contact@printproerp.com',
      gstNumber: json['gst_number'] as String? ?? '33AAAAA0000A1Z5',
      logoUrl: json['logo_url'] as String? ?? '',
      footerMessage: json['footer_message'] as String? ?? 'Thank you for your business! Visit again.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shop_name': shopName,
      'address': address,
      'phone': phone,
      'email': email,
      'gst_number': gstNumber,
      'logo_url': logoUrl,
      'footer_message': footerMessage,
    };
  }
}

class BillingSettings {
  final String billPrefix;
  final String billFormat;
  final String defaultPaymentMethod;
  final String currencySymbol;
  final int decimalPrecision;
  final bool gstEnabled;
  final double gstRate;
  final String defaultPrinterSize;
  final bool autoPrint;
  final String roundingMethod;

  BillingSettings({
    this.billPrefix = 'INV',
    this.billFormat = 'PREFIX-YYYYMM-SEQ',
    this.defaultPaymentMethod = 'Cash',
    this.currencySymbol = '₹',
    this.decimalPrecision = 2,
    this.gstEnabled = false,
    this.gstRate = 18.0,
    this.defaultPrinterSize = '80mm',
    this.autoPrint = false,
    this.roundingMethod = 'None',
  });

  factory BillingSettings.fromJson(Map<String, dynamic> json) {
    return BillingSettings(
      billPrefix: json['bill_prefix'] as String? ?? 'INV',
      billFormat: json['bill_format'] as String? ?? 'PREFIX-YYYYMM-SEQ',
      defaultPaymentMethod: json['default_payment_method'] as String? ?? 'Cash',
      currencySymbol: json['currency_symbol'] as String? ?? '₹',
      decimalPrecision: (json['decimal_precision'] as num?)?.toInt() ?? 2,
      gstEnabled: json['gst_enabled'] as bool? ?? false,
      gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 18.0,
      defaultPrinterSize: json['default_printer_size'] as String? ?? '80mm',
      autoPrint: json['auto_print'] as bool? ?? false,
      roundingMethod: json['rounding_method'] as String? ?? 'None',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bill_prefix': billPrefix,
      'bill_format': billFormat,
      'default_payment_method': defaultPaymentMethod,
      'currency_symbol': currencySymbol,
      'decimal_precision': decimalPrecision,
      'gst_enabled': gstEnabled,
      'gst_rate': gstRate,
      'default_printer_size': defaultPrinterSize,
      'auto_print': autoPrint,
      'rounding_method': roundingMethod,
    };
  }
}

class LoyaltySettings {
  final bool enabled;
  final double pointsRequired;
  final double discountValue;

  LoyaltySettings({
    this.enabled = true,
    this.pointsRequired = 10.0,
    this.discountValue = 5.0,
  });

  factory LoyaltySettings.fromJson(Map<String, dynamic> json) {
    return LoyaltySettings(
      enabled: json['enabled'] as bool? ?? true,
      pointsRequired: (json['points_required'] as num?)?.toDouble() ?? 10.0,
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'points_required': pointsRequired,
      'discount_value': discountValue,
    };
  }
}

class LoyaltyRedemptionRule {
  final String id;
  final double pointsRequired;
  final double discountAmount;
  final bool enabled;

  LoyaltyRedemptionRule({
    required this.id,
    required this.pointsRequired,
    required this.discountAmount,
    this.enabled = true,
  });

  factory LoyaltyRedemptionRule.fromJson(Map<String, dynamic> json) {
    return LoyaltyRedemptionRule(
      id: json['id'] as String,
      pointsRequired: (json['points_required'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class AllSettings {
  final ShopSettings shop;
  final BillingSettings billing;
  final LoyaltySettings loyalty;

  AllSettings({
    required this.shop,
    required this.billing,
    required this.loyalty,
  });

  factory AllSettings.fromJson(Map<String, dynamic> json) {
    return AllSettings(
      shop: ShopSettings.fromJson(json['shop'] as Map<String, dynamic>? ?? {}),
      billing: BillingSettings.fromJson(json['billing'] as Map<String, dynamic>? ?? {}),
      loyalty: LoyaltySettings.fromJson(json['loyalty'] as Map<String, dynamic>? ?? {}),
    );
  }
}
