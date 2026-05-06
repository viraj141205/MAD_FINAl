import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/appointment.dart';
import '../providers/appointment_provider.dart';

class QueueStatusScreen extends StatelessWidget {
  const QueueStatusScreen({super.key, required this.appointment});

  final Appointment appointment;

  // ── Status helpers ────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'In Progress': return const Color(0xFFF59E0B);
      case 'Completed':   return const Color(0xFF10B981);
      case 'Cancelled':   return const Color(0xFFEF4444);
      default:            return const Color(0xFF1976D2); // Scheduled
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(title: const Text('Queue Status')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .doc(appointment.id)
            .snapshots(),
        builder: (context, snapshot) {
          // Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1976D2)),
            );
          }

          // Error
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Doc deleted or missing
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Appointment not found.'));
          }

          // Deserialise
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final apt = Appointment.fromMap(data, snapshot.data!.id);

          // Total active count for progress bar
          final totalCount = context
              .read<AppointmentProvider>()
              .appointments
              .where((a) => a.status != 'Cancelled')
              .length;
          final totalSafe = totalCount < 1 ? 1 : totalCount;
          final progress = (apt.queuePosition / totalSafe).clamp(0.0, 1.0);
          final estWait = apt.queuePosition * 10;

          final isCompleted = apt.status == 'Completed';
          final isCancelled = apt.status == 'Cancelled';
          final statusColor = _statusColor(apt.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // ── Status banner ───────────────────────────────────────────
                if (isCompleted)
                  _Banner(
                    color: const Color(0xFF10B981),
                    icon: Icons.check_circle_rounded,
                    message: "You've been served!",
                  )
                else if (isCancelled)
                  _Banner(
                    color: const Color(0xFFEF4444),
                    icon: Icons.cancel_rounded,
                    message: 'Appointment cancelled',
                  ),

                if (isCompleted || isCancelled) const SizedBox(height: 16),

                // ── Main detail card ────────────────────────────────────────
                Card(
                  elevation: 6,
                  shadowColor: primary.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status chip row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Appointment',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E))),
                            _StatusChip(status: apt.status, color: statusColor,
                                icon: _statusIcon(apt.status)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // Detail rows — Hero on Booking ID for shared-element transition
                        _DetailRow(
                          icon: Icons.badge_outlined,
                          label: 'Booking ID',
                          value: apt.id.substring(0, 8).toUpperCase(),
                          heroTag: 'appt-${apt.id}',
                        ),
                        _DetailRow(
                          icon: Icons.person_outline,
                          label: 'Name',
                          value: apt.name,
                        ),
                        _DetailRow(
                          icon: Icons.medical_services_outlined,
                          label: 'Service',
                          value: apt.serviceType,
                        ),
                        _DetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Date & Time',
                          value: DateFormat('dd MMM yyyy, hh:mm a')
                              .format(apt.dateTime),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Queue info card ─────────────────────────────────────────
                if (!isCancelled)
                  Card(
                    elevation: 4,
                    shadowColor: primary.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Queue Information',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A237E))),
                          const SizedBox(height: 20),

                          // Position & wait
                          Row(children: [
                            Expanded(
                              child: _QueueStat(
                                icon: Icons.format_list_numbered_rounded,
                                label: 'Position',
                                value: '#${apt.queuePosition}',
                                color: primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QueueStat(
                                icon: Icons.timer_outlined,
                                label: 'Est. Wait',
                                value: '$estWait min',
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 22),

                          // Progress label
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Queue Progress',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700)),
                              Text(
                                '${apt.queuePosition} / $totalSafe',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Animated progress bar
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: progress),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (_, value, __) => ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: value,
                                minHeight: 12,
                                backgroundColor: const Color(0xFFE0EDFF),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    statusColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Live indicator
                          Row(children: [
                            Container(
                              width: 8, height: 8,
                              decoration: const BoxDecoration(
                                  color: Colors.green, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text('Live updates enabled',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500)),
                          ]),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.message});
  final Color color;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Text(message,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.color, required this.icon});
  final String status;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(status,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.heroTag,
  });
  final IconData icon;
  final String label;
  final String value;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A237E)),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF1976D2), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 2),
            heroTag != null
                ? Hero(
                    tag: heroTag!,
                    child: Material(
                      color: Colors.transparent,
                      child: valueText,
                    ),
                  )
                : valueText,
          ]),
        ),
      ]),
    );
  }
}

class _QueueStat extends StatelessWidget {
  const _QueueStat({required this.icon, required this.label,
      required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    );
  }
}
