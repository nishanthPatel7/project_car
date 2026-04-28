import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';

class AdminGarageRequestsPage extends StatefulWidget {
  const AdminGarageRequestsPage({super.key});

  @override
  State<AdminGarageRequestsPage> createState() => _AdminGarageRequestsPageState();
}

class _AdminGarageRequestsPageState extends State<AdminGarageRequestsPage> {
  bool _isLoading = true;
  List<dynamic> _requests = [];
  String _searchQuery = "";
  String _selectedFilter = "pending";

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().getGarageRequestsAdmin();
      if (mounted) {
        setState(() {
          final List<dynamic> rawRequests = res['requests'] ?? [];
          _requests = rawRequests.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredRequests {
    return _requests.where((req) {
      final matchesStatus = (req['status'] ?? 'pending').toString().toLowerCase() == _selectedFilter.toLowerCase();
      final matchesSearch = (req['name'] ?? "").toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesStatus && matchesSearch;
    }).toList();
  }

  Future<void> _handleDecision(int id, String status) async {
    final res = await ApiService().updateGarageRequestStatus(id, status);
    if (res['status'] == 'success') {
      _fetchRequests();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Request marked as $status"), 
          backgroundColor: status == 'approved' ? AppTheme.success : AppTheme.danger
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("PARTNER REQUESTS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : _filteredRequests.isEmpty 
                ? Center(child: Text("No $_selectedFilter requests found", style: const TextStyle(color: AppTheme.textMuted)))
                : RefreshIndicator(
                    onRefresh: _fetchRequests,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _filteredRequests.length,
                      itemBuilder: (context, index) {
                        return _buildRequestCard(_filteredRequests[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.surfaceLighter)),
            child: TextField(
              style: const TextStyle(color: AppTheme.textBody, fontSize: 14),
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search by partner name...",
                hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                border: InputBorder.none,
                icon: Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFilterChip("pending", AppTheme.warning),
              _buildFilterChip("approved", AppTheme.success),
              _buildFilterChip("rejected", AppTheme.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, Color color) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color.withOpacity(0.5) : AppTheme.surfaceLighter),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(color: isSelected ? color : AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> req) {
    final status = req['status'] ?? 'pending';
    final Color statusColor = status == 'pending' ? AppTheme.warning : (status == 'approved' ? AppTheme.success : AppTheme.danger);

    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTap: () => _showRequestDetails(req),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.surfaceLighter),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.storefront_rounded, color: statusColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req['name'] ?? "Unknown Owner", style: const TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      "${req['city']}, ${req['district']}\n${req['state']}", 
                      style: AppTheme.monoStyle(color: AppTheme.primary.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w500),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRequestDetails(Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: const BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.all(Radius.circular(2))))),
              const SizedBox(height: 32),
              Text("PARTNER APPLICATION", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(req['name'] ?? "No Store Name", style: const TextStyle(color: AppTheme.textBody, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              
              _buildDetailSection("Contact Info", [
                {"icon": Icons.person, "label": "Owner Name", "val": req['owner_name'] ?? "N/A"},
                {"icon": Icons.phone, "label": "Phone", "val": req['phone'] ?? "N/A"},
              ]),
              
              const SizedBox(height: 24),
              _buildDetailSection("Business Details", [
                {"icon": Icons.location_city, "label": "City", "val": req['city'] ?? "N/A"},
                {"icon": Icons.map, "label": "District / State", "val": "${req['district']}, ${req['state']}"},
                if (req['partner_id'] != null) {"icon": Icons.verified_user_rounded, "label": "Partner ID", "val": req['partner_id'].toString().toUpperCase()},
                {"icon": Icons.my_location, "label": "Coordinates", "val": req['location'] ?? "N/A"},
              ]),

              const SizedBox(height: 32),
              const Text("STORE ASSETS", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var url in (req['photo_urls'] as List))
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 250,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: AppTheme.surface,
                          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                          border: Border.all(color: AppTheme.surfaceLighter),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              if (req['status'] == 'pending') ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleDecision(req['id'], 'rejected'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger.withOpacity(0.1), foregroundColor: AppTheme.danger, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 20)),
                        child: const Text("REJECT", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleDecision(req['id'], 'approved'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 20)),
                        child: const Text("APPROVE PARTNER", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Map<String, dynamic>> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 16),
        for (var item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(item['icon'] as IconData, color: AppTheme.primary.withOpacity(0.5), size: 18),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['label'] as String, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    Text(item['val'] as String, style: AppTheme.monoStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
