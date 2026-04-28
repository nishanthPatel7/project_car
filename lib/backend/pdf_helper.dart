import 'dart:io';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class PdfHelper {
  static Future<void> generateJobInvoice(Map<String, dynamic> job) async {
    final pdf = pw.Document();

    // Define professional color palette from HTML
    const accent = PdfColor.fromInt(0xFF0E2A47);
    const ink = PdfColor.fromInt(0xFF0F0F0D);
    const ink2 = PdfColor.fromInt(0xFF3A3A36);
    const ink3 = PdfColor.fromInt(0xFF7A7A72);
    const rule = PdfColor.fromInt(0xFFE8E6E0);
    const bg = PdfColor.fromInt(0xFFFAFAF7);
    const accentLt = PdfColor.fromInt(0xFFE8EEF5);

    final Map<String, dynamic> costs = job['cost_details'] is String 
        ? jsonDecode(job['cost_details']) 
        : Map<String, dynamic>.from(job['cost_details'] ?? {});
    
    final List<dynamic> services = job['service_types'] is String 
        ? jsonDecode(job['service_types']) 
        : List<dynamic>.from(job['service_types'] ?? []);

    final String vehicleNo = job['vehicle_no'] ?? "N/A";
    final String dateStr = DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0).toString().split(' ')[0];
    final String timeStr = DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0).toString().split(' ')[1].substring(0, 5);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero, // Full page background control
        build: (pw.Context context) {
          return pw.Container(
            color: bg,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── HEADER BAND ──
                pw.Container(
                  color: accent,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("AutoNex", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                          pw.Text("AUTOMOTIVE SERVICES", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey400, letterSpacing: 1.5)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("SERVICE INVOICE", style: pw.TextStyle(fontSize: 20, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 10),
                          pw.Text("Invoice No: #${job['invoice_no'] ?? 'N/A'}", style: pw.TextStyle(fontSize: 11, color: PdfColors.grey300)),
                          pw.Text("Generated on: ${DateFormat('dd MMM yyyy · hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0))}", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey300)),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── STATUS ROW ──
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 0),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    border: pw.Border.all(color: rule),
                    borderRadius: const pw.BorderRadius.vertical(bottom: pw.Radius.circular(12)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("Service completed on $dateStr", style: pw.TextStyle(fontSize: 11, color: ink3)),
                    ],
                  ),
                ),

                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(height: 32),
                      // ── DUAL INFO ──
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: _buildInfoSection("Customer Details", [
                              _buildInfoRow(ink, ink3, "Name", job['display_name'] ?? job['customer_name'] ?? job['customerName'] ?? "AutoNex Customer"),
                              _buildInfoRow(ink, ink3, "Vehicle", "${job['brand'] ?? ''} $vehicleNo"),
                              _buildInfoRow(ink, ink3, "Model", job['vehicle_type'] ?? "Car"),
                            ]),
                          ),
                          pw.SizedBox(width: 40),
                          pw.Expanded(
                            child: _buildInfoSection("Garage Details", [
                              _buildInfoRow(ink, ink3, "Garage", job['garage_name'] ?? job['garageName'] ?? job['garage'] ?? "Partner Garage"),
                              _buildInfoRow(ink, ink3, "Service", job['mode'] ?? "Standard"),
                              _buildInfoRow(ink, ink3, "Address", "${job['garage_city'] ?? ''}${job['garage_city'] != null ? ', ' : ''}${job['garage_district'] ?? ''}"),
                              _buildInfoRow(ink, ink3, "State", job['garage_state'] ?? "India"),
                            ]),
                          ),
                        ],
                      ),

                      pw.SizedBox(height: 40),
                      // ── SERVICES TABLE ──
                      pw.Text("SERVICE DETAILS", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: ink3, letterSpacing: 1.2)),
                      pw.SizedBox(height: 12),
                      pw.Table(
                        border: const pw.TableBorder(bottom: pw.BorderSide(color: rule, width: 0.5)),
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text("SERVICE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: ink2))),
                              pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text("AMOUNT", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: ink2), textAlign: pw.TextAlign.right)),
                            ],
                          ),
                          ...services.map((s) {
                            final item = costs[s];
                            final price = item is Map 
                              ? (int.tryParse(item['cost'].toString()) ?? 0) * (int.tryParse(item['qty'].toString()) ?? 1)
                              : (int.tryParse(item.toString()) ?? 0);

                            return pw.TableRow(
                              children: [
                                pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(s.toString(), style: const pw.TextStyle(fontSize: 12, color: ink))),
                                pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text("Rs. $price", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: ink), textAlign: pw.TextAlign.right)),
                              ],
                            );
                          }),
                        ],
                      ),

                      // ── SUMMARY ──
                      pw.SizedBox(height: 24),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.end,
                        children: [
                          pw.Container(
                            width: 240,
                            padding: const pw.EdgeInsets.all(20),
                            decoration: pw.BoxDecoration(color: accent, borderRadius: pw.BorderRadius.circular(16)),
                            child: pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text("GRAND TOTAL", style: pw.TextStyle(color: PdfColors.grey300, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                                pw.Text("Rs. ${job['total_amount'] ?? 0}", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 22)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),
                // ── FOOTER ──
                pw.Container(
                  color: PdfColors.grey50,
                  padding: const pw.EdgeInsets.all(40),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("Thank you for choosing AutoNex!", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: ink)),
                              pw.SizedBox(height: 4),
                              pw.Text("Official Invoice generated via AutoNex Terminal.", style: pw.TextStyle(fontSize: 10, color: ink3)),
                            ],
                          ),
                          pw.Text("Powered by Mastech", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: accent)),
                        ],
                      ),
                      pw.SizedBox(height: 20),
                      pw.Divider(color: rule, thickness: 0.5),
                      pw.SizedBox(height: 12),
                      pw.Text("This is a computer-generated document and does not require a signature.", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey400)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Save to device with custom name
    final output = await getApplicationDocumentsDirectory();
    final String cleanVehicle = vehicleNo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final String fileName = "For10-Service-$cleanVehicle-$dateStr.pdf";
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(await pdf.save());
    
    // Also show Print Preview / Share
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: fileName);
  }

  static pw.Widget _buildInfoSection(String title, List<pw.Widget> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600, letterSpacing: 1.2)),
        pw.SizedBox(height: 12),
        ...rows,
      ],
    );
  }

  static pw.Widget _buildInfoRow(PdfColor ink, PdfColor ink3, String key, String val) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(key, style: pw.TextStyle(fontSize: 11, color: ink3)),
          pw.Text(val, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: ink)),
        ],
      ),
    );
  }
}
