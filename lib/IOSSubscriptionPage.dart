import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  final List<String> _productIds = [
    'bito.weekly1',
    'bito.monthly1',
    'bito.yearly1'
  ];

  final List<String> _logs = [];

  void _addLog(String text) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.add("[$time] $text");
    });
    print("DEBUG: $text");
  }

  @override
  void initState() {
    super.initState();

    _addLog("🔄 initState() بدأ تشغيل صفحة الاشتراكات");

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () {
        _addLog("🟪 purchaseStream تم إغلاق");
        _subscription.cancel();
      },
    );

    _initializeStore();
  }

  Future<void> _initializeStore() async {
    _addLog("جاري التحقق من توفر متجر أبل...");

    try {
      final available = await _iap.isAvailable();
      _addLog("حالة المتجر: $available");

      if (!available) {
        _addLog("❌ المتجر غير متاح");
        if (mounted) {
          setState(() {
            _storeAvailable = false;
            _loading = false;
          });
        }
        return;
      }

      setState(() => _storeAvailable = true);

      await _loadProducts();
    } catch (e) {
      _addLog("❌ خطأ أثناء تهيئة المتجر: $e");
      setState(() {
        _storeAvailable = false;
        _loading = false;
      });
    }
  }

  Future<void> _loadProducts() async {
    _addLog("جاري تحميل المنتجات من App Store...");

    try {
      final response = await _iap.queryProductDetails(_productIds.toSet());

      if (mounted) {
        setState(() {
          _products = response.productDetails;
          _loading = false;
        });
      }

      if (response.error != null) {
        _addLog("⚠️ خطأ داخل queryProductDetails: ${response.error!.message}");
      }

      if (response.notFoundIDs.isNotEmpty) {
        _addLog("❌ منتجات غير موجودة داخل App Store: ${response.notFoundIDs}");
      }

      _addLog("✔ عدد المنتجات المحملة: ${_products.length}");
    } catch (e) {
      _addLog("❌ خطأ أثناء تحميل الباقات: $e");
      setState(() => _loading = false);
    }
  }

  void _handlePurchase(ProductDetails product) async {
    _addLog("🔄 بدء عملية الشراء للمنتج: ${product.id}");

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      _addLog("✔ تم إرسال طلب الشراء لأبل");
    } catch (e) {
      _addLog("❌ خطأ في buyNonConsumable: $e");
      _showDialog("خطأ في الشراء", "$e");
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      _addLog("📥 تم استلام PurchaseDetails... status=${purchase.status}");

      // ---------------------------------------------
      // 🔥 إضافة تجاهل RESTORE مؤقتاً
      // ---------------------------------------------
      if (purchase.status == PurchaseStatus.restored) {
        _addLog("⚠️ تم استلام RESTORE من Apple — سيتم تجاهله مؤقتاً في وضع الاختبار");
        return;
      }

      if (purchase.status == PurchaseStatus.pending) {
        _addLog("⏳ عملية الشراء قيد التنفيذ...");
      }

      if (purchase.status == PurchaseStatus.error) {
        _addLog("❌ Apple Purchase Error: ${purchase.error?.message}");
        _showDialog("فشل العملية", purchase.error?.message ?? "خطأ غير معروف");
      }

      if (purchase.status == PurchaseStatus.purchased) {
        _addLog("🎉 Apple أكدت عملية الشراء");
        _showSnack("جاري التحقق من الدفع...");
        await _verifyPurchaseWithServer(purchase);

        if (purchase.pendingCompletePurchase) {
          _addLog("🔄 إكمال العملية عبر completePurchase()");
          await _iap.completePurchase(purchase);
        }
      }
    }
  }

  Future<void> _verifyPurchaseWithServer(PurchaseDetails purchase) async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email') ?? '';
    final token = prefs.getString('auth_token') ?? '';
    const secret = "06acbbcf779f421589311198fddf70ee";

    final receiptData = purchase.verificationData.serverVerificationData;

    if (receiptData.isEmpty) {
      _addLog("❌ الإيصال من Apple فارغ!!");
      _showDialog("خطأ", "استلمنا إيصال فارغ من Apple");
      return;
    }

    _addLog("✔ استلمنا الإيصال من Apple (طوله: ${receiptData.length})");
    _addLog("📤 جاري إرسال الإيصال للسيرفر...");

    try {
      final response = await http.post(
        Uri.parse("https://studybito.com/wp-json/bito/v1/verify_ios_receipt"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "receipt-data": receiptData,
          "password": secret,
          "user_email": userEmail,
        }),
      );

      _addLog("📥 رد السيرفر: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          _addLog("🎉 تم التفعيل من السيرفر: ${data['plan']}");
          _showSnack("تم تفعيل ${data['plan']} بنجاح!");

          Future.delayed(const Duration(seconds: 1), () {
            Navigator.of(context).pop();
          });
          return;
        }
      }

      _addLog("⚠️ فشل التحقق من السيرفر — تجربة التفعيل المباشر");
      await _activateUserSubscription(purchase.productID, userEmail);
    } catch (e) {
      _addLog("❌ خطأ أثناء الاتصال بالسيرفر: $e");
      await _activateUserSubscription(purchase.productID, userEmail);
    }
  }

  Future<void> _activateUserSubscription(
      String productId, String userEmail) async {
    _addLog("🔄 تفعيل مباشر للباقة عبر السيرفر... product=$productId");

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.post(
        Uri.parse("https://studybito.com/wp-json/bito/v1/activate_subscription"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "product_id": productId,
          "user_email": userEmail,
          "platform": "ios",
        }),
      );

      _addLog("📥 رد التفعيل المباشر: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          _addLog("🎉 تفعيل ناجح: ${data['plan_name']}");
          _showSnack("تم تفعيل ${data['plan_name']} بنجاح!");

          Future.delayed(const Duration(seconds: 1), () {
            Navigator.of(context).pop();
          });
        }
      }
    } catch (e) {
      _addLog("❌ خطأ أثناء التفعيل المباشر: $e");
      _showDialog("خطأ", "$e");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.deepPurple,
      ),
    );
  }

  void _showDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            child: const Text("موافق"),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _debugConsole() {
    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView(
        children: _logs
            .map((log) => Text(
          log,
          style:
          const TextStyle(color: Colors.greenAccent, fontSize: 12),
        ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ready = _storeAvailable && _products.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text(
          "باقات Bito Plus",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.deepPurple),
      )
          : Column(
        children: [
          const SizedBox(height: 16),

          if (!ready)
            const Text(
              "⚠️ متجر Apple غير جاهز الآن",
              style: TextStyle(color: Colors.red),
            ),

          if (ready)
            _buildPlanCard(
              title: "الباقة الأسبوعية",
              price: "٢٩٫٩٩ ر.س",
              duration: "7 أيام",
              onTap: () => _handlePurchase(
                  _products.firstWhere((p) => p.id == "bito.weekly1")),
            ),
          if (ready)
            _buildPlanCard(
              title: "الباقة الشهرية",
              price: "٧٩٫٩٩ ر.س",
              duration: "30 يوم",
              onTap: () => _handlePurchase(
                  _products.firstWhere((p) => p.id == "bito.monthly1")),
            ),
          if (ready)
            _buildPlanCard(
              title: "الباقة السنوية",
              price: "٢٩٩٫٩٩ ر.س",
              duration: "365 يوم",
              onTap: () => _handlePurchase(
                  _products.firstWhere((p) => p.id == "bito.yearly1")),
            ),

          Expanded(child: _debugConsole()),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String duration,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple)),
          const SizedBox(height: 10),
          Text(price,
              style:
              const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(duration, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style:
              ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
              child: const Text("اشترك الآن",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
