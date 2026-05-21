import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/db_service.dart';
import '../../../shared/widgets/widgets.dart';

class ClassroomsTab extends StatefulWidget {
  const ClassroomsTab({super.key});
  @override
  State<ClassroomsTab> createState() => _ClassroomsTabState();
}

class _ClassroomsTabState extends State<ClassroomsTab> {
  List<Classroom> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await DbService.getClassrooms();
      setState(() { _items = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _showForm({Classroom? room}) {
    final name = TextEditingController(text: room?.name);
    final cap = TextEditingController(text: room?.capacity?.toString());
    final bldg = TextEditingController(text: room?.building);
    String roomType = room?.roomType ?? 'lecture';

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(room == null ? 'Add Classroom' : 'Edit Classroom',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 20),
          AppTextField(controller: name, label: 'Room Name', hint: 'LH-101', prefixIcon: Icons.room_rounded),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: AppTextField(controller: cap, label: 'Capacity',
                keyboardType: TextInputType.number, prefixIcon: Icons.people_outline)),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(controller: bldg, label: 'Building', prefixIcon: Icons.apartment_rounded)),
          ]),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: roomType, dropdownColor: AppColors.bgCard,
            decoration: InputDecoration(labelText: 'Room Type',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                filled: true, fillColor: AppColors.glass),
            style: const TextStyle(color: AppColors.textPrimary),
            items: ['lecture', 'lab', 'seminar', 'auditorium'].map((t) =>
                DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
            onChanged: (v) => setSt(() => roomType = v!),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: room == null ? 'Create' : 'Update', width: double.infinity,
              onPressed: () async {
                final data = {
                  'name': name.text.trim(), 'room_type': roomType,
                  if (cap.text.isNotEmpty) 'capacity': int.tryParse(cap.text),
                  if (bldg.text.isNotEmpty) 'building': bldg.text.trim(),
                };
                try {
                  if (room == null) await DbService.createClassroom(data);
                  else await DbService.updateClassroom(room.id, data);
                  if (mounted) { Navigator.pop(context); _load(); }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
          onPressed: () => _showForm(), backgroundColor: AppColors.primary,
          child: const Icon(Icons.add)),
      body: RefreshIndicator(
        onRefresh: _load, color: AppColors.primary,
        child: GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.3),
          itemCount: _loading ? 6 : _items.length,
          itemBuilder: (_, i) {
            if (_loading) return ShimmerBox(height: 100, radius: 16);
            final room = _items[i];
            return GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (room.isAvailable ? AppColors.success : AppColors.danger).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.room_rounded,
                        color: room.isAvailable ? AppColors.success : AppColors.danger, size: 18),
                  ),
                  const Spacer(),
                  Switch(
                    value: room.isAvailable, activeColor: AppColors.success,
                    onChanged: (v) async {
                      await DbService.updateClassroom(room.id, {'is_available': v});
                      _load();
                    },
                  ),
                ]),
                const SizedBox(height: 8),
                Text(room.name, style: const TextStyle(fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary, fontSize: 15)),
                Text('${room.roomType.toUpperCase()}${room.capacity != null ? ' · ${room.capacity}' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                if (room.building != null)
                  Text(room.building!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const Spacer(),
                Row(children: [
                  GestureDetector(onTap: () => _showForm(room: room),
                      child: const Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 18)),
                  const SizedBox(width: 12),
                  GestureDetector(onTap: () async { await DbService.deleteClassroom(room.id); _load(); },
                      child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18)),
                ]),
              ]),
            );
          },
        ),
      ),
    );
  }
}
