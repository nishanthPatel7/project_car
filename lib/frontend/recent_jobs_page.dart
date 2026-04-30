import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/app_theme.dart';
import '../backend/api_service.dart';
import '../backend/pdf_helper.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class RecentJobsPage extends StatefulWidget {
  final String module;
  final String? garageId;
  const RecentJobsPage({super.key, this.module = 'garage', this.garageId});

  @override
  State<RecentJobsPage> createState() => _RecentJobsPageState();
}

class _RecentJobsPageState extends State<RecentJobsPage> {
  int _visibleCount = 10;
  bool _isInitialLoad = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textBody, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.module == 'garage' ? "COMPLETED HISTORY" : "SERVICE HISTORY", 
          style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: widget.module == 'garage' ? ApiService().getGarageJobs(garageId: widget.garageId) : ApiService().getUserJobs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _isInitialLoad) {
            return _buildSkeletonList();
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading history", style: TextStyle(color: AppTheme.danger)));
          }

          final List rawJobs = (snapshot.data?['jobs'] as List?) ?? [];
          final seenIds = <dynamic>{};
          final allJobs = rawJobs.where((j) => seenIds.add(j['id'])).toList();

          final jobs = allJobs.where((j) => 
            j['status']?.toString().trim().toLowerCase() == 'completed'
          ).toList();
          
          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, color: AppTheme.textMuted.withOpacity(0.2), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    allJobs.isEmpty ? "No history records found" : "No completed jobs yet", 
                    style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 12)
                  ),
                ],
              ),
            );
          }

          _isInitialLoad = false;
          final displayJobs = jobs.take(_visibleCount).toList();
          final hasMore = jobs.length > _visibleCount;

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: displayJobs.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < displayJobs.length) {
                return _buildJobCard(context, displayJobs[index]);
              } else {
                return _buildLoadMoreButton(jobs.length - _visibleCount);
              }
            },
          );
        }
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 6,
      itemBuilder: (context, index) => FadeIn(
        duration: const Duration(milliseconds: 800),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Container(width: 40, height: 40, decoration: const BoxDecoration(color: AppTheme.surfaceLighter, shape: BoxShape.circle)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 120, height: 12, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 80, height: 8, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
              Container(width: 60, height: 16, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton(int remaining) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: GestureDetector(
          onTap: () => setState(() => _visibleCount += 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text("SHOW MORE ($remaining)", style: AppTheme.monoStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> job) {
    final name = job['display_name'] ?? "Customer";
    final car = "${job['brand'] ?? ''} ${job['vehicle_no'] ?? ''}";
    final amount = job['total_amount'];

    return FadeInUp(
      duration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: () => _showDetailsModal(context, job),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.6), 
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.surfaceLighter.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary.withOpacity(0.1), 
                child: Text(name.isNotEmpty ? name[0] : "?", style: const TextStyle(color: AppTheme.primary))
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(car, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              if (amount != null && amount > 0)
                Text("₹$amount", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppTheme.success, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailsModal(BuildContext context, Map<String, dynamic> job) {
    Map<String, dynamic> costMap = {};
    if (job['cost_details'] != null && job['cost_details'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(job['cost_details']);
        if (decoded is List) {
          for (var item in decoded) {
            costMap[item['name'].toString()] = item['cost'];
          }
        } else if (decoded is Map) {
          costMap = decoded.cast<String, dynamic>();
        }
      } catch (e) {
        debugPrint("Error parsing cost_details: $e");
      }
    }
    final List<dynamic> services = jsonDecode(job['service_types'] ?? '[]');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("JOB SUMMARY", style: TextStyle(color: AppTheme.textBody, fontSize: 20, fontWeight: FontWeight.bold)),
                            if (job['invoice_no'] != null)
                              Text("#${job['invoice_no']}", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text("₹${job['total_amount'] ?? 0}", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailSection("Customer Details", [
                      _buildDetailRow(Icons.person_rounded, "Name", job['display_name'] ?? "Unknown"),
                      _buildDetailRow(Icons.directions_car_rounded, "Vehicle", "${job['brand'] ?? ''} ${job['vehicle_no'] ?? ''}"),
                      _buildDetailRow(Icons.calendar_today_rounded, "Date", DateFormat('dd MMM yyyy · hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0))),
                    ]),
                    const SizedBox(height: 24),
                    const Text("ITEMIZED SERVICES", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.surfaceLighter)),
                      child: Column(
                        children: [
                          if (services.isEmpty) 
                            const Text("No services recorded", style: TextStyle(color: AppTheme.textMuted))
                          else
                            ...services.map((s) {
                              final item = costMap[s.toString()];
                              final price = item is Map 
                                ? (int.tryParse(item['cost'].toString()) ?? 0) * (int.tryParse(item['qty'].toString()) ?? 1)
                                : (int.tryParse(item.toString()) ?? 0);

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(s.toString(), style: const TextStyle(color: AppTheme.textBody, fontWeight: FontWeight.w500)),
                                    Text("₹$price", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 14)),
                                  ],
                                ),
                              );
                            }),
                          const Divider(color: AppTheme.surfaceLighter, height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("TOTAL AMOUNT", style: TextStyle(color: AppTheme.textBody, fontWeight: FontWeight.bold)),
                              Text("₹${job['total_amount'] ?? 0}", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (job['problem'] != null && job['problem'].toString().isNotEmpty) ...[
                      const Text("ADDITIONAL NOTES", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      Text(job['problem'], style: const TextStyle(color: AppTheme.textBody, height: 1.5)),
                    ],
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () => PdfHelper.generateJobInvoice(job),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text("DOWNLOAD PDF", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
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

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        ...children,
      ],
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
}
