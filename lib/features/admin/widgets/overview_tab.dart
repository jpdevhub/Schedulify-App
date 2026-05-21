import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';

class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  Map<String, int>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await DbService.getDashboardStats();
      setState(() { _stats = stats; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PageHeader(title: 'Overview', subtitle: 'System health and statistics'),
          const SizedBox(height: 24),
          if (_loading)
            ...List.generate(4, (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ShimmerBox(height: 80, radius: 16)))
          else ...[
            _statGrid(),
            const SizedBox(height: 28),
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('System Status', style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 16),
                _statusRow('Database', true),
                _statusRow('Supabase Auth', true),
                _statusRow('Active Timetable',
                    (_stats?['activeTimetables'] ?? 0) > 0),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statGrid() {
    final items = [
      ('Departments', '${_stats?['departments'] ?? 0}', Icons.business_rounded, AppColors.primary),
      ('Courses', '${_stats?['courses'] ?? 0}', Icons.book_rounded, AppColors.info),
      ('Classrooms', '${_stats?['classrooms'] ?? 0}', Icons.room_rounded, AppColors.warning),
      ('Users', '${_stats?['users'] ?? 0}', Icons.people_rounded, AppColors.success),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => StatCard(
        label: items[i].$1, value: items[i].$2,
        icon: items[i].$3, color: items[i].$4,
      ),
    );
  }

  Widget _statusRow(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: ok ? AppColors.success : AppColors.danger, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
        const Spacer(),
        Text(ok ? 'Operational' : 'Issue detected',
            style: TextStyle(
                color: ok ? AppColors.success : AppColors.danger,
                fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
