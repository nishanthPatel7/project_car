import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';

class GenerateBillPage extends StatefulWidget {
  const GenerateBillPage({super.key});

  @override
  State<GenerateBillPage> createState() => _GenerateBillPageState();
}

class _GenerateBillPageState extends State<GenerateBillPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final List<String> _selectedServices = [];
  final Map<String, int> _serviceCosts = {};
  bool _isSubmitting = false;
  String _vehicleType = 'Car';
  String? _selectedBrand;
  String? _vehicleError;
  String? _serviceError;
  late String _invoiceNo = "Loading...";

  @override
  void initState() {
    super.initState();
    _fetchInvoiceNo();
  }

  void _fetchInvoiceNo() async {
    final res = await ApiService().generateInvoiceNo();
    if (res['status'] == 'success') {
      setState(() => _invoiceNo = res['invoiceNo']);
    }
  }

  final List<Map<String, dynamic>> _serviceItems = [
    {'name': 'General', 'icon': Icons.settings_rounded},
    {'name': 'Oil', 'icon': Icons.opacity_rounded},
    {'name': 'Brake', 'icon': Icons.disc_full_rounded},
    {'name': 'Engine', 'icon': Icons.engineering_rounded},
    {'name': 'Body Wash', 'icon': Icons.wash_rounded},
    {'name': 'AC', 'icon': Icons.ac_unit_rounded},
    {'name': 'Battery', 'icon': Icons.battery_charging_full_rounded},
    {'name': 'Tyre', 'icon': Icons.tire_repair_rounded},
    {'name': 'Alignment', 'icon': Icons.align_vertical_center_rounded},
    {'name': 'Painting', 'icon': Icons.format_paint_rounded},
  ];

  final Map<String, List<String>> _topBrands = {
    'Car': ['Maruti Suzuki', 'Hyundai', 'Tata Motors', 'Mahindra', 'Toyota', 'Kia', 'Honda', 'Skoda', 'MG Motor', 'Volkswagen'],
    'Bike': ['Hero MotoCorp', 'Honda', 'TVS', 'Bajaj Auto', 'Royal Enfield', 'Suzuki', 'Yamaha', 'KTM', 'Jawa', 'Kawasaki']
  };

  int get _totalAmount => _serviceCosts.values.fold(0, (sum, val) => sum + val);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text("GENERATE BILL", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textBody, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          SizedBox(width: 48), // Balancing leading icon
        ],
      ),
      body: Container(
        color: AppTheme.background,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInDown(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Tax Invoice", style: TextStyle(color: AppTheme.textBody, fontSize: 24, fontWeight: FontWeight.bold)),
                            Text("#$_invoiceNo", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                        Text("TOTAL: ₹$_totalAmount", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildLabel("1) Vehicle Details", error: _vehicleError),
                  FadeInUp(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _buildTypeTile("Car", Icons.directions_car_rounded),
                            const SizedBox(width: 12),
                            _buildTypeTile("Bike", Icons.pedal_bike_rounded),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildBrandDropdown(),
                        const SizedBox(height: 16),
                        _buildTextField(_vehicleController, "Vehicle Number", Icons.confirmation_number_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel("2) Services & Costs", error: _serviceError),
                      IconButton(
                        onPressed: _showAddCustomServiceDialog,
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 20),
                      ),
                    ],
                  ),
                  FadeInUp(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: _serviceItems.length,
                      itemBuilder: (context, index) {
                        final item = _serviceItems[index];
                        return _buildServiceWithCostTile(item['name'], item['icon']);
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  if (_selectedServices.isNotEmpty) ...[
                    _buildLabel("Itemized Bill Summary"),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.surfaceLighter)),
                      child: Column(
                        children: [
                          ..._selectedServices.map((s) => _buildSummaryRow(s, _serviceCosts[s] ?? 0)),
                          const Divider(color: AppTheme.surfaceLighter, height: 24),
                          _buildSummaryRow("GRAND TOTAL", _totalAmount, isBold: true),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  _buildLabel("3) Additional Notes"),
                  FadeInUp(
                    child: _buildTextField(_issueController, "Repair details / parts used...", Icons.edit_note_rounded, maxLines: 3, required: false),
                  ),
                  const SizedBox(height: 48),

                  FadeInUp(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitBill,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text("GENERATE BILL & SYNC", style: AppTheme.monoStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildSummaryRow(String label, int val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? AppTheme.textBody : AppTheme.textMuted, fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text("₹$val", style: AppTheme.monoStyle(color: isBold ? AppTheme.primary : AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildServiceWithCostTile(String name, IconData icon) {
    bool isSelected = _selectedServices.contains(name);
    return GestureDetector(
      onTap: () => _toggleService(name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.surfaceLighter),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: isSelected 
                ? TextField(
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(hintText: "Cost", hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12), border: InputBorder.none),
                    onChanged: (val) => setState(() => _serviceCosts[name] = int.tryParse(val) ?? 0),
                  )
                : Text(name, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCustomServiceDialog() {
    String customName = "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text("ADD CUSTOM SERVICE", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 14)),
        content: TextField(
          autofocus: true,
          style: const TextStyle(color: AppTheme.textBody),
          decoration: const InputDecoration(hintText: "Enter service name...", hintStyle: TextStyle(color: AppTheme.textMuted)),
          onChanged: (val) => customName = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: AppTheme.textMuted))),
          TextButton(
            onPressed: () {
              if (customName.isNotEmpty) {
                setState(() {
                  _serviceItems.add({'name': customName, 'icon': Icons.add_to_photos_rounded});
                  _selectedServices.add(customName);
                  _serviceCosts[customName] = 0;
                });
              }
              Navigator.pop(context);
            }, 
            child: const Text("ADD", style: TextStyle(color: AppTheme.primary))
          ),
        ],
      ),
    );
  }

  void _toggleService(String service) {
    setState(() {
      if (_selectedServices.contains(service)) {
        _selectedServices.remove(service);
        _serviceCosts.remove(service);
      } else {
        _selectedServices.add(service);
        _serviceCosts[service] = 0;
      }
    });
  }

  Future<void> _generateAndSavePDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("MECHDESK INVOICE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
                    pw.Text("Date: ${DateTime.now().toString().split(' ')[0]}", style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 20),
                pw.Text("VEHICLE DETAILS", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text("Vehicle No: ${_vehicleController.text}"),
                pw.Text("Brand: $_selectedBrand"),
                pw.Text("Type: $_vehicleType"),
                pw.SizedBox(height: 30),
                pw.Text("SERVICE DETAILS", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Service Name", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Cost (INR)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                    ..._selectedServices.map((s) => pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(s)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Rs. ${_serviceCosts[s]}")),
                      ],
                    )),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("GRAND TOTAL", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text("Rs. $_totalAmount", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                      ],
                    ),
                  ],
                ),
                pw.Spacer(),
                pw.Center(child: pw.Text("Thank you for using MechDesk Partners!", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500))),
              ],
            ),
          );
        },
      ),
    );

    // Save to device
    final output = await getApplicationDocumentsDirectory();
    final file = File("${output.path}/invoice_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());
    
    // Also show Print Preview
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  void _submitBill() async {
    if (_selectedBrand == null || _vehicleController.text.isEmpty) {
      setState(() => _vehicleError = "Required");
      return;
    }
    
    if (_selectedServices.isEmpty) {
      setState(() => _serviceError = "Select at least 1 service");
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    final result = await ApiService().submitJob({
      'vehicleNo': _vehicleController.text,
      'problemDesc': _issueController.text,
      'serviceTypes': _selectedServices,
      'mode': 'Walk-in',
      'vehicleType': _vehicleType,
      'brand': _selectedBrand ?? "",
      'status': 'completed',
      'totalAmount': _totalAmount,
      'costDetails': _serviceCosts,
      'invoiceNo': _invoiceNo,
    });

    setState(() => _isSubmitting = false);

    if (result['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bill Synchronized Successfully!"), backgroundColor: AppTheme.success));
      
      // Removed Auto PDF generation as requested
      // Partners can now download on-demand from the interaction history
      
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync Error: ${result['message']}"), backgroundColor: AppTheme.danger));
    }
  }

  Widget _buildLabel(String text, {String? error}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text.toUpperCase(), style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          if (error != null) Text(error, style: const TextStyle(color: AppTheme.danger, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, bool required = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textBody),
      validator: (v) => (required && (v == null || v.isEmpty)) ? "Required" : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted),
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }

  Widget _buildTypeTile(String type, IconData icon) {
    bool isSelected = _vehicleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _vehicleType = type; _selectedBrand = null; }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.surfaceLighter),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textMuted, size: 18),
              const SizedBox(width: 8),
              Text(type, style: TextStyle(color: isSelected ? AppTheme.textBody : AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceLighter),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBrand,
          hint: const Text("Select Brand", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          isExpanded: true,
          dropdownColor: AppTheme.surface,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.primary),
          items: _topBrands[_vehicleType]!.map((brand) => DropdownMenuItem(value: brand, child: Text(brand, style: const TextStyle(color: AppTheme.textBody, fontSize: 14)))).toList(),
          onChanged: (val) => setState(() => _selectedBrand = val),
        ),
      ),
    );
  }
}
