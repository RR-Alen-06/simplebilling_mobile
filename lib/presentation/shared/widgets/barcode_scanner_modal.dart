import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/data/models/product_model.dart';
import 'package:simplebilling_mobile/data/models/customer_model.dart';

class BarcodeScannerModal extends StatefulWidget {
  final List<ProductModel> products;
  final List<CustomerModel> customers;
  final Function(ProductModel product)? onProductScanned;
  final Function(CustomerModel customer)? onCustomerScanned;

  const BarcodeScannerModal({
    super.key,
    this.products = const [],
    this.customers = const [],
    this.onProductScanned,
    this.onCustomerScanned,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ProductModel> products,
    required List<CustomerModel> customers,
    Function(ProductModel product)? onProductScanned,
    Function(CustomerModel customer)? onCustomerScanned,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BarcodeScannerModal(
        products: products,
        customers: customers,
        onProductScanned: onProductScanned,
        onCustomerScanned: onCustomerScanned,
      ),
    );
  }

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeCtrl = TextEditingController();
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isTorchOn = false;
  bool _isProcessingCode = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _cameraController.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _handleCodeSubmission(String rawCode) {
    if (_isProcessingCode) return;
    final query = rawCode.trim().toLowerCase();
    if (query.isEmpty) return;

    _isProcessingCode = true;

    // 1. Search products by product_code, name, or id
    final matchedProduct = widget.products.cast<ProductModel?>().firstWhere(
      (p) =>
          (p?.productCode?.toLowerCase() == query) ||
          (p?.name.toLowerCase() == query) ||
          (p?.id.toLowerCase() == query),
      orElse: () => null,
    );

    if (matchedProduct != null && widget.onProductScanned != null) {
      setState(() {
        _feedbackMessage =
            'Found Product: ${matchedProduct.name} (Rs. ${matchedProduct.price})';
        _isSuccess = true;
      });
      widget.onProductScanned!(matchedProduct);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    // 2. Search customers by customer_code, mobile, or name
    final matchedCustomer = widget.customers.cast<CustomerModel?>().firstWhere(
      (c) =>
          (c?.customerCode?.toLowerCase() == query) ||
          (c?.mobile?.toLowerCase() == query) ||
          (c?.name.toLowerCase() == query),
      orElse: () => null,
    );

    if (matchedCustomer != null && widget.onCustomerScanned != null) {
      setState(() {
        _feedbackMessage =
            'Found Customer: ${matchedCustomer.name} (${matchedCustomer.mobile ?? "-"})';
        _isSuccess = true;
      });
      widget.onCustomerScanned!(matchedCustomer);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }

    setState(() {
      _feedbackMessage = 'No product or customer found for "$rawCode"';
      _isSuccess = false;
      _isProcessingCode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Live Barcode & QR Scanner',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off,
                      color: _isTorchOn ? Colors.amber : Colors.grey,
                    ),
                    tooltip: 'Toggle Flashlight',
                    onPressed: () async {
                      await _cameraController.toggleTorch();
                      setState(() => _isTorchOn = !_isTorchOn);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.grey),
                    tooltip: 'Switch Camera',
                    onPressed: () => _cameraController.switchCamera(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Live Camera Viewport
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(
                    controller: _cameraController,
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final val = barcode.rawValue;
                        if (val != null && val.isNotEmpty) {
                          _handleCodeSubmission(val);
                          break;
                        }
                      }
                    },
                  ),
                  // Target Frame Overlay
                  Container(
                    width: 220,
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 2.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Align barcode / QR within frame',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Manual Entry Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  decoration: InputDecoration(
                    hintText: 'Or enter barcode / SKU / mobile manually...',
                    prefixIcon: const Icon(
                      Icons.keyboard,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: _handleCodeSubmission,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onPressed: () => _handleCodeSubmission(_codeCtrl.text),
                child: const Text('Lookup'),
              ),
            ],
          ),
          if (_feedbackMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isSuccess
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _isSuccess ? AppColors.success : AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _feedbackMessage!,
                      style: TextStyle(
                        color: _isSuccess ? AppColors.success : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
