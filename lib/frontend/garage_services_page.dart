import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';

class GarageServicesPage extends StatefulWidget {
  final String garageId;
  final String garageName;
  const GarageServicesPage({super.key, required this.garageId, required this.garageName});

  @override
  State<GarageServicesPage> createState() => _GarageServicesPageState();
}

class _GarageServicesPageState extends State<GarageServicesPage> {
  String _selectedCategory = 'Car'; // Car or Bike
  bool _isLoading = true;
  List<dynamic> _allPricing = [];
  Map<String, List<Map<String, dynamic>>> _modelServices = {}; // { 'ModelName': [{name, cost}] }
  Map<String, String> _searchQueries = {};
  bool _hasUnsavedChanges = false;

  void _cloneModelPricing(String targetModel) {
    String? sourceModel;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text("CLONE PRICING TO $targetModel", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select a model to copy services from:", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.surfaceLighter)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: sourceModel,
                    isExpanded: true,
                    dropdownColor: AppTheme.surface,
                    hint: const Text("Select Source Model", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    items: _modelServices.keys.where((k) => k != targetModel).map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(color: AppTheme.textBody, fontSize: 14)))).toList(),
                    onChanged: (v) => setDialogState(() => sourceModel = v),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: AppTheme.textMuted))),
            TextButton(
              onPressed: () {
                if (sourceModel != null) {
                  setState(() {
                    _modelServices[targetModel] = List.from(_modelServices[sourceModel!]!.map((s) => Map<String, dynamic>.from(s)));
                    _hasUnsavedChanges = true;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pricing copied from $sourceModel"), backgroundColor: AppTheme.primary));
                }
              },
              child: const Text("CLONE NOW", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  final List<String> _commonServices = [
    'General Service', 'Oil Change', 'Brake Repair', 'Engine Tune-up', 
    'Body Wash', 'AC Service', 'Battery Replacement', 'Tyre Change', 
    'Wheel Alignment', 'Painting', 'Clutch Work', 'Chain Lubrication'
  ];

  final Map<String, List<String>> _topBrands = {
    'Car': ['Maruti Suzuki', 'Hyundai', 'Tata Motors', 'Mahindra', 'Toyota', 'Kia', 'Honda', 'Skoda', 'MG Motor', 'Volkswagen'],
    'Bike': ['Hero MotoCorp', 'Honda', 'TVS', 'Bajaj Auto', 'Royal Enfield', 'Suzuki', 'Yamaha', 'KTM', 'Jawa', 'Kawasaki']
  };

  @override
  void initState() {
    super.initState();
    _fetchPricing();
  }

  Future<void> _fetchPricing() async {
    print("DEBUG: Fetching pricing for garage: ${widget.garageId}, category: $_selectedCategory");
    setState(() => _isLoading = true);
    final res = await ApiService().getGaragePricing({
      'garageUid': widget.garageId,
      'vehicleType': _selectedCategory,
    });
    
    print("DEBUG: Fetch Result: $res");
    
    if (mounted) {
      if (res['status'] == 'success') {
        final List services = res['services'] ?? [];
        Map<String, List<Map<String, dynamic>>> grouped = {};
        
        for (var s in services) {
          final model = s['model_name'];
          if (!grouped.containsKey(model)) grouped[model] = [];
          grouped[model]!.add({'name': s['service_name'], 'cost': s['cost'].toString()});
        }

        setState(() {
          _allPricing = services;
          _modelServices = grouped;
          _isLoading = false;
        });
        print("DEBUG: Grouped Services: ${_modelServices.keys.toList()}");
      } else {
        setState(() => _isLoading = false);
        print("DEBUG: Fetch Error: ${res['message']}");
      }
    }
  }

  Future<void> _saveModelServices(String modelName) async {
    final services = _modelServices[modelName] ?? [];
    if (services.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saving..."), duration: Duration(milliseconds: 500)));
    
    final res = await ApiService().saveGarageServices({
      'garageUid': widget.garageId,
      'vehicleType': _selectedCategory,
      'modelName': modelName,
      'services': services.map((s) => {'name': s['name'], 'cost': int.tryParse(s['cost'] ?? '0') ?? 0}).toList(),
    });

    if (mounted) {
      if (res['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully!"), backgroundColor: AppTheme.success));
        setState(() => _hasUnsavedChanges = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: AppTheme.danger));
      }
    }
  }

  void _addNewModel() {
    String? selectedBrand;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text("ADD ${_selectedCategory.toUpperCase()} MODEL", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 14)),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.surfaceLighter)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedBrand,
                isExpanded: true,
                dropdownColor: AppTheme.surface,
                hint: const Text("Select Brand", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                items: _topBrands[_selectedCategory]!.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(color: AppTheme.textBody, fontSize: 14)))).toList(),
                onChanged: (v) => setDialogState(() => selectedBrand = v),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: AppTheme.textMuted))),
            TextButton(
              onPressed: () {
                if (selectedBrand != null) {
                  if (_modelServices.length >= 20 && !_modelServices.containsKey(selectedBrand)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Limit reached: 20 models per type")));
                  } else {
                    setState(() {
                      if (!_modelServices.containsKey(selectedBrand)) {
                        _modelServices[selectedBrand!] = [];
                        _hasUnsavedChanges = true;
                      }
                    });
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text("ADD", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _addServiceToModel(String model) {
    String customName = "";
    String? selectedStandard;
    
    final TextEditingController nameController = TextEditingController(text: customName);
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text("ADD SERVICE TO $model", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppTheme.textBody, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Enter service name...",
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: AppTheme.primary),
                    onSelected: (v) {
                      setDialogState(() {
                        if (v == "OTHER") {
                          nameController.clear();
                        } else {
                          nameController.text = v;
                        }
                        customName = nameController.text;
                      });
                    },
                    itemBuilder: (context) => [
                      ..._commonServices.map((s) => PopupMenuItem(value: s, child: Text(s, style: const TextStyle(color: AppTheme.textBody, fontSize: 13)))),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: "OTHER", child: Text("OTHER (Type manually)", style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                onChanged: (v) => customName = v,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: AppTheme.textMuted))),
            TextButton(
              onPressed: () {
                if (customName.isNotEmpty) {
                  setState(() {
                    if ((_modelServices[model]?.length ?? 0) >= 50) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Limit reached: 50 services per model")));
                    } else {
                      _modelServices[model]!.add({'name': customName, 'cost': '0'});
                      _hasUnsavedChanges = true;
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text("ADD", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Set<String> _expandedModels = {};

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool? shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.surface,
            title: const Text("Unsaved Changes", style: TextStyle(color: AppTheme.textBody)),
            content: const Text("You have unsaved changes. Do you want to leave without saving?", style: TextStyle(color: AppTheme.textMuted)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("STAY", style: TextStyle(color: AppTheme.primary))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("LEAVE", style: TextStyle(color: AppTheme.danger))),
            ],
          ),
        );
        if (shouldPop == true && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textBody, size: 20),
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Column(
            children: [
              Text("MANAGE SERVICES", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              if (_hasUnsavedChanges)
                const Text("● Unsaved changes", style: TextStyle(color: AppTheme.primary, fontSize: 8, fontWeight: FontWeight.bold)),
            ],
          ),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: _fetchPricing,
          color: AppTheme.primary,
          child: Column(
            children: [
              // Category Toggle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    _buildCategoryBtn('Car', Icons.directions_car_rounded),
                    const SizedBox(width: 16),
                    _buildCategoryBtn('Bike', Icons.pedal_bike_rounded),
                  ],
                ),
              ),

              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _modelServices.isEmpty 
                    ? _buildEmptyState()
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: _modelServices.keys.map((model) => _buildModelAccordion(model)).toList(),
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addNewModel,
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text("ADD ${_selectedCategory.toUpperCase()}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildCategoryBtn(String label, IconData icon) {
    bool isSelected = _selectedCategory == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedCategory = label;
          _hasUnsavedChanges = false;
          _expandedModels.clear();
          _fetchPricing();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.surfaceLighter),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textMuted, size: 20),
              const SizedBox(width: 10),
              Text(label.toUpperCase(), style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModelAccordion(String model) {
    final bool isExpanded = _expandedModels.contains(model);
    final services = _modelServices[model] ?? [];
    
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface, 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: isExpanded ? AppTheme.primary.withOpacity(0.3) : AppTheme.surfaceLighter)
        ),
        child: Column(
          children: [
            // Model Header (Clickable)
            InkWell(
              onTap: () => setState(() {
                if (isExpanded) _expandedModels.remove(model);
                else _expandedModels.add(model);
              }),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(_selectedCategory == 'Car' ? Icons.directions_car_filled_rounded : Icons.pedal_bike_rounded, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Text(model, style: const TextStyle(color: AppTheme.textBody, fontSize: 15, fontWeight: FontWeight.bold))),
                    
                    if (!isExpanded) ...[
                      Text("${services.length} services", style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                      const SizedBox(width: 8),
                    ],
                    
                    Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
            
            if (isExpanded) ...[
              const Divider(color: AppTheme.surfaceLighter, height: 1),
              
              // Service List
              if (services.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Text("No services added for this model", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () => _addServiceToModel(model),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text("ADD FIRST SERVICE"),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final s = services[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.surfaceLighter.withOpacity(0.5), width: 0.5))
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              style: const TextStyle(color: AppTheme.textBody, fontSize: 13),
                              decoration: const InputDecoration(hintText: "Service Name", hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12), border: InputBorder.none),
                              controller: TextEditingController(text: s['name'])..selection = TextSelection.fromPosition(TextPosition(offset: s['name']?.length ?? 0)),
                              onChanged: (v) {
                                s['name'] = v;
                                _hasUnsavedChanges = true;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(8)),
                              child: TextField(
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(prefixText: "₹ ", border: InputBorder.none, isDense: true),
                                controller: TextEditingController(text: s['cost'])..selection = TextSelection.fromPosition(TextPosition(offset: s['cost']?.length ?? 0)),
                                onChanged: (v) {
                                  s['cost'] = v;
                                  _hasUnsavedChanges = true;
                                },
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              services.removeAt(index);
                              _hasUnsavedChanges = true;
                            }),
                            icon: const Icon(Icons.do_not_disturb_on_outlined, color: AppTheme.danger, size: 18),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              
              // Footer Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() {
                        _modelServices.remove(model);
                        _hasUnsavedChanges = true;
                      }),
                      icon: const Icon(Icons.delete_sweep_rounded, color: AppTheme.danger, size: 20),
                      tooltip: "Delete Brand",
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _addServiceToModel(model),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text("ADD SERVICE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _saveModelServices(model),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("SAVE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle_outlined, color: AppTheme.textMuted.withOpacity(0.1), size: 100),
          const SizedBox(height: 24),
          Text("No ${_selectedCategory}s Managed", style: const TextStyle(color: AppTheme.textBody, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Add your service models to show pricing to users", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
