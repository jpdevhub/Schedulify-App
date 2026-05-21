import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../models/models.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';

class UsersTab extends ConsumerStatefulWidget {
  final String role; // 'faculty' or 'student'
  const UsersTab({super.key, required this.role});

  @override
  ConsumerState<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<UsersTab> {
  List<Profile> _users = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await DbService.getAllUsers();
      setState(() {
        _users = all.where((u) => u.role == widget.role).toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  void _showCreateForm() {
    final email = TextEditingController();
    final password = TextEditingController();
    final first = TextEditingController();
    final last = TextEditingController();
    final dept = TextEditingController();
    final empId = TextEditingController();
    final rollNo = TextEditingController();
    final batch = TextEditingController();
    final sem = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Create ${widget.role == 'faculty' ? 'Faculty' : 'Student'}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          AppTextField(controller: email, label: 'Email', keyboardType: TextInputType.emailAddress, prefixIcon: Icons.email_outlined),
          const SizedBox(height: 14),
          AppTextField(controller: password, label: 'Password', obscureText: true, prefixIcon: Icons.lock_outline),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: AppTextField(controller: first, label: 'First Name', prefixIcon: Icons.person_outline)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(controller: last, label: 'Last Name', prefixIcon: Icons.person_outline)),
          ]),
          const SizedBox(height: 14),
          AppTextField(controller: dept, label: 'Department', prefixIcon: Icons.business_rounded),
          if (widget.role == 'faculty') ...[
            const SizedBox(height: 14),
            AppTextField(controller: empId, label: 'Employee ID', prefixIcon: Icons.badge_outlined),
          ] else ...[
            const SizedBox(height: 14),
            AppTextField(controller: rollNo, label: 'Roll Number', prefixIcon: Icons.numbers_rounded),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: AppTextField(controller: batch, label: 'Batch', hint: '2024-28')),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(controller: sem, label: 'Semester', hint: '3rd Sem')),
            ]),
          ],
          const SizedBox(height: 20),
          PrimaryButton(label: 'Create User', width: double.infinity, onPressed: () async {
            final profileData = {
              'role': widget.role,
              'first_name': first.text.trim(),
              'last_name': last.text.trim(),
              'department': dept.text.isEmpty ? null : dept.text.trim(),
              if (widget.role == 'faculty') 'employee_id': empId.text.isEmpty ? null : empId.text.trim(),
              if (widget.role == 'student') ...{
                'roll_number': rollNo.text.isEmpty ? null : rollNo.text.trim(),
                'batch': batch.text.isEmpty ? null : batch.text.trim(),
                'semester': sem.text.isEmpty ? null : sem.text.trim(),
              },
            };
            final err = await ref.read(authProvider.notifier).createUser(
                email: email.text.trim(),
                password: password.text,
                profileData: profileData);
            if (!mounted) return;
            if (err != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
            } else {
              Navigator.pop(context);
              _load();
            }
          }),
        ])),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.role == 'faculty' ? 'Faculty' : 'Students';
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
          onPressed: _showCreateForm, backgroundColor: AppColors.primary,
          child: const Icon(Icons.person_add_rounded)),
      body: RefreshIndicator(
        onRefresh: _load, color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PageHeader(title: title, subtitle: '${_users.length} ${title.toLowerCase()}'),
            const SizedBox(height: 20),
            if (_loading)
              ...List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 10),
                  child: ShimmerBox(height: 72, radius: 14)))
            else if (_users.isEmpty)
              EmptyState(icon: Icons.people_rounded,
                  title: 'No $title yet', subtitle: 'Tap + to add')
            else
              ..._users.map((u) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: widget.role == 'faculty'
                          ? AppColors.faculty.withOpacity(0.2)
                          : AppColors.student.withOpacity(0.2),
                      child: Text(u.firstName[0] + u.lastName[0],
                          style: TextStyle(
                              color: widget.role == 'faculty' ? AppColors.faculty : AppColors.student,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                      Text(u.department ?? (widget.role == 'faculty'
                          ? (u.employeeId ?? '') : (u.rollNumber ?? '')),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                    Switch(
                      value: u.isActive, activeColor: AppColors.success,
                      onChanged: (v) async {
                        await DbService.toggleUserActive(u.id, v);
                        _load();
                      },
                    ),
                  ]),
                ),
              )),
          ],
        ),
      ),
    );
  }
}
