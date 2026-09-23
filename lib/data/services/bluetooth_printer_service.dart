import 'dart:typed_data';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/core/utils/esc_pos_generator.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';

class BluetoothPrinterService {
  BluetoothPrinterService._();

  /// Generates ESC/POS byte sequence for 58mm or 80mm thermal receipt
  static Uint8List generateReceiptBytes({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
    int? paperWidthCols,
  }) {
    return EscPosGenerator.generateReceiptBytes(
      bill: bill,
      shop: shop,
      billing: billing,
      paperWidthCols: paperWidthCols,
    );
  }

  /// Print receipt using the configured printer size (58mm / 80mm / A4)
  static Future<void> printReceipt({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
    bool? forceA4,
  }) async {
    await ReceiptGenerator.printReceipt(
      bill: bill,
      shop: shop,
      billing: billing,
      forceA4: forceA4,
    );
  }
}
