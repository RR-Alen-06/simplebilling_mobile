import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:simplebilling_mobile/core/constants/app_colors.dart';
import 'package:simplebilling_mobile/core/utils/app_logger.dart';
import 'package:simplebilling_mobile/core/utils/esc_pos_generator.dart';
import 'package:simplebilling_mobile/data/models/bill_model.dart';
import 'package:simplebilling_mobile/data/models/settings_model.dart';
import 'package:simplebilling_mobile/presentation/shared/printing/receipt_generator.dart';

class BluetoothPrinterService {
  BluetoothPrinterService._();

  /// Requests runtime Bluetooth permissions (BLUETOOTH_CONNECT, BLUETOOTH_SCAN, Location if needed)
  static Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.locationWhenInUse,
        ].request();

        final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
        final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? true;
        final thermalPluginGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;

        return (connectGranted && scanGranted) || thermalPluginGranted;
      } else if (Platform.isIOS) {
        final status = await Permission.bluetooth.request();
        return status.isGranted;
      }
      return true;
    } catch (e, stack) {
      AppLogger.error('Failed to request Bluetooth permissions', e, stack);
      return false;
    }
  }

  /// Check if Bluetooth is enabled and permissions granted
  static Future<bool> isBluetoothEnabled() async {
    try {
      final bool bluetoothStatus = await PrintBluetoothThermal.bluetoothEnabled;
      return bluetoothStatus;
    } catch (e) {
      return false;
    }
  }

  /// Get list of paired / bonded Bluetooth devices
  static Future<List<BluetoothInfo>> getPairedDevices() async {
    try {
      final hasPerms = await requestPermissions();
      if (!hasPerms) {
        AppLogger.warn('Bluetooth permission denied while fetching paired devices');
        return [];
      }
      final List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices;
    } catch (e, stack) {
      AppLogger.error('Failed to get paired Bluetooth devices', e, stack);
      return [];
    }
  }

  /// Check if a thermal printer is currently connected
  static Future<bool> isConnected() async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (e) {
      return false;
    }
  }

  /// Connect to Bluetooth printer by MAC address
  static Future<bool> connect(String macAddress) async {
    try {
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      return result;
    } catch (e, stack) {
      AppLogger.error('Error connecting to Bluetooth printer: $macAddress', e, stack);
      return false;
    }
  }

  /// Disconnect current Bluetooth printer
  static Future<bool> disconnect() async {
    try {
      return await PrintBluetoothThermal.disconnect;
    } catch (e) {
      return false;
    }
  }

  /// Send raw ESC/POS bytes directly over Bluetooth
  static Future<bool> sendBytes(Uint8List bytes) async {
    try {
      final isConn = await isConnected();
      if (!isConn) {
        AppLogger.warn('Cannot send bytes: Bluetooth printer not connected');
        return false;
      }
      final bool result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e, stack) {
      AppLogger.error('Error writing bytes to Bluetooth thermal printer', e, stack);
      return false;
    }
  }

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

  /// Direct Bluetooth Thermal Print
  static Future<bool> printThermalDirect({
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
    required String macAddress,
  }) async {
    try {
      final hasPerms = await requestPermissions();
      if (!hasPerms) {
        AppLogger.warn('Bluetooth print cancelled: Permission not granted');
        return false;
      }

      final isConn = await isConnected();
      if (!isConn) {
        final connected = await connect(macAddress);
        if (!connected) {
          AppLogger.warn('Failed to connect to printer at $macAddress');
          return false;
        }
      }

      final int cols = billing.defaultPrinterSize == '58mm' ? 32 : 42;
      final bytes = generateReceiptBytes(
        bill: bill,
        shop: shop,
        billing: billing,
        paperWidthCols: cols,
      );

      final success = await sendBytes(bytes);
      return success;
    } catch (e, stack) {
      AppLogger.error('Failed to print thermal receipt via Bluetooth', e, stack);
      return false;
    }
  }

  /// Opens an interactive modal to pick a paired Bluetooth printer and print
  static Future<void> showBluetoothPrinterModal(
    BuildContext context, {
    required BillModel bill,
    required ShopSettings shop,
    required BillingSettings billing,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BluetoothPrinterSelector(
        bill: bill,
        shop: shop,
        billing: billing,
      ),
    );
  }

  /// Fallback print receipt using system PDF spooler (58mm / 80mm / A4)
  static Future<void> printReceiptPdf({
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

class _BluetoothPrinterSelector extends StatefulWidget {
  final BillModel bill;
  final ShopSettings shop;
  final BillingSettings billing;

  const _BluetoothPrinterSelector({
    required this.bill,
    required this.shop,
    required this.billing,
  });

  @override
  State<_BluetoothPrinterSelector> createState() => _BluetoothPrinterSelectorState();
}

class _BluetoothPrinterSelectorState extends State<_BluetoothPrinterSelector> {
  List<BluetoothInfo> _devices = [];
  bool _isLoading = true;
  String? _connectingMac;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    final devices = await BluetoothPrinterService.getPairedDevices();
    if (mounted) {
      setState(() {
        _devices = devices;
        _isLoading = false;
        if (devices.isEmpty) {
          _statusMessage = 'No paired Bluetooth printers found. Please pair your POS thermal printer in device Bluetooth settings first.';
        }
      });
    }
  }

  Future<void> _printToDevice(BluetoothInfo device) async {
    setState(() {
      _connectingMac = device.macAdress;
      _statusMessage = 'Connecting to ${device.name}...';
    });

    final success = await BluetoothPrinterService.printThermalDirect(
      bill: widget.bill,
      shop: widget.shop,
      billing: widget.billing,
      macAddress: device.macAdress,
    );

    if (mounted) {
      setState(() => _connectingMac = null);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt #${widget.bill.billNumber} printed via ${device.name}!'),
            backgroundColor: AppColors.primaryEmerald,
          ),
        );
      } else {
        setState(() {
          _statusMessage = 'Failed to print to ${device.name}. Check connection and try again or use PDF print.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bluetooth_connected_rounded, color: AppColors.primaryEmerald),
                  SizedBox(width: 8),
                  Text(
                    'Bluetooth Thermal Printer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _loadDevices,
                tooltip: 'Refresh paired devices',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Select a paired ESC/POS thermal printer (58mm / 80mm)',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          if (_statusMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_devices.isNotEmpty)
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _devices.length,
                separatorBuilder: (_, i) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final dev = _devices[idx];
                  final isBusy = _connectingMac == dev.macAdress;

                  return ListTile(
                    leading: const Icon(Icons.print_rounded, color: AppColors.primaryEmerald),
                    title: Text(dev.name.isNotEmpty ? dev.name : 'Unknown Device', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(dev.macAdress, style: const TextStyle(fontSize: 11)),
                    trailing: isBusy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _connectingMac != null ? null : () => _printToDevice(dev),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text('Use Standard PDF Spooler Instead'),
              onPressed: () {
                Navigator.pop(context);
                BluetoothPrinterService.printReceiptPdf(
                  bill: widget.bill,
                  shop: widget.shop,
                  billing: widget.billing,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
