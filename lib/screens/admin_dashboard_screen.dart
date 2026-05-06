import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/appointment.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _filterStatus = 'All';

  static const List<String> _filterOptions = [
    'All', 'Scheduled', 'In Progress', 'Completed', 'Cancelled',
  ];

  // ── Color helpers ─────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'In Progress': return const Color(0xFFF59E0B);
      case 'Completed':   return const Color(0xFF10B981);
      case 'Cancelled':   return const Color(0xFFEF4444);
      default:            return const Color(0xFF1976D2);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'In Progress': return Icons.hourglass_top_rounded;
      case 'Completed':   return Icons.check_circle_rounded;
      case 'Cancelled':   return Icons.cancel_rounded;
      default:            return Icons.schedule_rounded;
    }
  }

  // ── Firestore batch operations ────────────────────────────────────────────

  /// Marks [apt] as Completed; promotes the next Scheduled → In Progress.
  Future<void> _serve(List<Appointment> allApts, Appointment apt) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // Complete current
    batch.update(db.collection('appointments').doc(apt.id), {'status': 'Completed'});

    // Find next Scheduled sorted by queuePosition
    final next = allApts
        .where((a) => a.status == 'Scheduled' && a.id != apt.id)
        .toList()
      ..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));

    if (next.isNotEmpty) {
      batch.update(
        db.collection('appointments').doc(next.first.id),
        {'status': 'In Progress'},
      );
    }

    await batch.commit();
  }

  /// Moves [apt] to the last position in the queue.
  Future<void> _skip(List<Appointment> allApts, Appointment apt) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    final maxPos = allApts.map((a) => a.queuePosition).reduce((a, b) => a > b ? a : b);
    batch.update(db.collection('appointments').doc(apt.id), {'queuePosition': maxPos + 1});

    await batch.commit();
  }

  /// Cancels [apt].
  Future<void> _cancel(Appointment apt) async {
    await FirebaseFirestore.instance
        .collection('appointments')
        .doc(apt.id)
        .update({'status': 'Cancelled'});
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1976D2);
    final today = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .orderBy('dateTime')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1976D2)),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allApts = (snapshot.data?.docs ?? [])
              .map((d) => Appointment.fromMap(d.data() as Map<String, dynamic>, d.id))
              .toList();

          // ── Compute stats ───────────────────────────────────────────────
          final todayApts = allApts.where((a) =>
              a.dateTime.year == today.year &&
              a.dateTime.month == today.month &&
              a.dateTime.day == today.day).toList();

          final totalToday = todayApts.length;
          final inQueue = allApts.where((a) =>
              a.status == 'Scheduled' || a.status == 'In Progress').length;
          final completed = allApts.where((a) => a.status == 'Completed').length;

          // ── Active queue ────────────────────────────────────────────────
          final activeQueue = allApts
              .where((a) => a.status == 'Scheduled' || a.status == 'In Progress')
              .toList()
            ..sort((a, b) => a.queuePosition.compareTo(b.queuePosition));

          // ── Filtered list ───────────────────────────────────────────────
          final filtered = _filterStatus == 'All'
              ? allApts
              : allApts.where((a) => a.status == _filterStatus).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Stats row ─────────────────────────────────────────────
              Row(children: [
                Expanded(child: _StatCard(
                  label: 'Total Today', value: '$totalToday',
                  icon: Icons.today_rounded, color: primary)),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  label: 'In Queue', value: '$inQueue',
                  icon: Icons.people_rounded, color: const Color(0xFFF59E0B))),
                const SizedBox(width: 10),
                Expanded(child: _StatCard(
                  label: 'Completed', value: '$completed',
                  icon: Icons.check_circle_rounded, color: const Color(0xFF10B981))),
              ]),
              const SizedBox(height: 24),

              // ── Active Queue section ──────────────────────────────────
              _SectionHeader(
                icon: Icons.queue_rounded,
                title: 'Active Queue',
                count: activeQueue.length,
                color: primary,
              ),
              const SizedBox(height: 10),

              if (activeQueue.isEmpty)
                _EmptySection(message: 'No active appointments in queue.')
              else
                ...activeQueue.map((apt) => _ActiveQueueCard(
                  apt: apt,
                  statusColor: _statusColor(apt.status),
                  statusIcon: _statusIcon(apt.status),
                  onServe: () => _serve(allApts, apt),
                  onSkip: () => _skip(allApts, apt),
                  onCancel: () => _cancel(apt),
                )),

              const SizedBox(height: 24),

              // ── All Appointments section ──────────────────────────────
              _SectionHeader(
                icon: Icons.list_alt_rounded,
                title: 'All Appointments',
                count: allApts.length,
                color: const Color(0xFF6B7280),
              ),
              const SizedBox(height: 10),

              // Filter chips
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _filterOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final opt = _filterOptions[i];
                    final isSelected = _filterStatus == opt;
                    final chipColor = opt == 'All'
                        ? primary
                        : _statusColor(opt);
                    return FilterChip(
                      label: Text(opt,
                          style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : chipColor,
                              fontWeight: FontWeight.w600)),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _filterStatus = opt),
                      selectedColor: chipColor,
                      backgroundColor: chipColor.withValues(alpha: 0.08),
                      checkmarkColor: Colors.white,
                      side: BorderSide(color: chipColor.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              if (filtered.isEmpty)
                _EmptySection(message: 'No appointments for "$_filterStatus".')
              else
                ...filtered.map((apt) => _AllAppointmentRow(
                  apt: apt,
                  statusColor: _statusColor(apt.status),
                  statusIcon: _statusIcon(apt.status),
                )),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ),
    ]);
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(message,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
      ),
    );
  }
}

class _ActiveQueueCard extends StatelessWidget {
  const _ActiveQueueCard({
    required this.apt,
    required this.statusColor,
    required this.statusIcon,
    required this.onServe,
    required this.onSkip,
    required this.onCancel,
  });
  final Appointment apt;
  final Color statusColor;
  final IconData statusIcon;
  final VoidCallback onServe;
  final VoidCallback onSkip;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1976D2);
    final time = DateFormat('hh:mm a').format(apt.dateTime);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 10),
      shadowColor: primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Queue number
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('#${apt.queuePosition}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: statusColor, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apt.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15, color: Color(0xFF1A237E))),
                    Text('${apt.serviceType}  ·  $time',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),

              // Status chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(statusIcon, size: 11, color: statusColor),
                  const SizedBox(width: 4),
                  Text(apt.status,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: statusColor)),
                ]),
              ),
            ]),

            const SizedBox(height: 12),

            // Action buttons
            Row(children: [
              Expanded(child: _ActionBtn(
                label: '✓ Serve',
                color: const Color(0xFF10B981),
                onTap: onServe,
              )),
              const SizedBox(width: 8),
              Expanded(child: _ActionBtn(
                label: '↓ Skip',
                color: const Color(0xFFF59E0B),
                onTap: onSkip,
              )),
              const SizedBox(width: 8),
              Expanded(child: _ActionBtn(
                label: '✕ Cancel',
                color: const Color(0xFFEF4444),
                onTap: onCancel,
              )),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        backgroundColor: color.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

class _AllAppointmentRow extends StatelessWidget {
  const _AllAppointmentRow({
    required this.apt,
    required this.statusColor,
    required this.statusIcon,
  });
  final Appointment apt;
  final Color statusColor;
  final IconData statusIcon;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1976D2);
    final formattedDt = DateFormat('dd MMM, hh:mm a').format(apt.dateTime);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shadowColor: primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(statusIcon, color: statusColor, size: 18),
        ),
        title: Text(apt.name,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14,
                color: Color(0xFF1A237E))),
        subtitle: Text('${apt.serviceType}  ·  $formattedDt',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.4)),
              ),
              child: Text(apt.status,
                  style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
            ),
            const SizedBox(height: 4),
            Text('#${apt.queuePosition}',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
