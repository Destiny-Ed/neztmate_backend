import 'dart:io';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:neztmate_backend/features/auth_user/models/user_model.dart';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';

class LeasePdfService {
  Future<String> generateLeasePdf({
    required LeaseModel lease,
    required UnitModel unit,
    required PropertyModel property,
    required User tenant,
    required User landowner,
  }) async {
    final pdf = pw.Document();

    String formatDate(DateTime date) {
      return DateFormat('MMMM dd, yyyy').format(date);
    }

    pw.Widget sectionTitle(String title) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      );
    }

    pw.Widget paragraph(String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(text, style: const pw.TextStyle(fontSize: 11, lineSpacing: 4)),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),

        header: (context) {
          return pw.Column(
            children: [
              pw.Text(
                'RESIDENTIAL LEASE AGREEMENT',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
            ],
          );
        },

        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Page ${context.pageNumber}', style: const pw.TextStyle(fontSize: 9)),
          );
        },

        build: (context) => [
          sectionTitle('1. PARTIES'),

          paragraph(
            'This Residential Lease Agreement is entered into between '
            '${landowner.fullName} ("Landlord") and '
            '${tenant.fullName} ("Tenant").',
          ),

          paragraph(
            'Lease Reference Number: ${lease.id}\n'
            'Agreement Date: ${formatDate(DateTime.now())}',
          ),

          sectionTitle('2. PROPERTY'),

          paragraph(
            'The Landlord hereby leases to the Tenant the residential '
            'property located at ${property.address}, '
            'Unit ${unit.unitNumber}.',
          ),

          sectionTitle('3. LEASE TERM'),

          paragraph(
            'The lease shall commence on '
            '${formatDate(lease.startDate)} and terminate on '
            '${formatDate(lease.endDate)}.',
          ),

          // sectionTitle('4. RENT'),

          // paragraph(
          //   'Tenant agrees to pay monthly rent of '
          //   '₦${unit.monthlyRent.toStringAsFixed(2)} '
          //   'on or before the due date each month.',
          // ),

          // if (lease.securityDeposit != null)
          //   paragraph(
          //     'A refundable security deposit of '
          //     '₦${lease.securityDeposit!.toStringAsFixed(2)} '
          //     'shall be paid before move-in.',
          //   ),
          sectionTitle('4. RENT & FEES'),

          paragraph(
            'Tenant agrees to pay monthly rent of '
            '₦${unit.monthlyRent.toStringAsFixed(2)} '
            'according to the agreed payment schedule outlined by the Landlord.',
          ),

          if (unit.fees != null && unit.fees!.isNotEmpty) ...[
            paragraph(
              'In addition to the annual rent, the Tenant agrees to pay the following fees and charges where applicable. '
              'These fees form part of this Lease Agreement and are legally enforceable.',
            ),

            pw.Bullet(text: ''),

            ...unit.fees!.map(
              (fee) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Bullet(
                  text:
                      '${fee.name} - '
                      '${fee.isPercentage ? '${fee.amount}%' : '₦${fee.amount.toStringAsFixed(2)}'} '
                      '(${fee.isOneTime ? 'One-Time Fee' : 'Recurring Fee'})',
                ),
              ),
            ),
          ],

          pw.SizedBox(height: 10),

          paragraph(
            'The Tenant acknowledges and accepts responsibility for all applicable fees listed above. '
            'Failure to pay required recurring charges may constitute a breach of this Lease Agreement.',
          ),

          //table format
          // if (unit.fees != null && unit.fees!.isNotEmpty) ...[
          //   pw.SizedBox(height: 10),

          //   pw.Table(
          //     border: pw.TableBorder.all(),
          //     columnWidths: {
          //       0: const pw.FlexColumnWidth(3),
          //       1: const pw.FlexColumnWidth(2),
          //       2: const pw.FlexColumnWidth(2),
          //     },
          //     children: [
          //       pw.TableRow(
          //         decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          //         children: [_tableCell('Fee'), _tableCell('Amount'), _tableCell('Type')],
          //       ),

          //       ...unit.fees!.map(
          //         (fee) => pw.TableRow(
          //           children: [
          //             _tableCell(fee.name),
          //             _tableCell(fee.isPercentage ? '${fee.amount}%' : '₦${fee.amount.toStringAsFixed(2)}'),
          //             _tableCell(fee.isOneTime ? 'One-Time' : 'Recurring'),
          //           ],
          //         ),
          //       ),
          //     ],
          //   ),

          //   pw.SizedBox(height: 20),
          // ],
          sectionTitle('5. TENANT RESPONSIBILITIES'),

          paragraph(
            'Tenant shall maintain the premises in good condition, '
            'comply with applicable laws, and notify the Landlord '
            'of maintenance issues promptly.',
          ),

          sectionTitle('6. LANDLORD RESPONSIBILITIES'),

          paragraph(
            'Landlord shall ensure the premises remain habitable and '
            'provide necessary repairs within a reasonable timeframe.',
          ),

          sectionTitle('7. MAINTENANCE'),

          paragraph(
            'Maintenance requests shall be submitted through the '
            'NeztMate platform whenever possible.',
          ),

          sectionTitle('8. TERMINATION'),

          paragraph(
            'Either party may terminate this Agreement in accordance '
            'with applicable law and the notice period specified herein.',
          ),

          sectionTitle('9. GOVERNING LAW'),

          paragraph(
            'This Agreement shall be governed by the laws applicable '
            'within the jurisdiction where the property is located.',
          ),

          sectionTitle('10. LANDLORD ACKNOWLEDGEMENT'),

          paragraph(
            'The Landlord confirms that they are the lawful owner or authorized representative '
            'of the Property and agree to all terms contained within this Lease Agreement.',
          ),

          sectionTitle('11. ELECTRONIC SIGNATURE CONSENT'),

          paragraph(
            'The Parties agree that electronic signatures and records generated through '
            'the NeztMate platform shall have the same legal force and effect as handwritten signatures. '
            'The Parties further agree that this Agreement may be executed electronically '
            'and stored digitally for evidentiary purposes.',
          ),

          pw.SizedBox(height: 40),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 180, child: pw.Divider()),
                  pw.Text('Landlord Signature'),
                ],
              ),

              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 180, child: pw.Divider()),
                  pw.Text('Date'),
                ],
              ),
            ],
          ),

          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'DIGITAL SIGNATURE SECTION',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                ),

                pw.SizedBox(height: 20),

                pw.Text(
                  'By signing below, the Tenant acknowledges that they have '
                  'read, understood, and agreed to the terms contained within '
                  'this Lease Agreement.',
                ),

                pw.SizedBox(height: 40),

                pw.Text('TENANT DIGITAL SIGNATURE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),

                pw.SizedBox(height: 60),

                pw.Container(
                  height: 130,
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                ),

                pw.SizedBox(height: 10),

                pw.Text(
                  'Upon electronic execution, NeztMate will automatically insert the Tenant signature, '
                  'signing date, Lease ID, verification details, and digital audit record into this section.',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final file = File('lease_${lease.id}.pdf');

    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  // pw.Widget _tableCell(String text) {
  //   return pw.Padding(
  //     padding: const pw.EdgeInsets.all(8),
  //     child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
  //   );
  // }
}
