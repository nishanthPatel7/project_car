import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';


class BookServicePage extends StatefulWidget {
  const BookServicePage({super.key});

  @override
  State<BookServicePage> createState() => _BookServicePageState();
}

class _BookServicePageState extends State<BookServicePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final List<String> _selectedServices = [];
  bool _isSubmitting = false;
  String _serviceMode = 'Walk-in'; // Walk-in or Pickup
  String _vehicleType = 'Car';
  String? _selectedBrand;
  String? _vehicleError;
  String? _serviceError;
  String? _addressError;
  bool _isFetchingLocation = false;
  List _allGarages = [];
  List _filteredGarages = [];
  String? _selectedGarageId;
  bool _isLoadingGarages = true;
  final TextEditingController _garageSearchController = TextEditingController();
  String? _garageError;
  List<Map<String, dynamic>> _garageAvailableServices = [];
  List<String> _availableBrandsForGarage = [];
  bool _isFetchingBrands = false;
  bool _isFetchingPricing = false;

  final Map<String, List<String>> _topBrands = {
    'Car': ['Maruti Suzuki', 'Hyundai', 'Tata Motors', 'Mahindra', 'Toyota', 'Kia', 'Honda', 'Skoda', 'MG Motor', 'Volkswagen'],
    'Bike': ['Hero MotoCorp', 'Honda', 'TVS', 'Bajaj Auto', 'Royal Enfield', 'Suzuki', 'Yamaha', 'KTM', 'Jawa', 'Kawasaki']
  };

  static const Color primaryOrange = Color(0xFFFF5C00);
  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color cardBg = Color(0xFF1A1A1A);

  List _userVehicles = [];
  bool _isLoadingVehicles = true;
  String? _selectedVehicleId;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadGarages();
  }

  void _loadGarages() async {
    final res = await ApiService().getApprovedGarages();
    if (mounted) {
      setState(() {
        _allGarages = res['garages'] ?? [];
        _filteredGarages = _allGarages;
        _isLoadingGarages = false;
      });
    }
  }

  void _fetchGaragePricing() async {
    if (_selectedGarageId == null) return;
    
    String? model;
    if (_selectedVehicleId == 'new') {
      model = _selectedBrand;
    } else {
      final v = _userVehicles.firstWhere((v) => v['id'].toString() == _selectedVehicleId, orElse: () => null);
      model = v?['brand'] ?? v?['model'];
    }

    if (model == null) return;

    setState(() {
      _isFetchingPricing = true;
      _selectedServices.clear();
      _garageAvailableServices.clear();
    });

    final res = await ApiService().getGaragePricing({
      'garageUid': _selectedGarageId,
      'vehicleType': _vehicleType,
      'modelName': model,
    });

    if (mounted) {
      if (res['status'] == 'success') {
        List<Map<String, dynamic>> services = [];
        for (var s in (res['services'] as List)) {
          services.add({
            'name': s['service_name'].toString(),
            'cost': int.tryParse(s['cost'].toString()) ?? 0,
          });
        }
        setState(() {
          _garageAvailableServices = services;
          _isFetchingPricing = false;
        });
      } else {
        setState(() => _isFetchingPricing = false);
      }
    }
  }

  void _fetchGarageBrands() async {
    if (_selectedGarageId == null) return;

    setState(() {
      _isFetchingBrands = true;
      _availableBrandsForGarage = [];
      _selectedBrand = null;
      _garageAvailableServices.clear(); // Clear services when fetching new brands
    });

    final res = await ApiService().getGaragePricing({
      'garageUid': _selectedGarageId,
      'vehicleType': _vehicleType,
      'onlyBrands': true,
    });

    if (mounted) {
      if (res['status'] == 'success') {
        Set<String> brands = {};
        for (var s in (res['services'] as List)) {
          if (s['model_name'] != null) {
            brands.add(s['model_name'].toString());
          }
        }
        setState(() {
          _availableBrandsForGarage = brands.toList()..sort();
          _isFetchingBrands = false;
        });
      } else {
        setState(() => _isFetchingBrands = false);
      }
    }
  }

  int get _estimatedTotal {
    int total = 0;
    for (var sName in _selectedServices) {
      final s = _garageAvailableServices.firstWhere((item) => item['name'] == sName, orElse: () => {'cost': 0});
      total += (s['cost'] as int);
    }
    return total;
  }

  void _filterGarages(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredGarages = _allGarages;
      } else {
        _filteredGarages = _allGarages.where((g) {
          final name = g['name']?.toString().toLowerCase() ?? "";
          final city = g['city']?.toString().toLowerCase() ?? "";
          return name.contains(query.toLowerCase()) || city.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _loadVehicles() async {
    final res = await ApiService().getInitialState();
    if (mounted) {
      setState(() {
        _userVehicles = res['data']?['vehicles'] ?? [];
        _isLoadingVehicles = false;
        _selectedVehicleId = 'new';
        _vehicleController.clear();
      });
    }
  }

  void _toggleService(String service) {
    setState(() {
      if (_selectedServices.contains(service)) {
        _selectedServices.remove(service);
      } else {
        _selectedServices.add(service);
      }
    });
  }

  IconData _getServiceIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('oil')) return Icons.opacity_rounded;
    if (n.contains('brake')) return Icons.disc_full_rounded;
    if (n.contains('engine')) return Icons.engineering_rounded;
    if (n.contains('wash')) return Icons.wash_rounded;
    if (n.contains('ac')) return Icons.ac_unit_rounded;
    if (n.contains('battery')) return Icons.battery_charging_full_rounded;
    if (n.contains('tyre')) return Icons.tire_repair_rounded;
    if (n.contains('alignment')) return Icons.align_vertical_center_rounded;
    if (n.contains('paint')) return Icons.format_paint_rounded;
    if (n.contains('clutch')) return Icons.work_history_rounded;
    if (n.contains('chain')) return Icons.link_rounded;
    return Icons.settings_rounded;
  }

  void _submitBooking() async {
    setState(() {
      _vehicleError = null;
      _serviceError = null;
      _addressError = null;
      _garageError = null;
    });

    bool hasError = false;

    if (_selectedGarageId == null) {
      setState(() => _garageError = "Please select a garage");
      hasError = true;
    }

    if (_selectedVehicleId == 'new') {
      if (_selectedBrand == null || _vehicleController.text.isEmpty) {
        setState(() => _vehicleError = "Not filled this details");
        hasError = true;
      }
    }

    if (_selectedServices.isEmpty) {
      setState(() => _serviceError = "Please select at least one service");
      hasError = true;
    }

    if (_serviceMode == 'Pickup' && _addressController.text.isEmpty) {
      setState(() => _addressError = "Pickup address is required");
      hasError = true;
    }

    if (hasError) return;

    final selectedGarage = _allGarages.firstWhere((g) => (g['uid'] ?? g['partner_id'] ?? g['user_uid']).toString() == _selectedGarageId);
    final garageName = selectedGarage['name'] ?? "Partner Garage";

    // Prepare cost details
    List<Map<String, dynamic>> serviceCosts = [];
    int subtotal = 0;
    for (var sName in _selectedServices) {
      final s = _garageAvailableServices.firstWhere((item) => item['name'] == sName, orElse: () => {'cost': 0});
      int cost = (s['cost'] as int);
      serviceCosts.add({'name': sName, 'cost': cost});
      subtotal += cost;
    }

    _showConfirmationSheet(subtotal, serviceCosts, garageName);
  }

  void _showConfirmationSheet(int subtotal, List<Map<String, dynamic>> serviceCosts, String garageName) {
    final double tax = subtotal * 0.05;
    final double total = subtotal + tax;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A), // Matching darkBg
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("CONFIRM BOOKING", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text("Garage: $garageName", style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 24),
            
            const Text("SERVICES", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            ...serviceCosts.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s['name'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                  Text("₹${s['cost']}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            )),
            
            const Divider(color: Colors.white10, height: 32),
            
            _buildAmountRow("Subtotal", subtotal.toDouble()),
            _buildAmountRow("Service Tax (5%)", tax),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: _buildAmountRow("GRAND TOTAL", total, isBold: true, color: Colors.orange),
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _executeBooking(total.round(), serviceCosts, garageName);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("BOOK NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, double val, {bool isBold = false, Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isBold ? Colors.white : Colors.white60, fontSize: isBold ? 14 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text("₹${val.toStringAsFixed(0)}", style: TextStyle(color: color, fontSize: isBold ? 20 : 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _executeBooking(int finalTotal, List<Map<String, dynamic>> serviceCosts, String garageName) async {
    setState(() => _isSubmitting = true);

    // Calculate tax for DB storage
    final subtotal = finalTotal / 1.05;
    final taxAmount = finalTotal - subtotal;
    
    // Create a copy to avoid modifying the list used in the UI if needed
    List<Map<String, dynamic>> dbServiceCosts = List.from(serviceCosts);
    dbServiceCosts.add({'name': 'Service Tax (5%)', 'cost': taxAmount.round()});

    final result = await ApiService().submitJob({
      'vehicleNo': _vehicleController.text,
      'problemDesc': _issueController.text,
      'serviceTypes': _selectedServices,
      'mode': _serviceMode,
      'address': _serviceMode == 'Pickup' ? _addressController.text : null,
      'vehicleType': _vehicleType,
      'brand': _selectedBrand ?? "",
      'garage_uid': _selectedGarageId,
      'garage_name': garageName,
      'garageName': garageName,
      'totalAmount': finalTotal,
      'costDetails': jsonEncode(dbServiceCosts),
    });

    setState(() => _isSubmitting = false);

    if (result['status'] == 'success') {
      if (mounted) {
        _showSuccessSheet(finalTotal, dbServiceCosts, garageName);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${result['message']}"), backgroundColor: Colors.red));
      }
    }
  }

  void _showSuccessSheet(int finalTotal, List<Map<String, dynamic>> serviceCosts, String garageName) {
    final now = DateTime.now();
    final timeStr = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final dateStr = "${now.day}/${now.month}/${now.year}";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A), // darkBg
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            const Text("BOOKING CONFIRMED", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text("Your request has been sent to $garageName", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      const Text("Booking Time", style: TextStyle(color: Colors.white60, fontSize: 12)),
                      const Spacer(),
                      Text("$dateStr · $timeStr", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 32),
                  ...serviceCosts.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s['name'], style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        Text("₹${s['cost']}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
                  const Divider(color: Colors.white10, height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TOTAL BILL", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      Text("₹$finalTotal", style: const TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close sheet
                  Navigator.pop(this.context); // Go back
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("DONE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        title: const Text("Book Service", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeInDown(
                duration: const Duration(milliseconds: 500),
                child: const Text("Choose Vehicle", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              
              if (_isLoadingVehicles)
                const Center(child: CircularProgressIndicator(color: primaryOrange))
              else
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: SizedBox(
                    height: 72,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildNewVehicleToggle(),
                        ..._userVehicles.map((v) => _buildVehicleSmallCard(v)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),
              
              _buildLabel("1) Choose Garage", error: _garageError),
              const SizedBox(height: 12),
              if (_isLoadingGarages)
                const Center(child: CircularProgressIndicator(color: primaryOrange))
              else ...[
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: _buildTextField(_garageSearchController, "Search by name or city...", Icons.search_rounded, required: false, onChanged: _filterGarages),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: _filteredGarages.length,
                  itemBuilder: (context, index) => _buildGarageBlock(_filteredGarages[index]),
                ),
              ],

              const SizedBox(height: 32),

              _buildLabel("2) Vehicle Details", error: _vehicleError),
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    if (_selectedVehicleId == 'new') ...[
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
                    ],
                    _buildTextField(_vehicleController, "Vehicle Number", Icons.confirmation_number_rounded, enabled: _selectedVehicleId == 'new', maxLength: 12),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildLabel("3) Select Services", error: _serviceError),
              const SizedBox(height: 12),
              if (_selectedGarageId == null)
                _buildInfoBanner("Select a garage first to view services")
              else if (_isFetchingPricing)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: primaryOrange)))
              else if (_garageAvailableServices.isEmpty)
                _buildInfoBanner("This garage does not offer services for the selected vehicle model.")
              else
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                    ),
                    itemCount: _garageAvailableServices.length,
                    itemBuilder: (context, index) {
                      final s = _garageAvailableServices[index];
                      return _buildDynamicServiceCard(s['name'], s['cost']);
                    },
                  ),
                ),
              const SizedBox(height: 32),

              _buildLabel("4) Details & Mode"),
              FadeInUp(duration: const Duration(milliseconds: 700), child: _buildTextField(_issueController, "Problem description (Optional)", Icons.edit_note_rounded, maxLines: 3, required: false)),
              const SizedBox(height: 16),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                child: Row(
                  children: [
                    _buildModeTile("Walk-in", Icons.location_on_rounded),
                    const SizedBox(width: 16),
                    _buildModeTile("Pickup", Icons.moped_rounded),
                  ],
                ),
              ),
              if (_serviceMode == 'Pickup') ...[
                const SizedBox(height: 16),
                _buildLabel("Pickup Address", error: _addressError),
                _buildTextField(_addressController, "Enter full address", Icons.home_rounded, suffix: IconButton(icon: Icon(_isFetchingLocation ? Icons.hourglass_empty : Icons.my_location_rounded, color: primaryOrange, size: 20), onPressed: _getCurrentLocation)),
              ],
              
              const SizedBox(height: 48),

              if (_estimatedTotal > 0)
                FadeInUp(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryOrange.withOpacity(0.3))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("ESTIMATED TOTAL", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          Text("₹$_estimatedTotal", style: AppTheme.monoStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ]),
                        const Icon(Icons.receipt_long_rounded, color: primaryOrange, size: 28),
                      ],
                    ),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitBooking,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Book Now", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
      child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white38, fontSize: 13)),
    );
  }

  Widget _buildVehicleSmallCard(Map v) {
    bool isSelected = _selectedVehicleId == v['id'].toString();
    return GestureDetector(
      onTap: () => setState(() {
        _selectedVehicleId = v['id'].toString();
        _vehicleController.text = v['vehicle_no'];
        _fetchGaragePricing();
      }),
      child: Container(
        width: 110,
        height: 64,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryOrange : Colors.white10, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_rounded, color: isSelected ? primaryOrange : Colors.white24, size: 20),
            const SizedBox(height: 1),
            Text(v['vehicle_no'], style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            Text(v['model'], style: TextStyle(color: isSelected ? Colors.white70 : Colors.white10, fontSize: 8), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildNewVehicleToggle() {
    bool isSelected = _selectedVehicleId == 'new';
    return GestureDetector(
      onTap: () => setState(() {
        _selectedVehicleId = 'new';
        _vehicleController.clear();
        _selectedBrand = null;
        _garageAvailableServices.clear();
      }),
      child: Container(
        width: 90,
        height: 64,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryOrange : Colors.white10, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: isSelected ? primaryOrange : Colors.white24, size: 20),
            const SizedBox(height: 1),
            Text("NEW VEHICLE", style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildGarageBlock(Map garage) {
    final String gId = (garage['uid'] ?? garage['partner_id'] ?? garage['user_uid'] ?? "").toString();
    bool isSelected = _selectedGarageId != null && _selectedGarageId == gId;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedGarageId = gId;
        _selectedServices.clear();
        _fetchGarageBrands();
      }),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryOrange : Colors.white10, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: (garage['photo_urls'] != null && (garage['photo_urls'] as List).isNotEmpty)
                  ? Image.network(garage['photo_urls'][0], width: double.infinity, height: 75, fit: BoxFit.cover)
                  : Container(height: 75, width: double.infinity, color: Colors.white10, child: const Icon(Icons.garage_rounded, color: Colors.white24, size: 30)),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "${garage['name'] ?? "Garage"}\n",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, height: 1.1),
                        ),
                        TextSpan(
                          text: "${garage['address'] ?? ""}${garage['address'] != null && garage['city'] != null ? ", " : ""}${garage['city'] ?? ""}",
                          style: const TextStyle(color: Colors.white38, fontSize: 9, height: 1.1),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicServiceCard(String name, int cost) {
    bool isSelected = _selectedServices.contains(name);
    return GestureDetector(
      onTap: () => _toggleService(name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryOrange : Colors.white10, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getServiceIcon(name), color: isSelected ? primaryOrange : Colors.white24, size: 16),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            Text("₹$cost", style: AppTheme.monoStyle(color: isSelected ? primaryOrange : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {String? error}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(text.toUpperCase(), style: const TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          if (error != null) Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks[0];
        setState(() => _addressController.text = "${p.street}, ${p.locality}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, bool enabled = true, bool required = true, int? maxLength, Widget? suffix, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      maxLength: maxLength,
      onChanged: onChanged,
      style: TextStyle(color: enabled ? Colors.white : Colors.white38),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white12),
        prefixIcon: Icon(icon, color: enabled ? primaryOrange : Colors.white10, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Widget _buildModeTile(String mode, IconData icon) {
    bool isSelected = _serviceMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _serviceMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? primaryOrange : Colors.white10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? primaryOrange : Colors.white24, size: 18),
              const SizedBox(width: 8),
              Text(mode, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeTile(String type, IconData icon) {
    bool isSelected = _vehicleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _vehicleType = type;
          _selectedBrand = null;
          _garageAvailableServices.clear();
          if (_selectedGarageId != null) _fetchGarageBrands();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? primaryOrange : Colors.white10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? primaryOrange : Colors.white24, size: 18),
              const SizedBox(width: 8),
              Text(type, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandDropdown() {
    bool hasGarage = _selectedGarageId != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBrand,
              hint: Text("Select Brand", style: TextStyle(color: Colors.white24, fontSize: 13)),
              isExpanded: true,
              dropdownColor: cardBg,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: hasGarage ? primaryOrange : Colors.white10),
              items: _availableBrandsForGarage.map((brand) => DropdownMenuItem(value: brand, child: Text(brand, style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
              onChanged: hasGarage ? (val) => setState(() {
                _selectedBrand = val;
                _fetchGaragePricing();
              }) : null,
            ),
          ),
        ),
        if (!hasGarage)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text("Choose a garage above to see supported brands", style: TextStyle(color: Colors.white30, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        if (hasGarage && _isFetchingBrands)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: SizedBox(height: 2, child: LinearProgressIndicator(color: primaryOrange, backgroundColor: Colors.white10)),
          ),
        if (hasGarage && !_isFetchingBrands && _availableBrandsForGarage.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8, left: 4),
            child: Text("❌ This garage doesn't offer services for this vehicle type.", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
