import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../models/models.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';

class TimetablesTab extends ConsumerStatefulWidget {
  const TimetablesTab({super.key});
  @override
  ConsumerState<TimetablesTab> createState() => _TimetablesTabState();
}

class _TimetablesTabState extends ConsumerState<TimetablesTab> {
  List<Timetable> _items = [];
  List<Department> _depts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await Future.wait([DbService.getTimetables(), DbService.getDepartments()]);
      setState(() {
        _items = r[0] as List<Timetable>;
        _depts = r[1] as List<Department>;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  void _showForm({Timetable? tt}) {
    final name = TextEditingController(text: tt?.name);
    final year = TextEditingController(text: tt?.academicYear ?? '2025-26');
    final sem = TextEditingController(text: tt?.semester);
    String? deptId = tt?.departmentId;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tt == null ? 'New Timetable' : 'Edit Timetable',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          AppTextField(controller: name, label: 'Timetable Name',
              hint: 'CSE Sem 3 2025', prefixIcon: Icons.calendar_month_rounded),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: AppTextField(controller: year, label: 'Academic Year', hint: '2025-26')),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(controller: sem, label: 'Semester', hint: '3rd')),
          ]),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: deptId, dropdownColor: AppColors.bgCard,
            decoration: InputDecoration(labelText: 'Department',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                filled: true, fillColor: AppColors.glass),
            style: const TextStyle(color: AppColors.textPrimary),
            items: _depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
            onChanged: (v) => setSt(() => deptId = v),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: tt == null ? 'Create' : 'Update', width: double.infinity,
              onPressed: () async {
                final user = ref.read(currentUserProvider);
                final data = {
                  'name': name.text.trim(),
                  'academic_year': year.text.trim(),
                  'semester': sem.text.trim(),
                  'department_id': deptId,
                  'generated_by': user?.id,
                };
                try {
                  if (tt == null) await DbService.createTimetable(data);
                  else await DbService.updateTimetable(tt.id, data);
                  if (mounted) { Navigator.pop(context); _load(); }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }),
        ]),
      )),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'published' => AppColors.success,
    'archived' => AppColors.textMuted,
    _ => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
          onPressed: () => _showForm(), backgroundColor: AppColors.primary,
          child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load, color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PageHeader(title: 'Timetables', subtitle: '${_items.length} timetables'),
            const SizedBox(height: 20),
            if (_loading)
              ...List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 12),
                  child: ShimmerBox(height: 110, radius: 16)))
            else if (_items.isEmpty)
              EmptyState(icon: Icons.calendar_month_rounded,
                  title: 'No timetables', subtitle: 'Tap + to create one')
            else
              ..._items.map((tt) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tt.name, style: const TextStyle(fontWeight: FontWeight.w700,
                            fontSize: 16, color: AppColors.textPrimary)),
                        Text('${tt.academicYear} · ${tt.semester}',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        if (tt.department != null)
                          Text(tt.department!.name,
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusColor(tt.status).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(tt.status.toUpperCase(),
                            style: TextStyle(color: _statusColor(tt.status),
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      if (tt.status == 'draft')
                        _ActionBtn('Publish', Icons.publish_rounded, AppColors.success,
                            () async { await DbService.publishTimetable(tt.id); _load(); }),
                      if (tt.status == 'published')
                        _ActionBtn('Archive', Icons.archive_rounded, AppColors.warning,
                            () async { await DbService.archiveTimetable(tt.id); _load(); }),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 20),
                          onPressed: () => _showForm(tt: tt)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                          onPressed: () async { await DbService.deleteTimetable(tt.id); _load(); }),
                    ]),
                  ]),
                ),
              )),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}
