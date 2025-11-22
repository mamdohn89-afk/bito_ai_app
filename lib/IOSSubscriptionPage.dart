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
  // ===============================
  // 🔧 المتغيرات الأساسية
  // ===============================
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  bool _loading = true;
  bool _storeAvailable = false;
  List<ProductDetails> _products = [];
  final List<String> _productIds = ['bito.weekly1', 'bito.monthly1', 'bito.yearly1'];

  // 🔥 سجل الأخطاء المحسن
  List<String> debugLogs = [];

  void addLog(String text) {
    debugLogs.add("${DateTime.now()}: $text");
    print("🐞 DEBUG: $text");
  }

  // ===============================
  // 🎭 بيانات الباقات التجريبية
  // ===============================
  final List<Map<String, dynamic>> _demoProductsData = [
    {
      'id': 'bito.weekly1',
      'title': 'Bito Plus - أسبوعي',
      'description': 'اشتراك لا محدود لجميع خدمات بيتو',
      'price': '٢٩٫٩٩ ر.س',
      'rawPrice': 29.99,
      'currencyCode': 'SAR',
      'label': '7 أيام',
      'icon': Icons.calendar_view_week,
      'features': ['جميع الأدوات الذكية', 'تحميل غير محدود', 'دعم فني', '7 أيام']
    },
    {
      'id': 'bito.monthly1',
      'title': 'Bito Plus - شهري',
      'description': 'اشتراك لا محدود لجميع خدمات بيتو',
      'price': '٧٩٫٩٩ ر.س',
      'rawPrice': 79.99,
      'currencyCode': 'SAR',
      'label': '30 يوم',
      'icon': Icons.calendar_month,
      'features': ['جميع الأدوات الذكية', 'تحميل غير محدود', 'دعم فني', '30 يوم']
    },
    {
      'id': 'bito.yearly1',
      'title': 'Bito Plus - سنوي',
      'description': 'اشتراك لا محدود لجميع خدمات بيتو',
      'price': '٢٩٩٫٩٩ ر.س',
      'rawPrice': 299.99,
      'currencyCode': 'SAR',
      'label': '365 يوم',
      'icon': Icons.workspace_premium,
      'features': ['جميع الأدوات الذكية', 'تحميل غير محدود', 'دعم فني', '365 يوم', 'وفر 62%']
    },
  ];

  List<ProductDetails> get _demoProducts => _demoProductsData.map((data) {
    return ProductDetails(
      id: data['id'],
      title: data['title'],
      description: data['description'],
      price: data['price'],
      rawPrice: data['rawPrice'],
      currencyCode: data['currencyCode'],
    );
  }).toList();

  // ===============================
  // 🚀 التهيئة
  // ===============================
  @override
  void initState() {
    super.initState();
    _initializeStore();
    _startRobustPurchaseListener();
    _startAutoVerification(); // 🔥 الجديد: التحقق التلقائي
  }

  void _startRobustPurchaseListener() {
    addLog("🔊 بدء تشغيل الـ Stream المعزز...");

    _subscription = _iap.purchaseStream.listen(
          (List<PurchaseDetails> purchases) {
        if (purchases.isNotEmpty) {
          addLog("📥 استقبل الـ Stream ${purchases.length} عملية شراء");
          addLog("🔄 حالة أول عملية: ${purchases.first.status}");
        } else {
          addLog("📥 استقبل الـ Stream ولكن القائمة فارغة");
        }
        _onPurchaseUpdate(purchases);
      },
      onError: (error) {
        addLog("❌ خطأ في الـ Stream: $error");
        _restartPurchaseListener();
      },
      onDone: () {
        addLog("ℹ️ الـ Stream اكتمل - إعادة التشغيل...");
        _restartPurchaseListener();
      },
      cancelOnError: false,
    );
  }

  void _restartPurchaseListener() {
    addLog("🔄 إعادة تشغيل الـ Stream...");
    _subscription.cancel();
    Future.delayed(const Duration(seconds: 2), () {
      _startRobustPurchaseListener();
    });
  }

  // 🔥 الجديد: التحقق التلقائي الدوري
  void _startAutoVerification() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_loading && _storeAvailable) {
        _checkForPendingPurchases();
      }
    });
  }

  Future<void> _checkForPendingPurchases() async {
    try {
      final response = await _iap.queryPastPurchases();
      if (response.purchases.isNotEmpty) {
        addLog("🔍 Auto-Check: وجد ${response.purchases.length} عملية شراء معلقة");
        _onPurchaseUpdate(response.purchases);
      }
    } catch (e) {
      addLog("❌ خطأ في التحقق التلقائي: $e");
    }
  }

  // ===============================
  // 🛒 تهيئة المتجر
  // ===============================
  Future<void> _initializeStore() async {
    try {
      addLog("🔄 بدء تهيئة متجر Apple...");
      final available = await _iap.isAvailable();

      if (!available) {
        addLog("⚠️ المتجر غير متاح → سيتم استخدام المحاكاة");
        if (mounted) {
          setState(() {
            _storeAvailable = false;
            _loading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _storeAvailable = true;
        });
      }

      await _loadProducts();
    } catch (e) {
      addLog("❌ خطأ في تهيئة المتجر: $e");
      if (mounted) {
        setState(() {
          _storeAvailable = false;
          _loading = false;
        });
      }
    }
  }

  // ===============================
  // 📦 تحميل المنتجات
  // ===============================
  Future<void> _loadProducts() async {
    try {
      addLog("🔄 جاري تحميل المنتجات من Apple...");
      final response = await _iap.queryProductDetails(_productIds.toSet());

      if (mounted) {
        setState(() {
          _products = response.productDetails;
          _loading = false;
        });
      }

      if (response.error != null) {
        addLog("⚠️ خطأ في تحميل المنتجات: ${response.error!.message}");
      }

      if (response.notFoundIDs.isNotEmpty) {
        addLog("⚠️ منتجات غير موجودة: ${response.notFoundIDs}");
      }

      if (response.productDetails.isNotEmpty) {
        addLog("✅ تم تحميل ${response.productDetails.length} منتج من Apple");
      }
    } catch (e) {
      addLog("❌ خطأ في تحميل الباقات: $e");
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ===============================
  // 🛒 بدء الشراء
  // ===============================
  void _handlePurchase(ProductDetails product) async {
    if (!_storeAvailable) {
      addLog("⚠️ المتجر غير متاح → تشغيل المحاكاة");
      _showPurchaseSimulation(product);
      return;
    }

    try {
      addLog("STEP 1: 🚀 بداية عملية الشراء الحقيقية");

      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      // 🔥 الجديد: التحقق التلقائي بعد الشراء
      Future.delayed(const Duration(seconds: 5), () {
        addLog("🔄 التحقق التلقائي بعد الشراء...");
        _checkForPendingPurchases();
      });

    } catch (e) {
      addLog("❌ خطأ في بدء عملية الشراء: $e");
      _showDialog("خطأ في الشراء", "حدث خطأ أثناء عملية الشراء: ${e.toString()}");
    }
  }

  // ===============================
  // 🎭 محاكاة الشراء (من الكود القديم)
  // ===============================
  void _showPurchaseSimulation(ProductDetails product) {
    final productData = _demoProductsData.firstWhere(
            (data) => data['id'] == product.id,
        orElse: () => _demoProductsData.first
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildPurchaseSheet(product, productData),
    );
  }

  Widget _buildPurchaseSheet(ProductDetails product, Map<String, dynamic> productData) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // رأس نافذة الشراء
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // محاكاة واجهة Apple
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                // رأس Apple
                Row(
                  children: [
                    const Icon(Icons.apple, color: Colors.black, size: 28),
                    const SizedBox(width: 8),
                    const Text(
                      "Confirm Purchase",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // تفاصيل المنتج
                Row(
                  children: [
                    Icon(productData['icon'] as IconData, color: Colors.deepPurple, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            productData['label'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      product.price,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // محاكاة Face ID
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.fingerprint, color: Colors.blue[700], size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Confirm with Face ID to purchase",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // أزرار التحكم
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "إلغاء",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showPurchaseSuccess(product);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "شراء",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // رسالة توضيحية
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber[100]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.amber[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "تجربة مراجعة - الشراء الحقيقي سيعمل بعد اعتماد الباقات",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseSuccess(ProductDetails product) {
    // تفعيل الباقة حتى في التجربة
    _activateDemoSubscription(product);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            const Text(
              "تمت المحاكاة بنجاح",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "تمت محاكاة شراء '${product.title}' بنجاح",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "✅ النظام جاهز للتشغيل\n✅ واجهة الشراء مكتملة\n✅ ينتظر الاعتماد النهائي من Apple",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.green),
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text("تم", style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _activateDemoSubscription(ProductDetails product) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('user_email') ?? '';

      if (userEmail.isEmpty) {
        addLog('❌ لم يتم العثور على إيميل المستخدم');
        return;
      }

      await _activateUserSubscription(product.id, userEmail);
    } catch (e) {
      addLog('❌ خطأ في التفعيل التجريبي: $e');
    }
  }

  // ===============================
  // 📥 استقبال تحديثات Apple
  // ===============================
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    addLog("STEP 2: 📥 Apple أرسلت PurchaseDetails");

    for (var p in purchases) {
      addLog(" - الحالة: ${p.status}");
      addLog(" - المنتج: ${p.productID}");
      addLog(" - يوجد إيصال؟ ${p.verificationData != null}");

      if (p.status == PurchaseStatus.purchased) {
        addLog("STEP 3: 📄 Apple أرسلت إيصال شراء");

        await _verifyPurchaseWithServer(p);

        if (p.pendingCompletePurchase) {
          await _iap.completePurchase(p);
        }
      }

      if (p.status == PurchaseStatus.error) {
        addLog("❌ خطأ في عملية الشراء: ${p.error?.message}");
        _showDialog("فشل العملية", p.error?.message ?? "حدث خطأ غير متوقع.");
      } else if (p.status == PurchaseStatus.pending) {
        addLog("⏳ العملية قيد المعالجة...");
        _showSnack("⏳ العملية قيد المعالجة...");
      }
    }
  }

  // ===============================
  // 🌐 إرسال الإيصال للسيرفر
  // ===============================
  Future<void> _verifyPurchaseWithServer(PurchaseDetails purchase) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userEmail = prefs.getString('user_email') ?? '';
    const secret = "06acbbcf779f421589311198fddf70ee";
    final receiptData = purchase.verificationData.serverVerificationData;

    addLog("STEP 4: 📦 إرسال الإيصال إلى السيرفر");
    addLog("Length: ${receiptData.length}");

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

      addLog("STEP 5: 📬 رد السيرفر: ${response.statusCode}");
      addLog(response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSnack("🎉 تم تفعيل ${data['plan']} بنجاح!");

          // العودة للرئيسية بعد ثانيتين
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.of(context).pop();
          });
        } else {
          // ❌ فشل تحقق Apple - جرب التفعيل المباشر
          addLog("⚠️ فشل تحقق Apple → تشغيل Fallback");
          _showSnack("⚠️ جرب التفعيل المباشر...");
          await _activateUserSubscription(purchase.productID, userEmail);
        }
      } else {
        // ❌ خطأ في السيرفر - جرب التفعيل المباشر
        addLog("⚠️ خطأ في السيرفر → تشغيل Fallback");
        _showSnack("⚠️ جرب التفعيل المباشر...");
        await _activateUserSubscription(purchase.productID, userEmail);
      }
    } catch (e) {
      // ❌ خطأ في الاتصال - جرب التفعيل المباشر
      addLog("❌ خطأ في الاتصال → تشغيل Fallback");
      _showSnack("⚠️ جرب التفعيل المباشر...");
      await _activateUserSubscription(purchase.productID, userEmail);
    }
  }

  // ===============================
  // 🔧 Fallback Manual Activation
  // ===============================
  Future<void> _activateUserSubscription(String productId, String userEmail) async {
    addLog("STEP 6: ⚠️ تفعيل Fallback للمنتج: $productId");

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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          addLog('✅ تم تفعيل الباقة: ${data['plan_name']}');

          // حفظ محلي
          await prefs.setString('user_subscription', productId);
          await prefs.setBool('is_premium', true);
          await prefs.setString('subscription_expires', data['expires_date'] ?? '');

          _showSnack("🎉 تم تفعيل ${data['plan_name']} بنجاح!");

          // العودة للرئيسية
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.of(context).pop();
          });
        } else {
          addLog("❌ فشل Fallback: ${data['message']}");
          _showDialog("خطأ", data['message'] ?? "فشل في تفعيل الباقة");
        }
      } else {
        addLog("❌ فشل Fallback: ${response.body}");
      }
    } catch (e) {
      addLog('❌ خطأ في تفعيل الباقة: $e');
      _showDialog("خطأ", "حدث خطأ: $e");
    }
  }

  // ===============================
  // 🎨 واجهة المستخدم
  // ===============================
  @override
  Widget build(BuildContext context) {
    final bool isStoreAvailable = _storeAvailable && _products.isNotEmpty;
    final List<ProductDetails> displayProducts = isStoreAvailable ? _products : _demoProducts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FF),
      appBar: AppBar(
        title: const Text(
          "باقات Bito Plus",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.deepPurple),
            SizedBox(height: 16),
            Text(
              "جاري تحميل الباقات...",
              style: TextStyle(fontSize: 16, color: Colors.deepPurple),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // 🔥 زر عرض الأخطاء المحسن
          TextButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("سجل الأخطاء (DEBUG)"),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 300,
                    child: SingleChildScrollView(
                      child: Text(
                        debugLogs.isEmpty
                            ? "لا توجد أخطاء"
                            : debugLogs.join("\n\n"),
                      ),
                    ),
                  ),
                  actions: [
                    // 🔥 زر التحقق اليدوي
                    ElevatedButton(
                      onPressed: () {
                        addLog("🔍 تحقق يدوي من المشتريات...");
                        _checkForPendingPurchases();
                        Navigator.pop(context);
                      },
                      child: const Text("🔍 تحقق يدوي"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("إغلاق"),
                    ),
                  ],
                ),
              );
            },
            child: const Text("📄 عرض الأخطاء (DEBUG)",
                style: TextStyle(color: Colors.red)),
          ),

          // ⭐ رسالة الاستخدام اللامحدود
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
            ),
            child: const Text(
              "⭐ جميع الباقات تأتي مع استخدام لا محدود",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),

          // 🟪 الباقات
          _buildSimplePlan(
            title: "الباقة الأسبوعية",
            price: "٢٩٫٩٩ ر.س",
            duration: "7 أيام",
            onTap: () => _handlePurchase(
              displayProducts.firstWhere((p) => p.id == "bito.weekly1"),
            ),
          ),

          _buildSimplePlan(
            title: "الباقة الشهرية",
            price: "٧٩٫٩٩ ر.س",
            duration: "30 يوم",
            onTap: () => _handlePurchase(
              displayProducts.firstWhere((p) => p.id == "bito.monthly1"),
            ),
          ),

          _buildSimplePlan(
            title: "الباقة السنوية",
            price: "٢٩٩٫٩٩ ر.س",
            duration: "365 يوم",
            saveTag: "🔥 وفر 69%",
            onTap: () => _handlePurchase(
              displayProducts.firstWhere((p) => p.id == "bito.yearly1"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplePlan({
    required String title,
    required String price,
    required String duration,
    required VoidCallback onTap,
    String? saveTag,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // العنوان + وسم التوفير
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              if (saveTag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    saveTag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // السعر
          Text(
            price,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          // المدة
          Text(
            duration,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          // زر الاشتراك
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "اشترك الآن",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================
  // 🎯 دوال المساعدة
  // ===============================
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
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

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}