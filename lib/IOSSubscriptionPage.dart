import 'dart:convert';
import 'dart:async';
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
  List<ProductDetails> _products = [];
  final List<String> _productIds = ['bito.weekly', 'bito.monthly', 'bito.yearly'];

  @override
  void initState() {
    super.initState();
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate);
    _loadProducts();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  // ✅ تحميل المنتجات من App Store
  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(_productIds.toSet());
    if (mounted) {
      setState(() {
        _products = response.productDetails;
        _loading = false;
      });
    }

    if (response.notFoundIDs.isNotEmpty) {
      _showDialog("خطأ", "تعذر تحميل بعض الباقات من App Store.");
    }
  }

  // ✅ تنفيذ عملية الشراء
  void _buy(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // ✅ التحقق من عملية الشراء
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        _showSnack("✅ جاري التحقق من الدفع...");

        // تحقق من الإيصال عبر السيرفر
        await _verifyPurchaseWithServer(purchase);

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }

        if (mounted) {
          Navigator.pop(context); // ✅ يرجع لصفحة study
        }
      } else if (purchase.status == PurchaseStatus.error) {
        _showDialog("خطأ في الدفع", purchase.error?.message ?? "حدث خطأ غير متوقع أثناء الشراء.");
      }
    }
  }

  // ✅ إرسال الإيصال للتحقق في السيرفر
  Future<void> _verifyPurchaseWithServer(PurchaseDetails purchase) async {
    const String secret = "06acbbcf779f421589311198fddf70ee"; // App-Specific Shared Secret
    final String receiptData = purchase.verificationData.serverVerificationData;

    try {
      final response = await http.post(
        Uri.parse("https://studybito.com/wp-json/bito/v1/verify_ios_receipt"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "receipt-data": receiptData,
          "password": secret,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showDialog("تم التفعيل ✅", "تم تفعيل ${data['plan']} بنجاح. يمكنك الآن استخدام جميع الأدوات بلا حدود.");
        } else {
          _showDialog("فشل التحقق", data['message'] ?? "لم يتم التحقق من الإيصال.");
        }
      } else {
        _showDialog("خطأ في الاتصال", "تعذر الاتصال بالخادم للتحقق من الدفع.");
      }
    } catch (e) {
      _showDialog("مشكلة في الشبكة", "حدث خطأ أثناء الاتصال: $e");
    }
  }

  // ✅ أدوات مساعدة لعرض رسائل
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.deepPurple,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.deepPurple)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("موافق", style: TextStyle(color: Colors.deepPurple)),
          )
        ],
      ),
    );
  }

  // ✅ تصميم بطاقة الباقة
  Widget _buildPlanCard(ProductDetails product, String durationLabel, IconData icon) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 45, color: Colors.white),
            const SizedBox(height: 10),
            Text(
              product.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              durationLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              product.price,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "استخدام غير محدود خلال هذه المدة 📚",
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: () => _buy(product),
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: const Text(
                "اشترك الآن",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(160, 45),
              ),
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
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : _products.isEmpty
          ? const Center(child: Text("⚠️ لا توجد باقات متاحة حالياً."))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildPlanCard(_products.firstWhere((p) => p.id == 'bito.weekly',
              orElse: () => _products.first), "اشتراك أسبوعي (7 أيام)", Icons.calendar_view_week),
          _buildPlanCard(_products.firstWhere((p) => p.id == 'bito.monthly',
              orElse: () => _products.first), "اشتراك شهري (30 يوم)", Icons.calendar_month),
          _buildPlanCard(_products.firstWhere((p) => p.id == 'bito.yearly',
              orElse: () => _products.first), "اشتراك سنوي (365 يوم)", Icons.workspace_premium),
        ],
      ),
    );
  }
}

