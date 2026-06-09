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

          sectionTitle('4. RENT'),

          paragraph(
            'Tenant agrees to pay yearly rent of '
            '₦${unit.yearlyRent.toStringAsFixed(2)} '
            'on or before the due date each month.',
          ),

          if (lease.securityDeposit != null)
            paragraph(
              'A refundable security deposit of '
              '₦${lease.securityDeposit!.toStringAsFixed(2)} '
              'shall be paid before move-in.',
            ),

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

          pw.SizedBox(height: 40),

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
                  'This section will be completed automatically by NeztMate upon signing.',
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
}
