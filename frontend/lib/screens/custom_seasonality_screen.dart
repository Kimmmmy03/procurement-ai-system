// screens/custom_seasonality_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../widgets/glass_dialog.dart';
import '../widgets/glass_skeleton.dart';
import '../widgets/animated_list_item.dart';

class CustomSeasonalityScreen extends StatefulWidget {
  const CustomSeasonalityScreen({super.key});

  @override
  State<CustomSeasonalityScreen> createState() => _CustomSeasonalityScreenState();
}

class _CustomSeasonalityScreenState extends State<CustomSeasonalityScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  // Calendar state
  late DateTime _calendarMonth;
  int _selectedYear = DateTime.now().year;

  static const _monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final data = await api.getCustomSeasonalityEvents();
      setState(() {
        _events = List<Map<String, dynamic>>.from(data['events'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        GlassNotification.show(context, 'Failed to load events: $e', isError: true);
      }
    }
  }

  Future<void> _deleteEvent(int eventId) async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.deleteCustomSeasonalityEvent(eventId);
      GlassNotification.show(context, 'Event deleted successfully');
      _loadEvents();
    } catch (e) {
      GlassNotification.show(context, 'Delete failed: $e', isError: true);
    }
  }

  void _showAddEditDialog({Map<String, dynamic>? event}) {
    showDialog(
      context: context,
      builder: (ctx) => _AddEditEventDialog(
        existingEvent: event,
        onSave: (data) async {
          try {
            final api = Provider.of<ApiService>(context, listen: false);
            await api.upsertCustomSeasonalityEvent(data);
            if (mounted) GlassNotification.show(context, 'Event saved successfully');
            _loadEvents();
          } catch (e) {
            if (mounted) GlassNotification.show(context, 'Save failed: $e', isError: true);
          }
        },
      ),
    );
  }

  int get _activeThisMonthCount {
    final currentMonth = DateTime.now().month;
    return _events.where((e) {
      final months = e['months'] as List?;
      if (months == null) return false;
      return months.any((m) {
        final idx = (m is int) ? m : (int.tryParse(m.toString()) ?? 0);
        return idx == currentMonth;
      });
    }).length;
  }

  double get _avgMultiplier {
    if (_events.isEmpty) return 0.0;
    final sum = _events.fold<double>(0.0, (s, e) => s + ((e['multiplier'] as num?)?.toDouble() ?? 1.0));
    return sum / _events.length;
  }

  /// Returns events active in a given month number (1-12).
  List<Map<String, dynamic>> _eventsForMonth(int month) {
    return _events.where((e) {
      final months = e['months'] as List?;
      if (months == null) return false;
      return months.any((m) {
        final idx = (m is int) ? m : (int.tryParse(m.toString()) ?? 0);
        return idx == month;
      });
    }).toList();
  }

  /// Get the date range string for an event's months in a given year.
  String _eventDateRange(Map<String, dynamic> event, int year) {
    final months = (event['months'] as List?)?.map((m) {
      return (m is int) ? m : (int.tryParse(m.toString()) ?? 1);
    }).toList()?..sort();
    if (months == null || months.isEmpty) return '';
    final startMonth = months.first;
    final endMonth = months.last;
    final lastDay = DateTime(year, endMonth + 1, 0).day;
    return '${startMonth.toString().padLeft(2, '0')}/01/$year - ${endMonth.toString().padLeft(2, '0')}/$lastDay/$year';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading ? _buildSkeletonLoading() : _buildLoadedContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB74D).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.event_note, color: Color(0xFFFFB74D), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Custom Seasonality Events',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                'Add company-specific peaks that override or supplement the AI calendar',
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
        ),
        _buildGlassButton(icon: Icons.refresh, label: 'Refresh', onTap: _loadEvents),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _showAddEditDialog(),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Event'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Skeleton Loading ---

  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: GlassSkeletonCard(
                padding: EdgeInsets.all(16),
                child: Row(children: [
                  GlassSkeleton(width: 32, height: 32, borderRadius: 8),
                  SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GlassSkeleton(width: 60, height: 22, borderRadius: 6),
                    SizedBox(height: 6),
                    GlassSkeleton(width: 80, height: 12),
                  ]),
                ]),
              )),
              SizedBox(width: 12),
              Expanded(child: GlassSkeletonCard(
                padding: EdgeInsets.all(16),
                child: Row(children: [
                  GlassSkeleton(width: 32, height: 32, borderRadius: 8),
                  SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GlassSkeleton(width: 60, height: 22, borderRadius: 6),
                    SizedBox(height: 6),
                    GlassSkeleton(width: 100, height: 12),
                  ]),
                ]),
              )),
              SizedBox(width: 12),
              Expanded(child: GlassSkeletonCard(
                padding: EdgeInsets.all(16),
                child: Row(children: [
                  GlassSkeleton(width: 32, height: 32, borderRadius: 8),
                  SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    GlassSkeleton(width: 60, height: 22, borderRadius: 6),
                    SizedBox(height: 6),
                    GlassSkeleton(width: 90, height: 12),
                  ]),
                ]),
              )),
            ],
          ),
          const SizedBox(height: 20),
          // Calendar skeleton
          const GlassSkeletonCard(
            padding: EdgeInsets.all(20),
            child: Column(children: [
              GlassSkeleton(width: double.infinity, height: 30),
              SizedBox(height: 12),
              GlassSkeleton(width: double.infinity, height: 200),
            ]),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < 4; i++) ...[
            GlassSkeletonCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: const [
                  GlassSkeleton(width: 48, height: 48, borderRadius: 12),
                  SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassSkeleton(width: 160, height: 16, borderRadius: 6),
                      SizedBox(height: 8),
                      Row(children: [
                        GlassSkeleton(width: 100, height: 20, borderRadius: 6),
                        SizedBox(width: 8),
                        GlassSkeleton(width: 50, height: 20, borderRadius: 6),
                      ]),
                    ],
                  )),
                ],
              ),
            ),
            if (i < 3) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  // --- Loaded Content ---

  Widget _buildLoadedContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(delay: const Duration(milliseconds: 0), child: _buildSummaryCards()),
          const SizedBox(height: 20),
          // Calendar and Active Events side by side
          FadeSlideIn(
            delay: const Duration(milliseconds: 100),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildDateCalendar()),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildMonthlyEventsTable()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(delay: const Duration(milliseconds: 200), child: _buildYearTimeline()),
          const SizedBox(height: 20),
          if (_events.isEmpty) FadeSlideIn(delay: const Duration(milliseconds: 300), child: _buildEmptyState()),
        ],
      ),
    );
  }

  // --- Summary Cards ---

  Widget _buildSummaryCards() {
    final systemCount = _events.where((e) => e['is_system'] == true).length;
    final customCount = _events.length - systemCount;
    return Row(
      children: [
        _buildSummaryCard('Total Events', '${_events.length}', Icons.event_note, const Color(0xFFFFB74D),
            subtitle: '$systemCount system, $customCount custom'),
        const SizedBox(width: 12),
        _buildSummaryCard('Active This Month', '$_activeThisMonthCount', Icons.today, const Color(0xFF66BB6A)),
        const SizedBox(width: 12),
        _buildSummaryCard('Avg Multiplier', _events.isEmpty ? '-' : 'x${_avgMultiplier.toStringAsFixed(2)}', Icons.trending_up, const Color(0xFF42A5F5)),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color, {String? subtitle}) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.15), color.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    if (subtitle != null)
                      Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Date Calendar (proper month calendar with day cells) ---

  Widget _buildDateCalendar() {
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Monday = 1, Sunday = 7
    final startWeekday = firstDay.weekday; // 1 = Mon
    final today = DateTime.now();
    final eventsThisMonth = _eventsForMonth(month);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month navigation
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: Colors.white.withOpacity(0.7)),
                    onPressed: () => setState(() {
                      _calendarMonth = DateTime(year, month - 1);
                    }),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_monthLabels[month - 1]} $year',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7)),
                    onPressed: () => setState(() {
                      _calendarMonth = DateTime(year, month + 1);
                    }),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => setState(() {
                      _calendarMonth = DateTime(today.year, today.month);
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.15)),
                      ),
                      child: const Text('Today', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ),
                  if (eventsThisMonth.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB74D).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${eventsThisMonth.length} event${eventsThisMonth.length > 1 ? 's' : ''} this month',
                        style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Day of week headers
              Row(
                children: _dayLabels.map((d) => Expanded(
                  child: Center(
                    child: Text(d, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),

              // Day grid
              _buildDayGrid(year, month, daysInMonth, startWeekday, today, eventsThisMonth),

              // Active events legend for this month
              if (eventsThisMonth.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: eventsThisMonth.map((evt) {
                      final color = _severityColor(evt['severity']);
                      final dateRange = _eventDateRange(evt, year);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(
                            color: color, borderRadius: BorderRadius.circular(3),
                          )),
                          const SizedBox(width: 6),
                          Text(
                            '${evt['name']}',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          if (dateRange.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '($dateRange)',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                            ),
                          ],
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayGrid(int year, int month, int daysInMonth, int startWeekday, DateTime today, List<Map<String, dynamic>> eventsThisMonth) {
    // Build 6 weeks x 7 days grid
    final totalCells = ((startWeekday - 1) + daysInMonth);
    final rows = ((totalCells + 6) ~/ 7); // ceil division

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - (startWeekday - 1) + 1;

              if (dayNum < 1 || dayNum > daysInMonth) {
                return Expanded(child: SizedBox(height: 40));
              }

              final isToday = today.year == year && today.month == month && today.day == dayNum;
              final isWeekend = col >= 5; // Sat, Sun

              // Check which events cover this entire month (since events are month-based)
              // All events in eventsThisMonth cover every day of this month
              final dayEvents = eventsThisMonth;

              return Expanded(
                child: Tooltip(
                  message: dayEvents.isNotEmpty
                      ? dayEvents.map((e) => '${e['name']} (x${(e['multiplier'] as num?)?.toStringAsFixed(2) ?? '1.00'})').join('\n')
                      : '',
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isToday
                          ? const Color(0xFF1E88E5).withOpacity(0.25)
                          : dayEvents.isNotEmpty
                              ? _blendEventColors(dayEvents).withOpacity(0.12)
                              : Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday
                            ? const Color(0xFF1E88E5).withOpacity(0.6)
                            : dayEvents.isNotEmpty
                                ? _blendEventColors(dayEvents).withOpacity(0.25)
                                : Colors.white.withOpacity(0.04),
                        width: isToday ? 1.5 : 1.0,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            color: isToday
                                ? const Color(0xFF64B5F6)
                                : isWeekend
                                    ? Colors.white.withOpacity(0.4)
                                    : Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (dayEvents.isNotEmpty)
                          Positioned(
                            bottom: 3,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: dayEvents.take(3).map((evt) => Container(
                                width: 4,
                                height: 4,
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  color: _severityColor(evt['severity']),
                                  shape: BoxShape.circle,
                                ),
                              )).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Color _blendEventColors(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return Colors.white;
    // Use the highest severity color
    final severities = {'high': 3, 'medium': 2, 'low': 1};
    events.sort((a, b) => (severities[b['severity']] ?? 0).compareTo(severities[a['severity']] ?? 0));
    return _severityColor(events.first['severity']);
  }

  // --- Year Timeline (shows all 12 months with event ranges) ---

  Widget _buildYearTimeline() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with year selector
              Row(
                children: [
                  Icon(Icons.date_range, color: Colors.white.withOpacity(0.7), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Annual Event Timeline',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: Colors.white.withOpacity(0.5), size: 20),
                    onPressed: () => setState(() => _selectedYear--),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  Text('$_selectedYear', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.5), size: 20),
                    onPressed: () => setState(() => _selectedYear++),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Month labels row
              Row(
                children: List.generate(12, (i) {
                  final isCurrentMonth = DateTime.now().year == _selectedYear && DateTime.now().month == i + 1;
                  return Expanded(
                    child: Center(
                      child: Text(
                        _monthLabels[i],
                        style: TextStyle(
                          color: isCurrentMonth ? const Color(0xFF64B5F6) : Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: isCurrentMonth ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),

              // Event range bars
              if (_events.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No events to display', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
                  ),
                )
              else
                ..._events.map((event) => _buildTimelineBar(event)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineBar(Map<String, dynamic> event) {
    final months = (event['months'] as List?)?.map((m) {
      return (m is int) ? m : (int.tryParse(m.toString()) ?? 1);
    }).toList()?..sort();
    if (months == null || months.isEmpty) return const SizedBox.shrink();

    final color = _severityColor(event['severity']);
    final startMonth = months.first;
    final endMonth = months.last;
    final multiplier = (event['multiplier'] as num?)?.toStringAsFixed(2) ?? '1.00';
    final lastDay = DateTime(_selectedYear, endMonth + 1, 0).day;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event label
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2),
              )),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${event['name']} (x$multiplier)',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_monthLabels[startMonth - 1]} 1 - ${_monthLabels[endMonth - 1]} $lastDay',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Range bar
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final monthWidth = totalWidth / 12;
              final left = (startMonth - 1) * monthWidth;
              final width = (endMonth - startMonth + 1) * monthWidth;
              return SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    // Background track
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // Event bar
                    Positioned(
                      left: left,
                      width: width,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.6), color.withOpacity(0.3)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Monthly Events Table ---

  Widget _buildMonthlyEventsTable() {
    if (_events.isEmpty) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.table_chart, color: Colors.white.withOpacity(0.7), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Active Seasonality Events by Month',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Month tabs - show events for each month
              ...List.generate(12, (i) {
                final monthNum = i + 1;
                final monthEvents = _eventsForMonth(monthNum);
                if (monthEvents.isEmpty) return const SizedBox.shrink();
                final isCurrentMonth = DateTime.now().month == monthNum;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrentMonth
                          ? const Color(0xFF1E88E5).withOpacity(0.08)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentMonth
                            ? const Color(0xFF1E88E5).withOpacity(0.3)
                            : Colors.white.withOpacity(0.06),
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: isCurrentMonth,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: isCurrentMonth
                                ? const Color(0xFF1E88E5).withOpacity(0.2)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              _monthLabels[i],
                              style: TextStyle(
                                color: isCurrentMonth ? const Color(0xFF64B5F6) : Colors.white70,
                                fontSize: 12, fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              _fullMonthLabels[i],
                              style: TextStyle(
                                color: isCurrentMonth ? Colors.white : Colors.white.withOpacity(0.8),
                                fontSize: 14, fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${monthEvents.length} event${monthEvents.length > 1 ? 's' : ''}',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                              ),
                            ),
                            if (isCurrentMonth) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E88E5).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Current', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 10)),
                              ),
                            ],
                          ],
                        ),
                        iconColor: Colors.white38,
                        collapsedIconColor: Colors.white24,
                        children: monthEvents.map((evt) => _buildTableEventRow(evt)).toList(),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableEventRow(Map<String, dynamic> event) {
    final severityColor = _severityColor(event['severity']);
    final multiplier = (event['multiplier'] as num?)?.toStringAsFixed(2) ?? '1.00';
    final isSystem = event['is_system'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: severityColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        event['name'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSystem) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF42A5F5).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('System', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                if ((event['description'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      event['description'],
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildChip('x$multiplier', const Color(0xFF66BB6A)),
                _buildChip(event['category'] ?? '', const Color(0xFF64B5F6)),
                _buildChip(event['severity'] ?? '', severityColor),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            color: const Color(0xFF64B5F6),
            onPressed: () => _showAddEditDialog(event: event),
            tooltip: 'Edit',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            color: const Color(0xFFEF5350),
            onPressed: () => _confirmDelete(event),
            tooltip: 'Delete',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  static const _fullMonthLabels = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // --- Empty State ---

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('No custom events yet', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Add events like annual sales campaigns, company shutdowns, etc.',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add First Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Event Card ---

  Widget _buildEventCard(Map<String, dynamic> event) {
    final months = (event['months'] as List?) ?? [];
    final monthNames = months.map((m) => _monthName(m)).join(', ');
    final multiplier = (event['multiplier'] as num?)?.toStringAsFixed(2) ?? '1.00';
    final severityColor = _severityColor(event['severity']);
    final category = event['category'] ?? 'general';
    final dateRange = _eventDateRange(event, _selectedYear);
    final isSystem = event['is_system'] == true;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.event, color: severityColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          event['name'] ?? 'Unnamed Event',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        if (isSystem) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF42A5F5).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF42A5F5).withOpacity(0.3)),
                            ),
                            child: const Text('System', style: TextStyle(color: Color(0xFF64B5F6), fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildChip(monthNames, Colors.white.withOpacity(0.6)),
                        _buildChip('x$multiplier', const Color(0xFF66BB6A)),
                        _buildChip(category, const Color(0xFF64B5F6)),
                        _buildChip(event['severity'] ?? 'medium', severityColor),
                      ],
                    ),
                    if (dateRange.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.date_range, size: 12, color: Colors.white.withOpacity(0.4)),
                          const SizedBox(width: 4),
                          Text(dateRange, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                        ],
                      ),
                    ],
                    if ((event['description'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event['description'],
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF64B5F6), size: 20),
                    onPressed: () => _showAddEditDialog(event: event),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF5350), size: 20),
                    onPressed: () => _confirmDelete(event),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  void _confirmDelete(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (ctx) => GlassDialog(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delete Event', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
              'Delete "${event['name']}"? This cannot be undone.',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteEvent(event['id'] ?? 0);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF5350)),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(dynamic m) {
    final idx = (m is int) ? m - 1 : (int.tryParse(m.toString()) ?? 1) - 1;
    return (idx >= 0 && idx < 12) ? _monthLabels[idx] : m.toString();
  }

  Color _severityColor(dynamic severity) {
    switch (severity?.toString()) {
      case 'high': return const Color(0xFFEF5350);
      case 'medium': return const Color(0xFFFFB74D);
      default: return const Color(0xFF66BB6A);
    }
  }
}

// --- Add/Edit Event Dialog (Refined UX) ---

class _AddEditEventDialog extends StatefulWidget {
  final Map<String, dynamic>? existingEvent;
  final Function(Map<String, dynamic>) onSave;

  const _AddEditEventDialog({this.existingEvent, required this.onSave});

  @override
  State<_AddEditEventDialog> createState() => _AddEditEventDialogState();
}

class _AddEditEventDialogState extends State<_AddEditEventDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<bool> _selectedMonths = List.filled(12, false);
  double _multiplier = 1.2;
  String _category = 'festive';
  String _severity = 'medium';

  final _categories = [
    {'value': 'festive', 'label': 'Festive', 'icon': Icons.celebration, 'color': const Color(0xFFEF5350)},
    {'value': 'cycle', 'label': 'Business Cycle', 'icon': Icons.loop, 'color': const Color(0xFF42A5F5)},
    {'value': 'national', 'label': 'National', 'icon': Icons.flag, 'color': const Color(0xFF66BB6A)},
    {'value': 'industry', 'label': 'Industry', 'icon': Icons.factory, 'color': const Color(0xFFFFB74D)},
    {'value': 'weather', 'label': 'Weather', 'icon': Icons.cloud, 'color': const Color(0xFF78909C)},
    {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz, 'color': const Color(0xFFAB47BC)},
  ];

  final _monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final _fullMonthLabels = ['January', 'February', 'March', 'April', 'May', 'June',
                            'July', 'August', 'September', 'October', 'November', 'December'];

  @override
  void initState() {
    super.initState();
    final e = widget.existingEvent;
    if (e != null) {
      _nameCtrl.text = e['name'] ?? '';
      _descCtrl.text = e['description'] ?? '';
      _multiplier = (e['multiplier'] as num?)?.toDouble() ?? 1.2;
      _category = e['category'] ?? 'festive';
      _severity = e['severity'] ?? 'medium';
      for (final m in (e['months'] as List? ?? [])) {
        final idx = (m is int) ? m - 1 : (int.tryParse(m.toString()) ?? 1) - 1;
        if (idx >= 0 && idx < 12) _selectedMonths[idx] = true;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  List<int> get _monthNumbers {
    return [for (var i = 0; i < 12; i++) if (_selectedMonths[i]) i + 1];
  }

  String get _selectedRangeText {
    final selected = _monthNumbers;
    if (selected.isEmpty) return 'No months selected';
    if (selected.length == 1) return _fullMonthLabels[selected.first - 1];
    return '${_fullMonthLabels[selected.first - 1]} - ${_fullMonthLabels[selected.last - 1]}';
  }

  Color get _multiplierColor {
    if (_multiplier < 0.9) return const Color(0xFF42A5F5);
    if (_multiplier < 1.1) return Colors.white70;
    if (_multiplier < 1.3) return const Color(0xFF66BB6A);
    if (_multiplier < 1.6) return const Color(0xFFFFB74D);
    return const Color(0xFFEF5350);
  }

  String get _multiplierLabel {
    if (_multiplier < 0.9) return 'Below Average';
    if (_multiplier < 1.1) return 'Normal';
    if (_multiplier < 1.3) return 'Moderate Increase';
    if (_multiplier < 1.6) return 'High Demand';
    return 'Very High Demand';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingEvent != null;
    return GlassDialog(
      width: 560,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dialog header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isEdit ? Icons.edit : Icons.add_circle_outline, color: const Color(0xFF64B5F6), size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                isEdit ? 'Edit Event' : 'Add Custom Event',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Event Name
                  _sectionLabel('Event Name', Icons.label_outline),
                  const SizedBox(height: 8),
                  _glassField(_nameCtrl, 'e.g. Annual Company Bazaar, Factory Shutdown'),
                  const SizedBox(height: 20),

                  // Affected Months (visual month picker)
                  _sectionLabel('Affected Months', Icons.calendar_month),
                  const SizedBox(height: 4),
                  Text(_selectedRangeText, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  const SizedBox(height: 10),
                  _buildMonthPicker(),
                  const SizedBox(height: 20),

                  // Demand Multiplier
                  _sectionLabel('Demand Multiplier', Icons.speed),
                  const SizedBox(height: 8),
                  _buildMultiplierControl(),
                  const SizedBox(height: 20),

                  // Category & Severity side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCategorySelector()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildSeveritySelector()),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Description
                  _sectionLabel('Description', Icons.notes, optional: true),
                  const SizedBox(height: 8),
                  _glassField(_descCtrl, 'What drives this seasonal change?', maxLines: 2),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.6))),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _onSave,
                icon: Icon(isEdit ? Icons.check : Icons.add, size: 18),
                label: Text(isEdit ? 'Update Event' : 'Add Event'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onSave() {
    if (_nameCtrl.text.trim().isEmpty) {
      GlassNotification.show(context, 'Please enter an event name', isError: true);
      return;
    }
    if (_monthNumbers.isEmpty) {
      GlassNotification.show(context, 'Please select at least one month', isError: true);
      return;
    }
    Navigator.pop(context);
    widget.onSave({
      if (widget.existingEvent?['id'] != null) 'id': widget.existingEvent!['id'],
      'name': _nameCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'months': _monthNumbers,
      'multiplier': _multiplier,
      'category': _category,
      'severity': _severity,
    });
  }

  Widget _buildMonthPicker() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: List.generate(12, (i) {
          final selected = _selectedMonths[i];
          final isCurrentMonth = DateTime.now().month == i + 1;
          // Check if neighbors are also selected for visual continuity
          final leftSelected = i > 0 && _selectedMonths[i - 1];
          final rightSelected = i < 11 && _selectedMonths[i + 1];

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMonths[i] = !_selectedMonths[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                margin: EdgeInsets.only(
                  left: selected && leftSelected ? 0 : 2,
                  right: selected && rightSelected ? 0 : 2,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1E88E5).withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(selected && leftSelected ? 0 : 8),
                    right: Radius.circular(selected && rightSelected ? 0 : 8),
                  ),
                  border: selected ? null : Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(
                  children: [
                    Text(
                      _monthLabels[i],
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : isCurrentMonth
                                ? const Color(0xFF64B5F6)
                                : Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: selected || isCurrentMonth ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (isCurrentMonth && !selected)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        width: 4, height: 4,
                        decoration: const BoxDecoration(color: Color(0xFF1E88E5), shape: BoxShape.circle),
                      ),
                    if (selected)
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        child: const Icon(Icons.check, color: Colors.white, size: 12),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMultiplierControl() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'x${_multiplier.toStringAsFixed(2)}',
                style: TextStyle(color: _multiplierColor, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _multiplierColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_multiplierLabel, style: TextStyle(color: _multiplierColor, fontSize: 11)),
              ),
              const Spacer(),
              Text('0.5x', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
              const SizedBox(width: 4),
              SizedBox(
                width: 200,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: _multiplier,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    activeColor: _multiplierColor,
                    inactiveColor: Colors.white.withOpacity(0.1),
                    onChanged: (v) => setState(() => _multiplier = v),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('3.0x', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Category', Icons.category),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _categories.map((cat) {
            final isSelected = _category == cat['value'];
            final color = cat['color'] as Color;
            return GestureDetector(
              onTap: () => setState(() => _category = cat['value'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? color.withOpacity(0.5) : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat['icon'] as IconData, size: 14,
                      color: isSelected ? color : Colors.white.withOpacity(0.4)),
                    const SizedBox(width: 4),
                    Text(cat['label'] as String, style: TextStyle(
                      color: isSelected ? color : Colors.white.withOpacity(0.5),
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSeveritySelector() {
    final severities = [
      {'value': 'low', 'label': 'Low Impact', 'color': const Color(0xFF66BB6A)},
      {'value': 'medium', 'label': 'Medium Impact', 'color': const Color(0xFFFFB74D)},
      {'value': 'high', 'label': 'High Impact', 'color': const Color(0xFFEF5350)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Impact Level', Icons.signal_cellular_alt),
        const SizedBox(height: 8),
        ...severities.map((sev) {
          final isSelected = _severity == sev['value'];
          final color = sev['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => setState(() => _severity = sev['value'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? color.withOpacity(0.5) : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: isSelected ? color : Colors.transparent,
                        border: Border.all(color: isSelected ? color : Colors.white.withOpacity(0.3), width: 1.5),
                        shape: BoxShape.circle,
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 8, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 8),
                    Text(sev['label'] as String, style: TextStyle(
                      color: isSelected ? color : Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    )),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _sectionLabel(String text, IconData icon, {bool optional = false}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.5)),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w600)),
        if (optional) ...[
          const SizedBox(width: 6),
          Text('(optional)', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
        ],
      ],
    );
  }

  Widget _glassField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
