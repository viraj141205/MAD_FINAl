import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/appointment_provider.dart';
import 'queue_status_screen.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  static const List<String> _statusOptions = [
    'All', 'Scheduled', 'In Progress', 'Completed', 'Cancelled',
  ];

  static const List<String> _serviceTypes = [
    'All Services',
    'General Consultation',
    'Dental',
    'Hair Cut',
    'Document Submission',
    'Other',
  ];

  final _searchCtrl = TextEditingController();

  String _selectedStatus = 'All';
  String _selectedService = 'All Services';
  DateTime? _selectedDate;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF1976D2)),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void _clearAll() {
    setState(() {
      _searchCtrl.clear();
      _selectedStatus = 'All';
      _selectedService = 'All Services';
      _selectedDate = null;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _hasActiveFilters =>
      _searchCtrl.text.isNotEmpty ||
      _selectedStatus != 'All' ||
      _selectedService != 'All Services' ||
      _selectedDate != null;

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        title: const Text('Search & Filter'),
        actions: [
          if (_hasActiveFilters)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear All',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter panel ────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search field
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name or booking ID…',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF1976D2)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF5F9FF),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.blue.shade100, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFF1976D2), width: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Status chips row
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statusOptions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final opt = _statusOptions[i];
                      final isSelected = _selectedStatus == opt;
                      final chipColor = opt == 'All'
                          ? primary
                          : _statusColor(opt);
                      return FilterChip(
                        label: Text(opt,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : chipColor)),
                        selected: isSelected,
                        onSelected: (_) =>
                            setState(() => _selectedStatus = opt),
                        selectedColor: chipColor,
                        backgroundColor: chipColor.withValues(alpha: 0.08),
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                            color: chipColor.withValues(alpha: 0.4)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // Service dropdown + Date picker row
                Row(children: [
                  // Service dropdown
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.blue.shade100, width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedService,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down_rounded,
                              color: Color(0xFF1976D2)),
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A237E),
                              fontWeight: FontWeight.w500),
                          items: _serviceTypes
                              .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s,
                                        overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedService = v);
                            }
                          },
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Date picker button
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: _selectedDate != null
                            ? primary.withValues(alpha: 0.1)
                            : const Color(0xFFF5F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _selectedDate != null
                              ? primary.withValues(alpha: 0.5)
                              : Colors.blue.shade100,
                          width: 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 15,
                            color: _selectedDate != null
                                ? primary
                                : Colors.grey.shade500),
                        const SizedBox(width: 6),
                        Text(
                          _selectedDate == null
                              ? 'Filter by Date'
                              : DateFormat('dd MMM').format(_selectedDate!),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _selectedDate != null
                                  ? primary
                                  : Colors.grey.shade600),
                        ),
                        if (_selectedDate != null) ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedDate = null),
                            child: Icon(Icons.close_rounded,
                                size: 14, color: primary),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ]),
              ],
            ),
          ),

          // ── Results list ────────────────────────────────────────────────
          Expanded(
            child: Consumer<AppointmentProvider>(
              builder: (context, provider, _) {
                final results = provider.getFilteredAppointments(
                  search: _searchCtrl.text.trim().isEmpty
                      ? null
                      : _searchCtrl.text.trim(),
                  status: _selectedStatus == 'All' ? null : _selectedStatus,
                  serviceType: _selectedService == 'All Services'
                      ? null
                      : _selectedService,
                  date: _selectedDate,
                );

                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF1976D2)),
                  );
                }

                if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 72,
                            color: primary.withValues(alpha: 0.2)),
                        const SizedBox(height: 14),
                        Text(
                          _hasActiveFilters
                              ? 'No results match your filters.'
                              : 'Start searching above.',
                          style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        if (_hasActiveFilters) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _clearAll,
                            icon: const Icon(Icons.filter_alt_off_rounded),
                            label: const Text('Clear Filters'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final apt = results[i];
                    final statusColor = _statusColor(apt.status);
                    final formattedDt = DateFormat('dd MMM yyyy, hh:mm a')
                        .format(apt.dateTime);

                    return Card(
                      elevation: 2,
                      shadowColor: primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                QueueStatusScreen(appointment: apt),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            // Queue badge
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('#${apt.queuePosition}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primary,
                                          fontSize: 13)),
                                  Text('Q',
                                      style: TextStyle(
                                          fontSize: 8,
                                          color: primary.withValues(
                                              alpha: 0.6))),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(apt.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF1A237E))),
                                  const SizedBox(height: 2),
                                  Text(apt.serviceType,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600)),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    Icon(Icons.access_time_rounded,
                                        size: 11,
                                        color: Colors.grey.shade500),
                                    const SizedBox(width: 3),
                                    Text(formattedDt,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500)),
                                  ]),
                                ],
                              ),
                            ),

                            // Status chip + icon
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _SearchStatusBadge(
                                    status: apt.status,
                                    color: statusColor),
                                const SizedBox(height: 5),
                                Icon(_statusIcon(apt.status),
                                    color: statusColor, size: 16),
                              ],
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge ──────────────────────────────────────────────────────────────────────

class _SearchStatusBadge extends StatelessWidget {
  const _SearchStatusBadge({required this.status, required this.color});
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
