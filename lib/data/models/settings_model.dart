class ShopSettings {
  final String shopName;
  final String address;
  final String phone;
  final String email;
  final String gstNumber;
  final String logoUrl;
  final String footerMessage;

  ShopSettings({
    this.shopName = 'SimpleBilling Store',
    this.address = 'Main Street, City Center',
    this.phone = '+91 98765 43210',
    this.email = 'contact@simplebilling.com',
    this.gstNumber = '',
    this.logoUrl = '',
    this.footerMessage = 'Thank you for your business! Visit again.',
  });

  factory ShopSettings.fromJson(Map<String, dynamic> json) {
    return ShopSettings(
      shopName: json['shop_name'] as String? ?? 'SimpleBilling Store',
      address: json['address'] as String? ?? 'Main Street, City Center',
      phone: json['phone'] as String? ?? '+91 98765 43210',
      email: json['email'] as String? ?? 'contact@simplebilling.com',
      gstNumber: json['gst_number'] as String? ?? '',
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
    this.billPrefix = 'BILL',
    this.billFormat = 'BILL-{SEQ}',
    this.defaultPaymentMethod = 'Cash',
    this.currencySymbol = '₹',
    this.decimalPrecision = 2,
    this.gstEnabled = false,
    this.gstRate = 0.0,
    this.defaultPrinterSize = '80mm',
    this.autoPrint = false,
    this.roundingMethod = 'None',
  });

  factory BillingSettings.fromJson(Map<String, dynamic> json) {
    return BillingSettings(
      billPrefix: json['bill_prefix'] as String? ?? 'BILL',
      billFormat: json['bill_format'] as String? ?? 'BILL-{SEQ}',
      defaultPaymentMethod: json['default_payment_method'] as String? ?? 'Cash',
      currencySymbol: json['currency_symbol'] as String? ?? '₹',
      decimalPrecision: (json['decimal_precision'] as num?)?.toInt() ?? 2,
      gstEnabled: json['gst_enabled'] as bool? ?? false,
      gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 0.0,
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

class LoyaltyRule {
  final String id;
  final String ruleName;
  final double minBillAmount;
  final double? maxBillAmount;
  final double pointsEarned;
  final bool enabled;
  final int sortOrder;

  LoyaltyRule({
    required this.id,
    required this.ruleName,
    required this.minBillAmount,
    this.maxBillAmount,
    required this.pointsEarned,
    this.enabled = true,
    this.sortOrder = 0,
  });

  factory LoyaltyRule.fromJson(Map<String, dynamic> json) {
    return LoyaltyRule(
      id: json['id'] as String,
      ruleName: json['rule_name'] as String? ?? 'Rule',
      minBillAmount: (json['min_bill_amount'] as num?)?.toDouble() ?? 0.0,
      maxBillAmount: (json['max_bill_amount'] as num?)?.toDouble(),
      pointsEarned: (json['points_earned'] as num?)?.toDouble() ?? 1.0,
      enabled: json['enabled'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rule_name': ruleName,
      'min_bill_amount': minBillAmount,
      if (maxBillAmount != null) 'max_bill_amount': maxBillAmount,
      'points_earned': pointsEarned,
      'enabled': enabled,
      'sort_order': sortOrder,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'points_required': pointsRequired,
      'discount_amount': discountAmount,
      'enabled': enabled,
    };
  }
}

class SequenceConfigModel {
  final String? id;
  final String key;
  final String prefix;
  final int padding;
  final int currentVal;

  SequenceConfigModel({
    this.id,
    required this.key,
    required this.prefix,
    required this.padding,
    required this.currentVal,
  });

  factory SequenceConfigModel.fromJson(Map<String, dynamic> json) {
    return SequenceConfigModel(
      id: json['id'] as String?,
      key: json['key'] as String? ?? '',
      prefix: json['prefix'] as String? ?? '',
      padding: (json['padding'] as num?)?.toInt() ?? 6,
      currentVal: (json['current_val'] as num?)?.toInt() ?? 0,
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

  Map<String, dynamic> toJson() {
    return {
      'shop': shop.toJson(),
      'billing': billing.toJson(),
      'loyalty': loyalty.toJson(),
    };
  }
}
