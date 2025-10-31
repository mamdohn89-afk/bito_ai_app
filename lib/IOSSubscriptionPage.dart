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
  bool _loading = true;
  List<ProductDetails> _products = [];
  final List<String> _productIds = ['bito.weekly', 'bito.monthly', 'bito.yearly'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _iap.purchaseStream.listen(_onPurchaseUpdate);
  }

  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails(_productIds.toSet());
    if (response.notFoundIDs.isEmpty) {
      setState(() {
        _products = response.productDetails;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ تعذر تحميل الباقات')),
      );
    }
  }

  // ✅ تنفيذ عملية الشراء
  void _buy(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // ✅ التعامل مع نتيجة الدفع
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ جاري التحقق من الدفع...')),
        );

        // إرسال الإيصال للتحقق في السيرفر
        await _verifyPurchaseWithServer(purchase);

        // ✅ بعد نجاح الدفع، توجيه المستخدم
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/study');
        }
      } else if (purchase.status == PurchaseStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ في الدفع: ${purchase.error}')),
        );
      }
    }
  }

  // ✅ إرسال الإيصال للتحقق إلى WordPress
  Future<void> _verifyPurchaseWithServer(PurchaseDetails purchase) async {
    const String secret = "06acbbcf779f421589311198fddf70ee"; // App-Specific Shared Secret
    final String receiptData = purchase.verificationData.serverVerificationData;

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ تم تفعيل الباقة بنجاح: ${data['plan']}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ فشل التحقق من الإيصال: ${data['message']}')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ فشل الاتصال بالخادم للتحقق من الدفع')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("باقات Bito AI"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: _products.map((p) {
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 5,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ListTile(
                title: Text(
                  p.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(p.description),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _buy(p),
                  child: Text("اشترك ${p.price}"),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
