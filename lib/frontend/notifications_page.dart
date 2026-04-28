import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/app_theme.dart';
import '../backend/api_service.dart';

class NotificationsPage extends StatefulWidget {
  final String module;
  const NotificationsPage({super.key, this.module = 'user'});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    _markRead();
  }

  void _markRead() async {
    await ApiService().markNotificationsAsRead(module: widget.module);
  }

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
        title: Text(widget.module == 'garage' ? "GARAGE NOTIFICATIONS" : "USER NOTIFICATIONS", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService().getNotifications(module: widget.module),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildSkeletonList();
          }

          if (snapshot.hasError) {
            return const Center(child: Text("Error loading notifications", style: TextStyle(color: AppTheme.danger)));
          }

          final notifications = snapshot.data?['notifications'] ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_rounded, color: AppTheme.textMuted.withOpacity(0.2), size: 64),
                  const SizedBox(height: 16),
                  Text("No notifications yet", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final n = notifications[index];
              return _buildNotificationItem(
                icon: _parseIcon(n['icon']),
                color: _parseColor(n['color']),
                title: n['title'] ?? "Alert",
                desc: n['desc'] ?? "",
                time: _formatTime(n['created_at']),
                isRead: n['is_read'] == 1,
              );
            },
          );
        }
      ),
    );
  }

  IconData _parseIcon(String? icon) {
    switch (icon) {
      case 'check': return Icons.check_circle_rounded;
      case 'inventory': return Icons.inventory_2_rounded;
      case 'warning': return Icons.campaign_rounded;
      case 'security': return Icons.security_rounded;
      case 'verified_user_rounded': return Icons.verified_user_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _parseColor(String? color) {
    switch (color) {
      case 'success': return AppTheme.success;
      case 'primary': return AppTheme.primary;
      case 'warning': return AppTheme.warning;
      case 'info': return AppTheme.info;
      default: return AppTheme.primary;
    }
  }

  String _formatTime(dynamic ts) {
    if (ts == null) return "";
    final dt = DateTime.fromMillisecondsSinceEpoch(ts is int ? ts : int.parse(ts.toString()));
    return "${dt.hour}:${dt.minute}";
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title, 
        style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required String time,
    bool isRead = true,
  }) {
    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.surfaceLighter),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (!isRead)
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: isRead ? FontWeight.bold : FontWeight.w900)),
                      Text(time, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc, 
                    style: TextStyle(color: isRead ? AppTheme.textMuted : AppTheme.textBody.withOpacity(0.8), fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          height: 100,
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
            ],
          ),
        ),
      ),
    );
  }
}
