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
  final List<String> _productIds = ['bito.weekly1', 'bito.monthly1', 'bito.yearly1'];


  // بيانات الباقات المعدلة بالريال السعودي
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

  @override
  void initState() {
    super.initState();
    _initializeStore();
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate, onDone: () {
      _subscription.cancel();
    });
  }

  Future<void> _initializeStore() async {
    try {
      print('🔄 جاري تهيئة متجر التطبيقات...');

      final available = await _iap.isAvailable();
      print('📱 حالة المتجر: $available');

      if (!available) {
        print('⚠️ المتجر غير متاح - استخدام وضع المحاكاة');
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
      print('❌ خطأ في تهيئة المتجر: $e');
      if (mounted) {
        setState(() {
          _storeAvailable = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadProducts() async {
    try {
      print('🔄 جاري تحميل المنتجات...');

      final response = await _iap.queryProductDetails(_productIds.toSet());

      if (mounted) {
        setState(() {
          _products = response.productDetails;
          _loading = false;
        });
      }

      if (response.error != null) {
        print('⚠️ خطأ في تحميل المنتجات: ${response.error!.message}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        print('⚠️ منتجات غير موجودة: ${response.notFoundIDs}');
      }

      if (response.productDetails.isNotEmpty) {
        print('✅ تم تحميل ${response.productDetails.length} منتج');
      }

    } catch (e) {
      print('❌ خطأ في تحميل الباقات: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _handlePurchase(ProductDetails product) async {
    if (!_storeAvailable) {
      _showPurchaseSimulation(product);
      return;
    }

    try {
      print('🔄 بدء عملية الشراء: ${product.id}');
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print('❌ خطأ في الشراء: $e');
      _showDialog("خطأ في الشراء", "حدث خطأ أثناء عملية الشراء: ${e.toString()}");
    }
  }

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
                    Icon(Icons.apple, color: Colors.black, size: 28),
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
    // 🔥 تفعيل الباقة حتى في التجربة
    _activateDemoSubscription(product);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
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
        print('❌ لم يتم العثور على إيميل المستخدم');
        return;
      }

      final response = await http.post(
        Uri.parse("https://studybito.com/wp-json/bito/v1/demo_subscription"),
        body: {
          'product_id': product.id,
          'user_email': userEmail,
          'is_demo': 'true'
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ تم تفعيل الباقة التجريبية: ${data['plan']} للمستخدم: $userEmail');
        } else {
          print('❌ فشل تفعيل الباقة: ${data['message']}');
        }
      } else {
        print('❌ خطأ في السيرفر: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ خطأ في التفعيل التجريبي: $e');
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
      } else if (purchase.status == PurchaseStatus.pending) {
        _showSnack("⏳ العملية قيد المعالجة...");
      }
    }
  }

  Future<void> _verifyPurchaseWithServer(PurchaseDetails purchase) async {
    const secret = "06acbbcf779f421589311198fddf70ee";
    final receiptData = purchase.verificationData.serverVerificationData;

    // 🔥 جلب الإيميل والتوكن
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email') ?? '';
    final token = prefs.getString('auth_token') ?? '';

    print("🔎 Email Sent: $userEmail");
    print("🔎 Token Sent: $token");

    try {
      final response = await http.post(
        Uri.parse("https://studybito.com/wp-json/bito/v1/verify_ios_receipt"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "receipt-data": receiptData,
          "password": secret,
          "user_email": userEmail,
          "bito_token": token,  // ← ← تم إضافة التوكن هنا 🔥
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSuccessAndGoToStudy();
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
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

          // 🟪 الباقة الأسبوعية
          _buildSimplePlan(
            title: "الباقة الأسبوعية",
            price: "٢٩٫٩٩ ر.س",
            duration: "7 أيام",
            onTap: () => _handlePurchase(
              displayProducts.firstWhere((p) => p.id == "bito.weekly1"),
            ),
          ),

          // 🟪 الباقة الشهرية
          _buildSimplePlan(
            title: "الباقة الشهرية",
            price: "٧٩٫٩٩ ر.س",
            duration: "30 يوم",
            onTap: () => _handlePurchase(
              displayProducts.firstWhere((p) => p.id == "bito.monthly1"),
            ),
          ),

          // 🟪 الباقة السنوية + وفر 69%
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
  void _showSuccessAndGoToStudy() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "مبروك! 🎉",
          style: TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          "تم تفعيل الباقة بنجاح.\nيمكنك الآن استخدام جميع خدمات بيتو.",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // إغلاق الرسالة
              Navigator.pushReplacementNamed(context, "/study"); // الذهاب للصفحة
            },
            child: const Text(
              "ابدأ الآن",
              style: TextStyle(color: Colors.deepPurple),
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

