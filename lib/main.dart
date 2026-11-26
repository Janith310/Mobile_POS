import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'db_helper.dart';
import 'manage_products_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const BillingScreen();
        }
        return const LoginScreen();
      },
    ),
  ));
}

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  List<Product> _products = [];
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  String _searchQuery = '';

  List<BluetoothInfo> _pairedDevices = [];
  String? _connectedMac;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _loadProductsFromDb();
    _initBluetooth();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  // Load products from SQLite while keeping any current cart quantities
  Future<void> _loadProductsFromDb() async {
    final currentCart = {for (var p in _products) p.code: p.qty};
    final dbItems = await DbHelper.instance.getAllProducts();

    for (var item in dbItems) {
      item.qty = currentCart[item.code] ?? 0;
    }

    setState(() => _products = dbItems);
  }

  Future<void> _initBluetooth() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    final List<BluetoothInfo> devices =
        await PrintBluetoothThermal.pairedBluetooths;
    setState(() => _pairedDevices = devices);
  }

  Future<void> _connectPrinter(String macAddress) async {
    final bool connected =
        await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    setState(() => _connectedMac = connected ? macAddress : null);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              connected ? 'Printer connected!' : 'Failed to connect printer.'),
        ),
      );
    }
  }

  void _addByCode(String rawInput) {
    final input = rawInput.trim().toLowerCase();
    if (input.isEmpty) return;

    final matchIndex = _products.indexWhere(
      (p) => p.code.toLowerCase() == input,
    );

    if (matchIndex != -1) {
      setState(() {
        _products[matchIndex].qty++;
        _codeController.clear();
        _searchQuery = '';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Product code "$rawInput" not found.'),
          duration: const Duration(seconds: 1),
        ),
      );
      _codeController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _codeController.text.length,
      );
    }

    _codeFocusNode.requestFocus();
  }

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    final q = _searchQuery.toLowerCase();
    return _products
        .where((p) =>
            p.code.toLowerCase().contains(q) ||
            p.name.toLowerCase().contains(q))
        .toList();
  }

  double get _grandTotal =>
      _products.fold(0.0, (sum, item) => sum + (item.price * item.qty));

  Future<void> _printReceipt() async {
    final cartItems = _products.where((p) => p.qty > 0).toList();
    if (cartItems.isEmpty) return;

    bool isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please connect a Bluetooth printer first.')),
      );
      return;
    }

    setState(() => _isPrinting = true);

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      bytes += generator.text(
        'MINI MART POS',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text(
        'No. 45, Main Street\nTel: 011-2345678',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
            text: 'Qty',
            width: 2,
            styles: const PosStyles(align: PosAlign.center, bold: true)),
        PosColumn(
            text: 'Total',
            width: 4,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.hr();

      for (var item in cartItems) {
        final lineTotal = (item.price * item.qty).toStringAsFixed(2);
        bytes += generator.row([
          PosColumn(text: '[${item.code}] ${item.name}', width: 6),
          PosColumn(
              text: '${item.qty}',
              width: 2,
              styles: const PosStyles(align: PosAlign.center)),
          PosColumn(
              text: lineTotal,
              width: 4,
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.hr();

      bytes += generator.row([
        PosColumn(
            text: 'GRAND TOTAL',
            width: 6,
            styles: const PosStyles(bold: true)),
        PosColumn(
            text: _grandTotal.toStringAsFixed(2),
            width: 6,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);

      bytes += generator.feed(1);
      bytes += generator.text(
        'Thank you for shopping!',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(3);

      await PrintBluetoothThermal.writeBytes(bytes);

      setState(() {
        for (var p in _products) {
          p.qty = 0;
        }
      });
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  void _showPrinterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Paired Printer',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    Navigator.pop(context);
                    _initBluetooth().then((_) => _showPrinterDialog());
                  },
                )
              ],
            ),
            const Divider(),
            if (_pairedDevices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                    'No paired Bluetooth devices found. Pair your printer in phone Settings first.'),
              )
            else
              ..._pairedDevices.map(
                (device) => ListTile(
                  leading: const Icon(Icons.print),
                  title: Text(device.name),
                  subtitle: Text(device.macAdress),
                  trailing: _connectedMac == device.macAdress
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _connectPrinter(device.macAdress);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleProducts = _filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick POS Billing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Manage Products',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ManageProductsScreen(),
                ),
              );
              // Refresh product list after returning from Manage Products
              _loadProductsFromDb();
            },
          ),
          IconButton(
            icon:const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed:() async{
              await FirebaseAuth.instance.signOut();
            },
          ),
          
          IconButton(
            icon: Icon(
              Icons.bluetooth_connected,
              color: _connectedMac != null ? Colors.greenAccent : Colors.grey,
            ),
            tooltip: 'Connect Printer',
            onPressed: _showPrinterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    focusNode: _codeFocusNode,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Enter Product Code or Name',
                      hintText: 'e.g. 101',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _codeController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                    onSubmitted: _addByCode,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _addByCode(_codeController.text),
                    child: const Text('Add'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: visibleProducts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = visibleProducts[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blueGrey.shade100,
                    child: Text(
                      item.code,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  title: Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(item.price.toStringAsFixed(2)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: item.qty > 0
                            ? () => setState(() => item.qty--)
                            : null,
                      ),
                      Text('${item.qty}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => setState(() => item.qty++),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Total Amount',
                          style: TextStyle(color: Colors.black54)),
                      Text(
                        _grandTotal.toStringAsFixed(2),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: (_grandTotal > 0 && !_isPrinting)
                        ? _printReceipt
                        : null,
                    icon: const Icon(Icons.print),
                    label: Text(_isPrinting ? 'Printing...' : 'Print Bill'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
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