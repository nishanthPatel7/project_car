import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';
import '../backend/pdf_helper.dart';
import 'dart:convert';

class GarageBookingsPage extends StatefulWidget {
  final String? garageId;
  const GarageBookingsPage({super.key, this.garageId});

  @override
  State<GarageBookingsPage> createState() => _GarageBookingsPageState();
}

class _GarageBookingsPageState extends State<GarageBookingsPage> {
  bool _isLoading = true;
  List _activeJobs = [];
  List _historyJobs = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    final res = await ApiService().getGarageJobs(garageId: widget.garageId);
    if (mounted) {
      final rawJobs = res['jobs'];
      final List allJobs = (rawJobs is List) ? rawJobs : [];
      
      setState(() {
        _activeJobs = allJobs.where((j) {
          final s = (j['status'] ?? '').toString().toLowerCase().trim();
          return s == 'pending' || s == 'working' || s == 'in_progress' || s == 'ongoing' || s == 'confirmed';
        }).toList();
        
        _historyJobs = allJobs.where((j) => 
          j['status']?.toString().toLowerCase().trim() == 'completed'
        ).toList();
        
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("SERVICE MONITOR", style: TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textBody, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? _buildSkeletonList()
        : RefreshIndicator(
            onRefresh: _fetchBookings,
            color: AppTheme.primary,
            backgroundColor: AppTheme.surface,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("ONGOING SERVICES", _activeJobs.length),
                  const SizedBox(height: 16),
                  if (_activeJobs.isEmpty)
                    _buildEmptyState("No active services", Icons.engineering_rounded)
                  else
                    for (var job in _activeJobs)
                      FadeInRight(child: _buildJobCard(job, isActive: true)),
                  
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader("COMPLETED HISTORY", _historyJobs.length),
                  const SizedBox(height: 16),
                  if (_historyJobs.isEmpty)
                    _buildEmptyState("No history records", Icons.history_rounded)
                  else
                    for (var job in _historyJobs)
                      FadeInUp(child: _buildJobCard(job, isActive: false)),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(title, style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(count.toString(), style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceLighter),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.textMuted.withOpacity(0.3), size: 48),
          const SizedBox(height: 16),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _fetchBookings,
            child: const Text("RELOAD DATA", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map job, {required bool isActive}) {
    final status = job['status'] ?? 'pending';
    final name = job['display_name'] ?? "Customer";
    final car = "${job['brand'] ?? ''} ${job['vehicle_no'] ?? ''}";

    Color statusColor = AppTheme.primary;
    String statusLabel = "PENDING";
    double progress = 0.33;

    if (status == 'working' || status == 'in_progress') {
      statusColor = AppTheme.warning;
      statusLabel = "WORKING";
      progress = 0.66;
    } else if (status == 'completed') {
      statusColor = AppTheme.success;
      statusLabel = "COMPLETED";
      progress = 1.0;
    }

    return GestureDetector(
      onTap: () => _showDetailsModal(context, Map<String, dynamic>.from(job)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isActive ? statusColor.withOpacity(0.3) : AppTheme.surfaceLighter, width: isActive ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(car, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isActive) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.background,
                  color: statusColor,
                  minHeight: 6,
                ),
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                  const SizedBox(width: 8),
                  const Text("Service completed", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  const Spacer(),
                  Text("₹${job['total_amount'] ?? 0}", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetailsModal(BuildContext context, Map<String, dynamic> job) {
    // Logic similar to RecentJobsPage for details/invoice
    // Reusing the modal structure for consistency
    final Map<String, dynamic> costs = jsonDecode(job['cost_details'] ?? '{}');
    final List<dynamic> services = jsonDecode(job['service_types'] ?? '[]');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("JOB DETAILS", style: TextStyle(color: AppTheme.textBody, fontSize: 20, fontWeight: FontWeight.bold)),
                        if (job['status'] == 'completed')
                          Text("₹${job['total_amount'] ?? 0}", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(Icons.person_rounded, "Customer", job['display_name'] ?? "Unknown"),
                    _buildDetailRow(Icons.directions_car_rounded, "Vehicle", "${job['brand'] ?? ''} ${job['vehicle_no'] ?? ''}"),
                    _buildDetailRow(Icons.calendar_today_rounded, "Date", DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0).toString().split(' ')[0]),
                    const SizedBox(height: 32),
                    const Text("SERVICES", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    ...services.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(s.toString(), style: const TextStyle(color: AppTheme.textBody)),
                          if (job['status'] == 'completed')
                            Text("₹${costs[s] ?? 0}", style: AppTheme.monoStyle(color: AppTheme.textBody)),
                        ],
                      ),
                    )),
                    if (job['status'] == 'completed') ...[
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity, height: 60,
                        child: ElevatedButton(
                          onPressed: () => PdfHelper.generateJobInvoice(job),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: const Text("DOWNLOAD INVOICE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 100,
        decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.3), borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
