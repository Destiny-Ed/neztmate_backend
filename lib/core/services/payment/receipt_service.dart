// import 'dart:io';
// import 'package:neztmate_backend/features/payments/models/payments.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;

// class ReceiptService {
//   /// Generate custom PDF receipt and return file path or URL
//   /// Currently returns a placeholder - uncomment when ready
//   Future<String?> generateReceipt(PaymentModel payment, String userFullName) async {
//     // ==================== PLACEHOLDER - COMMENTED ====================
//     /*
//     try {
//       final pdf = pw.Document();

//       pdf.addPage(
//         pw.Page(
//           build: (pw.Context context) => pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Center(
//                 child: pw.Text(
//                   'NeztMate Receipt',
//                   style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
//                 ),
//               ),
//               pw.SizedBox(height: 20),
//               pw.Text('Receipt ID: ${payment.id}'),
//               pw.Text('Date: ${payment.paidDate?.toIso8601String() ?? DateTime.now().toIso8601String()}'),
//               pw.SizedBox(height: 10),
//               pw.Text('Payer: $userFullName'),
//               pw.Text('Amount: ₦${payment.amount.toStringAsFixed(2)}'),
//               pw.Text('Status: ${payment.status}'),
//               pw.SizedBox(height: 20),
//               pw.Text('Thank you for using NeztMate!', style: pw.TextStyle(fontSize: 14)),
//             ],
//           ),
//         ),
//       );

//       // Save to temporary file
//       final output = File('receipt_${payment.id}.pdf');
//       await output.writeAsBytes(await pdf.save());

//       // TODO: Upload to Firebase Storage and return public URL
//       // final url = await uploadToStorage(output, payment.id);
//       // return url;

//       return output.path; // temporary local path for now
//     } catch (e) {
//       print('PDF generation error: $e');
//       return null;
//     }
//     */
//     // ==================== END PLACEHOLDER ====================

//     // For now, return Paystack receipt URL as fallback
//     return null; // Will use Paystack receipt by default
//   }
// }
