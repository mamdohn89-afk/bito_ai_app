import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReceiptDebugPage extends StatelessWidget {
  final String receipt;
  final String logs;

  const ReceiptDebugPage({
    super.key,
    required this.receipt,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: const Text("🔍 IAP Receipt Debug"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Receipt box
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurpleAccent),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    "📦 RECEIPT:\n\n$receipt\n\n======================\n\n📜 LOGS:\n\n$logs",
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 12,
                      fontFamily: "monospace",
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: "RECEIPT:\n$receipt\n\nLOGS:\n$logs",
                      ));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("📋 تم النسخ بنجاح"),
                          backgroundColor: Colors.deepPurple,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Copy All"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text("Close"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
