import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';
import '../backend/pdf_helper.dart';

import 'book_service_page.dart';
import 'notifications_page.dart';
import 'service_location_page.dart';

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  bool _isLoading = true;
  List _activeJobs = [];
  List _historyJobs = [];

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    final res = await ApiService().getInitialState();
    if (mounted) {
      setState(() {
        final List rawActive = res['data']?['activeJobs'] ?? [];
        final List rawHistory = res['data']?['historyJobs'] ?? [];
        
        final seenActive = <dynamic>{};
        _activeJobs = rawActive.where((j) => seenActive.add(j['id'])).toList();
        
        final seenHistory = <dynamic>{};
        _historyJobs = rawHistory.where((j) => seenHistory.add(j['id'])).toList();
        
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
        title: const Text("MY BOOKINGS", style: TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
                  _buildSectionHeader("ACTIVE SERVICES", _activeJobs.length),
                  const SizedBox(height: 16),
                  if (_activeJobs.isEmpty)
                    _buildEmptyState("No active services at the moment")
                  else
                    for (var job in _activeJobs)
                      FadeInRight(child: _buildJobCard(job, isActive: true)),
                  
                  const SizedBox(height: 32),
                  
                  _buildSectionHeader("SERVICE HISTORY", _historyJobs.length),
                  const SizedBox(height: 16),
                  if (_historyJobs.isEmpty)
                    _buildEmptyState("Your completed services will appear here")
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

  Widget _buildEmptyState(String msg) {
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
          Icon(Icons.calendar_today_rounded, color: AppTheme.textMuted.withOpacity(0.3), size: 48),
          const SizedBox(height: 16),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookServicePage())),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("BOOK A SERVICE NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map job, {required bool isActive}) {
    final status = job['status'] ?? 'pending';
    final date = DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0);
    final dateStr = "${date.day}/${date.month}/${date.year}";

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
      onTap: () => _showBookingDetails(job),
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
                    Text(job['vehicle_no'] ?? job['vehicleNo'] ?? "Unknown Vehicle", style: const TextStyle(color: AppTheme.textBody, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceLocationPage(initialGarageUid: job['garage_uid']))),
                      child: Text(job['garage_name'] ?? job['garageName'] ?? job['garage'] ?? job['partner_name'] ?? job['partnerName'] ?? "Partnered Garage", 
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, decoration: TextDecoration.underline, decorationColor: AppTheme.textMuted)),
                    ),
                    if (!isActive) ...[
                      const SizedBox(height: 4),
                      Text(dateStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ],
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                    if (isActive) ...[
                      const SizedBox(height: 6),
                      Text(dateStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ] else if (!isActive && (job['total_amount'] ?? job['totalAmount']) != null) ...[
                      const SizedBox(height: 8),
                      Text("₹${job['total_amount'] ?? job['totalAmount']}", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.background,
                  color: statusColor,
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(status == 'pending' ? "Booking Confirmed" : "Service in Progress", style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  Text("${(progress * 100).toInt()}%", style: AppTheme.monoStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBookingDetails(Map job) {
    final status = job['status'] ?? 'pending';
    final date = DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0);
    final dateStr = DateFormat('dd MMM yyyy · hh:mm a').format(date);
    
    Color statusColor = AppTheme.primary;
    if (status == 'working' || status == 'in_progress') statusColor = AppTheme.warning;
    if (status == 'completed') statusColor = AppTheme.success;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Booking Details", style: TextStyle(color: AppTheme.textBody, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text("ID: #${job['id'] ?? job['invoice_no'] ?? 'N/A'}", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                  Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'completed' ? AppTheme.success.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(8)
                      ),
                      child: Text(
                        status.toString().toUpperCase(), 
                        style: TextStyle(
                          color: status == 'completed' ? AppTheme.success : AppTheme.primary, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(dateStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: _buildCompactDetail("VEHICLE", job['vehicle_no'] ?? job['vehicleNo'] ?? "N/A", Icons.directions_car_filled_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCompactDetail("GARAGE", job['garage_name'] ?? job['garageName'] ?? job['garage'] ?? "Partner Garage", Icons.store_rounded, 
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceLocationPage(initialGarageUid: job['garage_uid']))))),
                ],
              ),
              if ((job['problem_desc'] ?? job['problemDesc']) != null && (job['problem_desc'] ?? job['problemDesc']).toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCompactDetail("ISSUE", job['problem_desc'] ?? job['problemDesc'], Icons.report_problem_rounded),
              ],
              
              const SizedBox(height: 24),
              const Divider(color: AppTheme.surfaceLighter),
              const SizedBox(height: 24),
              
              Text("SERVICES", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 16),
              if ((job['service_types'] ?? job['serviceTypes']) != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (() {
                    var services = job['service_types'] ?? job['serviceTypes'];
                    if (services is String && services.startsWith('[') && services.endsWith(']')) {
                      try { services = jsonDecode(services); } catch (e) {}
                    }
                    if (services is List) {
                      return services.map((s) => _buildServiceChip(s.toString())).toList();
                    } else if (services is String) {
                      return [_buildServiceChip(services)];
                    }
                    return <Widget>[];
                  })(),
                )
              else
                _buildServiceChip("General Service"),
              
              if (status == 'completed' && (job['total_amount'] ?? job['totalAmount']) != null) ...[
                const SizedBox(height: 24),
                const Divider(color: AppTheme.surfaceLighter),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL PAID", style: TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("₹${job['total_amount'] ?? job['totalAmount']}", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => PdfHelper.generateJobInvoice(Map<String, dynamic>.from(job)),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: const Text("DOWNLOAD INVOICE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDetail(String label, String value, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface, 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: onTap != null ? AppTheme.primary.withOpacity(0.3) : AppTheme.surfaceLighter)
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text(value, 
                    style: TextStyle(
                      color: AppTheme.textBody, 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold,
                      decoration: onTap != null ? TextDecoration.underline : null,
                    ), 
                    overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.success.withOpacity(0.2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: AppTheme.textBody, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.surfaceLighter)),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 4,
      itemBuilder: (context, index) => FadeIn(
        duration: const Duration(milliseconds: 800),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 140, height: 16, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
                  Container(width: 80, height: 24, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(12))),
                ],
              ),
              const SizedBox(height: 24),
              Container(width: double.infinity, height: 6, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 100, height: 10, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
                  Container(width: 30, height: 10, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
