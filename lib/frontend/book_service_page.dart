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
  final List<String> _selectedServices = ['General Service'];
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

  final Map<String, List<String>> _topBrands = {
    'Car': [
      'Maruti Suzuki', 'Hyundai', 'Tata Motors', 'Mahindra', 'Toyota', 
      'Kia', 'Honda', 'Skoda', 'MG Motor', 'Volkswagen'
    ],
    'Bike': [
      'Hero MotoCorp', 'Honda', 'TVS', 'Bajaj Auto', 'Royal Enfield', 
      'Suzuki', 'Yamaha', 'KTM', 'Jawa', 'Kawasaki'
    ]
  };

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
    {'name': 'Other', 'icon': Icons.more_horiz_rounded},
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
        // Default to 'new' (Always as start option)
        _selectedVehicleId = 'new';
        _vehicleController.clear();
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
      setState(() => _serviceError = "Not filled this details");
      hasError = true;
    }

    if (_serviceMode == 'Pickup' && _addressController.text.isEmpty) {
      setState(() => _addressError = "Pickup address is required");
      hasError = true;
    }

    if (hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Some details are missing"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final selectedGarage = _allGarages.firstWhere((g) => (g['partner_id'] ?? g['user_uid']) == _selectedGarageId);
    final garageName = selectedGarage['name'] ?? "Partner Garage";

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
                        // New Vehicle option always first
                        _buildNewVehicleToggle(),
                        ..._userVehicles.map((v) => _buildVehicleSmallCard(v)),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),
              
              // Vehicle Number (if adding new, otherwise show selected)
              _buildLabel("1) Vehicle Details", error: _vehicleError),
              FadeInUp(
                duration: const Duration(milliseconds: 500),
                child: Column(
                  children: [
                    // Vehicle Type Selector (Bike/Car)
                    if (_selectedVehicleId == 'new') ...[
                      Row(
                        children: [
                          _buildTypeTile("Car", Icons.directions_car_rounded),
                          const SizedBox(width: 12),
                          _buildTypeTile("Bike", Icons.pedal_bike_rounded),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Brand Dropdown
                      _buildBrandDropdown(),
                      const SizedBox(height: 16),
                    ],
                    _buildTextField(_vehicleController, "Vehicle Number", Icons.confirmation_number_rounded, enabled: _selectedVehicleId == 'new'),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Multiple Service Selection
              _buildLabel("2) Select Services", error: _serviceError),
              FadeInUp(
                duration: const Duration(milliseconds: 600),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.0,
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
              _buildLabel("3) Additional Notes"),
              FadeInUp(
                duration: const Duration(milliseconds: 700),
                child: _buildTextField(_issueController, "Any specific concerns? (Optional)", Icons.edit_note_rounded, maxLines: 3, required: false),
              ),
              const SizedBox(height: 32),

              // Service Mode
              _buildLabel("4) Service Mode"),
              const SizedBox(height: 12),
              FadeInUp(
                duration: const Duration(milliseconds: 800),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildModeTile("Walk-in", "Visit Garage", Icons.location_on_rounded),
                        const SizedBox(width: 16),
                        _buildModeTile("Pickup", "We Collect", Icons.moped_rounded),
                      ],
                    ),
                    if (_serviceMode == 'Pickup') ...[
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Pickup Address", error: _addressError),
                            _buildTextField(
                              _addressController, 
                              "Enter your full address", 
                              Icons.home_rounded,
                              suffix: IconButton(
                                icon: _isFetchingLocation 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: primaryOrange, strokeWidth: 2))
                                  : const Icon(Icons.my_location_rounded, color: primaryOrange, size: 20),
                                onPressed: _getCurrentLocation,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Garage Selection
              _buildLabel("5) Choose Garage", error: _garageError),
              const SizedBox(height: 12),
              
              if (_isLoadingGarages)
                const Center(child: CircularProgressIndicator(color: primaryOrange))
              else ...[
                // Search Bar
                FadeInUp(
                  duration: const Duration(milliseconds: 500),
                  child: _buildTextField(
                    _garageSearchController, 
                    "Search garage by name or city...", 
                    Icons.search_rounded,
                    required: false,
                    onChanged: _filterGarages,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Garage List
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: _filteredGarages.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                        child: const Center(child: Text("No approved garages found", style: TextStyle(color: Colors.white38))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredGarages.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final garage = _filteredGarages[index];
                          return _buildGarageCard(garage);
                        },
                      ),
                ),
              ],
              
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

  Widget _buildNewVehicleToggle() {
    bool isSelected = _selectedVehicleId == 'new';
    return GestureDetector(
      onTap: () => setState(() {
        _selectedVehicleId = 'new';
        _vehicleController.clear();
        _selectedBrand = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 120,
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
            Icon(Icons.add_circle_outline_rounded, color: isSelected ? primaryOrange : Colors.white24, size: 24),
            const SizedBox(height: 8),
            Text("NEW VEHICLE", style: TextStyle(color: isSelected ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
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
          if (error != null)
            Text(error, style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permission denied';
      }
      
      if (permission == LocationPermission.deniedForever) throw 'Permission denied forever';

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
        setState(() {
          _addressController.text = address;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, bool enabled = true, bool required = true, Widget? suffix, Function(String)? onChanged}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      enabled: enabled,
      onChanged: onChanged,
      style: TextStyle(color: enabled ? Colors.white : Colors.white38),
      validator: (v) => (required && (v == null || v.isEmpty)) ? "Required" : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white12),
        prefixIcon: Icon(icon, color: enabled ? primaryOrange : Colors.white10, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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

  Widget _buildTypeTile(String type, IconData icon) {
    bool isSelected = _vehicleType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _vehicleType = type;
          _selectedBrand = null; // Reset brand on type change
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? primaryOrange : Colors.white10),
          ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBrand,
          hint: const Text("Select Brand", style: TextStyle(color: Colors.white24, fontSize: 13)),
          isExpanded: true,
          dropdownColor: cardBg,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: primaryOrange),
          items: _topBrands[_vehicleType]!.map((brand) {
            return DropdownMenuItem(
              value: brand,
              child: Text(brand, style: const TextStyle(color: Colors.white, fontSize: 14)),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedBrand = val),
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
            Icon(icon, color: isSelected ? primaryOrange : Colors.white24, size: 20),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGarageCard(Map garage) {
    final String gId = garage['partner_id'] ?? garage['user_uid'] ?? "";
    bool isSelected = _selectedGarageId == gId;
    return GestureDetector(
      onTap: () => setState(() => _selectedGarageId = gId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryOrange.withOpacity(0.1) : cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primaryOrange : Colors.white10, width: 2),
        ),
        child: Row(
          children: [
            // Garage Image (Thumbnail)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
                image: (garage['photo_urls'] != null && (garage['photo_urls'] as List).isNotEmpty)
                  ? DecorationImage(image: NetworkImage(garage['photo_urls'][0]), fit: BoxFit.cover)
                  : null,
              ),
              child: (garage['photo_urls'] == null || (garage['photo_urls'] as List).isEmpty)
                ? const Icon(Icons.garage_rounded, color: Colors.white24)
                : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    garage['name'] ?? "Unnamed Garage",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: primaryOrange, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        "${garage['city']}, ${garage['district']}",
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Owner: ${garage['owner_name']}",
                    style: const TextStyle(color: Colors.white24, fontSize: 10),
                  ),
                  if (garage['partner_id'] != null)
                    Text(
                      "ID: ${garage['partner_id']}",
                      style: AppTheme.monoStyle(color: primaryOrange.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: primaryOrange),
          ],
        ),
      ),
    );
  }
}
