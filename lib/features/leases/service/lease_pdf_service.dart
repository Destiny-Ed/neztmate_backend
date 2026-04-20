import 'dart:io';
import 'package:neztmate_backend/features/leases/models/leases_model.dart';
import 'package:neztmate_backend/features/properties/models/property_model.dart';
import 'package:neztmate_backend/features/units/models/unit_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
 
import 'package:neztmate_backend/features/auth_user/models/user_model.dart';

class LeasePdfService {
  Future<String> generateLeasePdf({
    required LeaseModel lease,
    required UnitModel unit,
    required PropertyModel property,
    required User tenant,
    required User landowner,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'RESIDENTIAL LEASE AGREEMENT',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Text('Date: ${DateTime.now().toIso8601String().split('T')[0]}'),
            pw.SizedBox(height: 10),

            pw.Text('Between:'),
            pw.Text('Landlord: ${landowner.fullName}'),
            pw.Text('Tenant: ${tenant.fullName}'),
            pw.SizedBox(height: 20),

            pw.Text('Property Details:'),
            pw.Text('Property: ${property.name}'),
            pw.Text('Address: ${property.address}'),
            pw.Text('Unit: ${unit.unitNumber}'),
            pw.Text('Bedrooms: ${unit.bedrooms ?? "N/A"}'),
            pw.SizedBox(height: 20),

            pw.Text('Lease Terms:'),
            pw.Text('Start Date: ${lease.startDate.toIso8601String().split('T')[0]}'),
            pw.Text('End Date: ${lease.endDate.toIso8601String().split('T')[0]}'),
            pw.Text('Monthly Rent: ₦${lease.monthlyRent.toStringAsFixed(2)}'),
            if (lease.securityDeposit != null)
              pw.Text('Security Deposit: ₦${lease.securityDeposit!.toStringAsFixed(2)}'),

            pw.SizedBox(height: 30),
            pw.Text(
              'This is a system-generated lease agreement. Please review carefully before signing.',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
          ],
        ),
      ),
    );

    // Save to temporary file
    final output = File('lease_${lease.id}.pdf');
    await output.writeAsBytes(await pdf.save());

    // TODO: Upload to Firebase Storage and return public URL
    // For now, return local path (you'll replace this with storage URL)
    return output.path;
  }
}
