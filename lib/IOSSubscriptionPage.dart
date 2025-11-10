import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;

class IOSSubscriptionPage extends StatefulWidget {
  const IOSSubscriptionPage({super.key});

  @override
  State<IOSSubscriptionPage> createState() => _IOSSubscriptionPageState();
}

class _IOSSubscriptionPageState extends State<IOSSubscriptionPage> {
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _loading = true;
  bool _storeAvailable = false;
  List<ProductDetails> _products = [];
  final List<String> _productIds = ['bito.weekly', 'bito.monthly', 'bito.yearly'];

  @override
  void initState() {
    super.initState();
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate, onDone: () {
      _subscription.cancel();
    });
    _initializeStore();
  }

  Future<void> _initializeStore() async {
    final available = await _iap.isAvailable();
    if (!available) {
      setState(() {
        _storeAvailable = false;
        _loading = false;
      });
      _showDialog("خطأ", "متجر App Store غير متاح حالياً. يرجى المحاولة لاحقاً.");
      return;
    }

    setState(() {
      _storeAvailable = true;
    });

    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(_productIds.toSet());
      if (mounted) {
        setState(() {
          _products = response.productDetails;
          _loading = false;
        });
      }

      if (response.error != null) {
        _showDialog("خطأ", "تعذر الاتصال بمتجر أبل: ${response.error!.message}");
      } else if (response.notFoundIDs.isNotEmpty) {
        _showDialog("تنبيه", "لم يتم العثور على بعض الباقات بعد. تأكد من اعتمادها في App Store Connect.");
      }
    } catch (e) {
      _showDialog("مشكلة في الاتصال", "حدث خطأ أثناء تحميل الباقات: $e");
    }
  }

  void _buy(ProductDetails product) async {
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _showDialog("خطأ في الشراء", "حدث خطأ أثناء تنفيذ عملية الشراء: $e");
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        _showSnack("✅ جاري التحقق من الدفع...");
        await _verifyPurchaseWithServer(purchase);
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        _showDialog("فشل العملية", purchase.error?.message ?? "حدث خطأ غير متوقع.");
      }
    }
  }

  Future<void> _verifyPurchaseWithServer(PurchaseDetails purchase) async {
    const secret = "06acbbcf779f421589311198fddf70ee";
    final receiptData = purchase.verificationData.serverVerificationData;

    try {
      final response = await http.post(
        Uri.parse("https://studybito.com/wp-json/bito/v1/verify_ios_receipt"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"receipt-data": receiptData, "password": secret}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showDialog("تم التفعيل ✅", "تم تفعيل ${data['plan']} بنجاح.");
        } else {
          _showDialog("فشل التحقق", data['message'] ?? "لم يتم التحقق من الإيصال.");
        }
      } else {
        _showDialog("خطأ في السيرفر", "لم يتم التحقق من الإيصال.");
      }
    } catch (e) {
      _showDialog("مشكلة في الشبكة", "حدث خطأ أثناء الاتصال بالخادم: $e");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.deepPurple,
    ));
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(color: Colors.deepPurple)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("موافق", style: TextStyle(color: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(ProductDetails product, String label, IconData icon) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 42),
            const SizedBox(height: 8),
            Text(product.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            Text(product.price,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _buy(product),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text("اشترك الآن", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3FF),
      appBar: AppBar(
        title: const Text("باقات Bito Plus"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : !_storeAvailable
          ? const Center(child: Text("⚠️ متجر App Store غير متاح حالياً."))
          : _products.isEmpty
          ? const Center(child: Text("🚀 جاري تحميل الباقات أو لم يتم اعتمادها بعد."))
          : ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildPlanCard(_products.firstWhere((p) => p.id == 'bito.weekly', orElse: () => _products.first),
              "اشتراك أسبوعي (7 أيام)", Icons.calendar_view_week),
          _buildPlanCard(_products.firstWhere((p) => p.id == 'bito.monthly', orElse: () => _products.first),
              "اشتراك شهري (30 يوم)", Icons.calendar_month),
          _buildPlanCard(_products.firstWhere((p) => p.id == 'bito.yearly', orElse: () => _products.first),
              "اشتراك سنوي (365 يوم)", Icons.workspace_premium),
        ],
      ),
    );
  }
}
