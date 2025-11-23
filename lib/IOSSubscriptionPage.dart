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
        print('⚠️ المتجر غير متاح - لن يتمكن المستخدم من الشراء الآن');
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
// 🔥 🔥 🔥 أضف هذا الكود هنا مباشرة بعد _loadProducts 🔥 🔥 🔥
  ProductDetails _getProductById(String productId) {
    final bool isStoreAvailable = _storeAvailable && _products.isNotEmpty;
    final List<ProductDetails> displayProducts = isStoreAvailable ? _products : _demoProducts;

    try {
      return displayProducts.firstWhere(
            (p) => p.id == productId,
        orElse: () => _demoProducts.firstWhere((p) => p.id == productId),
      );
    } catch (e) {
      return _demoProducts.firstWhere((p) => p.id == productId);
    }
  }
// 🔥 🔥 🔥 نهاية الإضافة 🔥 🔥 🔥

  void _handlePurchase(ProductDetails product) async {
    // نتأكد أن المتجر متاح وأن المنتج موجود فعليًا في قائمة المنتجات القادمة من Apple
    final bool productExists =
    _products.any((p) => p.id == product.id);

    if (!_storeAvailable || !productExists) {
      _showDialog(
        "المشتريات غير متاحة",
        "المشتريات داخل التطبيق غير متاحة حاليًا. يرجى المحاولة لاحقًا.",
      );
      return;
    }

    try {
      print('🔄 بدء عملية الشراء: ${product.id}');
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      print('❌ خطأ في الشراء: $e');
      _showDialog(
        "خطأ في الشراء",
        "حدث خطأ أثناء عملية الشراء: ${e.toString()}",
      );
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final userEmail = prefs.getString('user_email') ?? '';
    const secret = "06acbbcf779f421589311198fddf70ee";
    final receiptData = purchase.verificationData.serverVerificationData;
    print("📦 Server Receipt: $receiptData");

    try {
      final response = await http.post(
        Uri.parse("https://studybito.com/wp-json/bito/v1/ios_purchase"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "receipt-data": receiptData,
          "password": secret,
          "user_email": userEmail,
          "product_id": purchase.productID,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSnack("🎉 تم تفعيل ${data['plan']} بنجاح!");

          // 🔥 حفظ البيانات المحلي - الإضافة المهمة
          await prefs.setString('user_subscription', data['product_id']);
          await prefs.setBool('is_premium', true);
          await prefs.setString('subscription_expires', data['expires_date'] ?? '');

          // العودة الآمنة للرئيسية بعد ثانيتين
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }
        else {
          // ❌ فشل تحقق Apple - جرب التفعيل المباشر

        }
      } else {
        // ❌ خطأ في السيرفر - جرب التفعيل المباشر

      }
    } catch (e) {
      // ❌ خطأ في الاتصال - جرب التفعيل المباشر

    }
  }
// ✅ أضف هذه الدالة هنا
  Future<void> _activateUserSubscription(String productId, String userEmail) async {
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
          print('✅ تم تفعيل الباقة: ${data['plan_name']}');

          // حفظ محلي
          await prefs.setString('user_subscription', productId);
          await prefs.setBool('is_premium', true);
          await prefs.setString('subscription_expires', data['expires_date'] ?? '');

          _showSnack("🎉 تم تفعيل ${data['plan_name']} بنجاح!");

          // العودة للرئيسية
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        } else {
          _showDialog("خطأ", data['message'] ?? "فشل في تفعيل الباقة");
        }
      }
    } catch (e) {
      print('❌ خطأ في تفعيل الباقة: $e');
      _showDialog("خطأ", "حدث خطأ: $e");
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
                _getProductById("bito.weekly1")
            ),
          ),

          // 🟪 الباقة الشهرية
          _buildSimplePlan(
            title: "الباقة الشهرية",
            price: "٧٩٫٩٩ ر.س",
            duration: "30 يوم",
            onTap: () => _handlePurchase(
              _getProductById("bito.monthly1"),
            ),
          ),

          // 🟪 الباقة السنوية + وفر 69%
          _buildSimplePlan(
            title: "الباقة السنوية",
            price: "٢٩٩٫٩٩ ر.س",
            duration: "365 يوم",
            saveTag: "🔥 وفر 69%",
            onTap: () => _handlePurchase(
              _getProductById("bito.yearly1"),
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
