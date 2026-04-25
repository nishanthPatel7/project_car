import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/app_theme.dart';
import '../backend/api_service.dart';
import '../backend/pdf_helper.dart';
import 'dart:convert';

class RecentJobsPage extends StatelessWidget {
  const RecentJobsPage({super.key});

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
        title: Text("ALL JOBS", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService().getGarageJobs(),
        builder: (context, snapshot) {
          final jobs = snapshot.data?['jobs'] ?? [];
          
          if (jobs.isEmpty) {
            return Center(child: Text("No jobs found", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 12)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return _buildJobCard(context, job);
            },
          );
        }
      ),
    );
  }

  Widget _buildJobCard(BuildContext context, Map<String, dynamic> job) {
    final name = job['display_name'] ?? "Customer";
    final car = "${job['brand'] ?? ''} ${job['vehicle_no'] ?? ''}";
    final status = job['status']?.toString().toUpperCase() ?? "PENDING";
    final statusColor = job['status'] == 'completed' ? AppTheme.success : AppTheme.warning;
    final amount = job['total_amount'];

    return FadeInUp(
      child: GestureDetector(
        onTap: () => _showDetailsModal(context, job),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface, 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: AppTheme.surfaceLighter)
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primary.withOpacity(0.1), 
                child: Text(name[0], style: const TextStyle(color: AppTheme.primary))
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(car, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (amount != null && amount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text("₹$amount", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1), 
                      borderRadius: BorderRadius.circular(12), 
                      border: Border.all(color: statusColor.withOpacity(0.3))
                    ),
                    child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailsModal(BuildContext context, Map<String, dynamic> job) {
    final Map<String, dynamic> costs = jsonDecode(job['cost_details'] ?? '{}');
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
                      _buildDetailRow(Icons.calendar_today_rounded, "Date", DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0).toString().split(' ')[0]),
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
                            ...services.map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(s.toString(), style: const TextStyle(color: AppTheme.textBody, fontWeight: FontWeight.w500)),
                                  Text("₹${costs[s] ?? 0}", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 14)),
                                ],
                              ),
                            )),
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
