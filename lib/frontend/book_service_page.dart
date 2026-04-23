import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/api_service.dart';

class BookServicePage extends StatefulWidget {
  const BookServicePage({super.key});

  @override
  State<BookServicePage> createState() => _BookServicePageState();
}

class _BookServicePageState extends State<BookServicePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _vehicleController = TextEditingController();
  final TextEditingController _issueController = TextEditingController();
  final List<String> _selectedServices = ['General Service'];
  String _serviceMode = 'Walk-in'; // Walk-in or Pickup
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _serviceItems = [
    {'name': 'General Service', 'icon': Icons.settings_rounded},
    {'name': 'Oil Change', 'icon': Icons.opacity_rounded},
    {'name': 'Brake Repair', 'icon': Icons.disc_full_rounded},
    {'name': 'Engine Check', 'icon': Icons.engineering_rounded},
    {'name': 'Body Wash', 'icon': Icons.wash_rounded},
    {'name': 'AC Repair', 'icon': Icons.ac_unit_rounded},
  ];

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
  }

  void _loadVehicles() async {
    final res = await ApiService().getInitialState();
    if (mounted) {
      setState(() {
        _userVehicles = res['data']?['vehicles'] ?? [];
        _isLoadingVehicles = false;
        if (_userVehicles.isNotEmpty) {
          _selectedVehicleId = _userVehicles[0]['id'].toString();
          _vehicleController.text = _userVehicles[0]['vehicle_no'];
        }
      });
    }
  }

  void _toggleService(String service) {
    setState(() {
      if (_selectedServices.contains(service)) {
        if (_selectedServices.length > 1) {
          _selectedServices.remove(service);
        }
      } else {
        _selectedServices.add(service);
      }
    });
  }

  void _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_vehicleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select or enter a vehicle")));
      return;
    }
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one service")));
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await ApiService().submitJob({
      'vehicleNo': _vehicleController.text,
      'problemDesc': _issueController.text,
      'serviceTypes': _selectedServices,
      'mode': _serviceMode,
    });

    setState(() => _isSubmitting = false);

    if (result['status'] == 'success') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Booking Successful!"),
            backgroundColor: Colors.green.shade700,
          ),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${result['message']}"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
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
                child: const Text(
                  "Choose Vehicle",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              
              // Vehicles List
              if (_isLoadingVehicles)
                const Center(child: CircularProgressIndicator(color: primaryOrange))
              else
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._userVehicles.map((v) => _buildVehicleSmallCard(v)),
                        _buildAddNewVehicleSmallCard(),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),
              
              // Vehicle Number (if adding new, otherwise show selected)
              _buildLabel("Vehicle Details"),
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: _buildTextField(_vehicleController, "Vehicle Number", Icons.directions_car_rounded, enabled: _selectedVehicleId == 'new'),
              ),
              const SizedBox(height: 28),

              // Multiple Service Selection
              _buildLabel("Select Services"),
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _serviceItems.length,
                  itemBuilder: (context, index) {
                    final item = _serviceItems[index];
                    return _buildServiceCard(item['name'], item['icon']);
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Issue Description
              _buildLabel("Additional Notes"),
              FadeInUp(
                duration: const Duration(milliseconds: 700),
                child: _buildTextField(_issueController, "Any specific concerns?", Icons.edit_note_rounded, maxLines: 3),
              ),
              const SizedBox(height: 32),

              // Service Mode
              _buildLabel("Service Mode"),
              const SizedBox(height: 12),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                child: Row(
                  children: [
                    _buildModeTile("Walk-in", "Visit Garage", Icons.location_on_rounded),
                    const SizedBox(width: 16),
                    _buildModeTile("Pickup", "We Collect", Icons.moped_rounded),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),

              // Submit Button
              FadeInUp(
                duration: const Duration(milliseconds: 900),
                child: SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Submit Request", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleSmallCard(Map v) {
    bool isSelected = _selectedVehicleId == v['id'].toString();
    return GestureDetector(
      onTap: () => setState(() {
        _selectedVehicleId = v['id'].toString();
        _vehicleController.text = v['vehicle_no'];
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryOrange : Colors.white10, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_filled_rounded, color: isSelected ? primaryOrange : Colors.white24, size: 24),
            const SizedBox(height: 8),
            Text(v['vehicle_no'], style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            Text(v['model'], style: TextStyle(color: isSelected ? Colors.white70 : Colors.white10, fontSize: 10), overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewVehicleSmallCard() {
    bool isSelected = _selectedVehicleId == 'new';
    return GestureDetector(
      onTap: () => setState(() {
        _selectedVehicleId = 'new';
        _vehicleController.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? primaryOrange : Colors.white10, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: isSelected ? primaryOrange : Colors.white24, size: 24),
            const SizedBox(height: 8),
            Text("Add New", style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(text.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.white : Colors.white38),
      validator: (v) => v!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white12),
        prefixIcon: Icon(icon, color: enabled ? primaryOrange : Colors.white10, size: 20),
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

  Widget _buildModeTile(String mode, String subtitle, IconData icon) {
    bool isSelected = _serviceMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _serviceMode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? primaryOrange : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? primaryOrange : Colors.white24, size: 32),
              const SizedBox(height: 12),
              Text(mode, style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(color: isSelected ? Colors.white70 : Colors.white10, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(String name, IconData icon) {
    bool isSelected = _selectedServices.contains(name);
    return GestureDetector(
      onTap: () => _toggleService(name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryOrange : Colors.white10.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? primaryOrange : Colors.white24, size: 24),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
