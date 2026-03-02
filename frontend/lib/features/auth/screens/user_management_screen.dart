import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../auth/cubit/auth_cubit.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _ManagedUser {
  final int id;
  final String phone;
  final String firstName;
  final String lastName;
  final String role;
  final int? ward;
  final bool isActive;

  _ManagedUser({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.ward,
    this.isActive = true,
  });

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isNotEmpty ? full : phone;
  }

  factory _ManagedUser.fromJson(Map<String, dynamic> j) => _ManagedUser(
        id: j['id'],
        phone: j['phone'] ?? '',
        firstName: j['first_name'] ?? '',
        lastName: j['last_name'] ?? '',
        role: j['role'] ?? 'citizen',
        ward: j['ward'],
        isActive: j['is_active'] ?? true,
      );
}

// ── State ─────────────────────────────────────────────────────────────────────

abstract class _UMState {}

class _UMLoading extends _UMState {}

class _UMError extends _UMState {
  final String msg;
  _UMError(this.msg);
}

class _UMLoaded extends _UMState {
  final List<_ManagedUser> users;
  _UMLoaded(this.users);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class _UMCubit extends Cubit<_UMState> {
  final ApiClient _api;
  _UMCubit(this._api) : super(_UMLoading());

  Future<void> load() async {
    emit(_UMLoading());
    try {
      final resp = await _api.get('/auth/users/');
      final raw = resp.data;
      final list = raw is List ? raw : (raw is Map ? (raw['results'] ?? []) : []) as List;
      final users = list
          .map((u) => _ManagedUser.fromJson(u as Map<String, dynamic>))
          .toList();
      emit(_UMLoaded(users));
    } catch (e) {
      emit(_UMError(_extractError(e)));
    }
  }

  Future<bool> createUser({
    required String phone,
    required String firstName,
    required String lastName,
    required String role,
    int? ward,
  }) async {
    try {
      await _api.post('/auth/users/', data: {
        'phone': phone,
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        if (ward != null) 'ward': ward,
      });
      await load();
      return true;
    } catch (e) {
      final current = state;
      emit(_UMError(_extractError(e)));
      await Future.delayed(const Duration(seconds: 2));
      emit(current);
      return false;
    }
  }

  Future<bool> updateUser(int userId, {String? role, int? ward}) async {
    try {
      await _api.patch('/auth/users/$userId/', data: {
        if (role != null) 'role': role,
        if (ward != null) 'ward': ward,
      });
      await load();
      return true;
    } catch (e) {
      final current = state;
      emit(_UMError(_extractError(e)));
      await Future.delayed(const Duration(seconds: 2));
      emit(current);
      return false;
    }
  }

  Future<bool> setUserActive(int userId, {required bool active}) async {
    try {
      if (active) {
        // Reactivate via PATCH
        await _api.patch('/auth/users/$userId/', data: {'is_active': true});
      } else {
        // Deactivate via DELETE (soft delete on backend)
        await _api.delete('/auth/users/$userId/');
      }
      await load();
      return true;
    } catch (e) {
      final current = state;
      emit(_UMError(_extractError(e)));
      await Future.delayed(const Duration(seconds: 2));
      emit(current);
      return false;
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException && e.response != null) {
      final d = e.response!.data;
      if (d is Map) return d.values.first?.toString() ?? 'Error';
      return 'Server error ${e.response!.statusCode}';
    }
    return 'Something went wrong';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => _UMCubit(context.read<ApiClient>())..load(),
      child: const _UMView(),
    );
  }
}

class _UMView extends StatefulWidget {
  const _UMView();

  @override
  State<_UMView> createState() => _UMViewState();
}

class _UMViewState extends State<_UMView> {
  bool _showInactive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Citizen Management', style: TextStyle(fontSize: 16)),
            Text('Manage village members & roles', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          // Toggle to show/hide inactive accounts
          IconButton(
            tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            icon: Icon(_showInactive ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showInactive = !_showInactive),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<_UMCubit>().load(),
          ),
        ],
      ),
      body: BlocBuilder<_UMCubit, _UMState>(
        builder: (context, state) {
          if (state is _UMLoading) return const Center(child: CircularProgressIndicator());
          if (state is _UMError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(state.msg, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => context.read<_UMCubit>().load(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (state is _UMLoaded) {
            return _buildList(context, state.users);
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserSheet(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Citizen'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildList(BuildContext context, List<_ManagedUser> allUsers) {
    final visible = _showInactive ? allUsers : allUsers.where((u) => u.isActive).toList();

    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _showInactive ? 'No users found' : 'No active users',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _showInactive
                  ? 'Tap + Add Citizen to register village members'
                  : 'Tap the eye icon to show inactive accounts',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Summary bar
    final totalActive = allUsers.where((u) => u.isActive).length;
    final totalInactive = allUsers.where((u) => !u.isActive).length;
    final leaders = visible.where((u) => u.role == 'leader').toList();
    final citizens = visible.where((u) => u.role == 'citizen').toList();
    final others = visible.where((u) => u.role != 'leader' && u.role != 'citizen').toList();

    return RefreshIndicator(
      onRefresh: () => context.read<_UMCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Row(
              children: [
                _StatChip(label: 'Active', count: totalActive, color: Colors.green.shade700),
                const SizedBox(width: 12),
                _StatChip(label: 'Inactive', count: totalInactive, color: Colors.grey),
                const SizedBox(width: 12),
                _StatChip(label: 'Leaders', count: leaders.length, color: Colors.indigo.shade700),
                const Spacer(),
                if (!_showInactive && totalInactive > 0)
                  GestureDetector(
                    onTap: () => setState(() => _showInactive = true),
                    child: Text(
                      'Show $totalInactive inactive',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, decoration: TextDecoration.underline),
                    ),
                  ),
              ],
            ),
          ),

          if (leaders.isNotEmpty) ...[
            _SectionLabel('Leaders', leaders.length, Colors.indigo),
            ...leaders.map((u) => _UserTile(
                  user: u,
                  onEdit: () => _showEditSheet(context, u),
                )),
            const SizedBox(height: 12),
          ],
          if (citizens.isNotEmpty) ...[
            _SectionLabel('Citizens', citizens.length, Colors.teal),
            ...citizens.map((u) => _UserTile(
                  user: u,
                  onEdit: () => _showEditSheet(context, u),
                )),
            const SizedBox(height: 12),
          ],
          if (others.isNotEmpty) ...[
            _SectionLabel('Other', others.length, Colors.grey),
            ...others.map((u) => _UserTile(user: u, onEdit: null)),
          ],
        ],
      ),
    );
  }

  void _showAddUserSheet(BuildContext context) {
    final cubit = context.read<_UMCubit>();
    final phoneCtrl = TextEditingController();
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    String selectedRole = 'citizen';
    int? selectedWard;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => BlocProvider.value(
        value: cubit,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.person_add, color: Colors.indigo.shade700),
                      const SizedBox(width: 10),
                      const Text('Add New Citizen',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      hintText: '+919876543210',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: lastCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'citizen', child: Text('Citizen')),
                            DropdownMenuItem(value: 'leader', child: Text('Leader')),
                          ],
                          onChanged: (v) => setSheetState(() => selectedRole = v ?? 'citizen'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: selectedWard,
                          decoration: const InputDecoration(
                            labelText: 'Ward (optional)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('—')),
                            ...List.generate(15, (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('Ward ${i + 1}'),
                            )),
                          ],
                          onChanged: (v) => setSheetState(() => selectedWard = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (phoneCtrl.text.trim().isEmpty) return;
                        Navigator.pop(sheetCtx);
                        await cubit.createUser(
                          phone: phoneCtrl.text.trim(),
                          firstName: firstCtrl.text.trim(),
                          lastName: lastCtrl.text.trim(),
                          role: selectedRole,
                          ward: selectedWard,
                        );
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Create User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, _ManagedUser user) {
    // Prevent editing yourself
    final currentUser = context.read<AuthCubit>().currentUser;
    if (currentUser?.id == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot modify your own account here.')),
      );
      return;
    }

    final cubit = context.read<_UMCubit>();
    String selectedRole = user.role;
    int? selectedWard = user.ward;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => BlocProvider.value(
        value: cubit,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // User identity header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: user.isActive
                            ? Colors.indigo.shade100
                            : Colors.grey.shade200,
                        child: Text(
                          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: user.isActive ? Colors.indigo.shade700 : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(user.phone,
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (!user.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text('INACTIVE',
                              style: TextStyle(color: Colors.red.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Role picker
                  const Text('Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: ['citizen', 'leader'].map((role) {
                      final selected = selectedRole == role;
                      final color = role == 'leader' ? Colors.indigo : Colors.teal;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(role == 'citizen' ? 'Citizen' : 'Leader'),
                            selected: selected,
                            onSelected: user.isActive
                                ? (_) => setSheetState(() => selectedRole = role)
                                : null,
                            selectedColor: color.withOpacity(0.15),
                            labelStyle: TextStyle(
                              color: selected ? color : Colors.grey.shade600,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Ward picker
                  const Text('Ward Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    value: selectedWard,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      hintText: 'No ward assigned',
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— No ward —')),
                      ...List.generate(15, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('Ward ${i + 1}'),
                      )),
                    ],
                    onChanged: user.isActive
                        ? (v) => setSheetState(() => selectedWard = v)
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // Save changes button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: !user.isActive || (selectedRole == user.role && selectedWard == user.ward)
                          ? null
                          : () async {
                              Navigator.pop(sheetCtx);
                              await cubit.updateUser(
                                user.id,
                                role: selectedRole != user.role ? selectedRole : null,
                                ward: selectedWard != user.ward ? (selectedWard ?? -1) : null,
                              );
                            },
                      icon: const Icon(Icons.save),
                      label: const Text('Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Deactivate / Reactivate button
                  SizedBox(
                    width: double.infinity,
                    child: user.isActive
                        ? OutlinedButton.icon(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: ctx,
                                builder: (d) => AlertDialog(
                                  title: const Text('Deactivate Account'),
                                  content: Text(
                                    'Deactivate ${user.displayName}? They will no longer be able to log in.',
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(d, true),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('Deactivate', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                if (ctx.mounted) Navigator.pop(sheetCtx);
                                await cubit.setUserActive(user.id, active: false);
                              }
                            },
                            icon: const Icon(Icons.block, color: Colors.red),
                            label: const Text('Deactivate Account',
                                style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(sheetCtx);
                              await cubit.setUserActive(user.id, active: true);
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Reactivate Account'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionLabel(this.title, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final _ManagedUser user;
  final VoidCallback? onEdit;
  const _UserTile({required this.user, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isInactive = !user.isActive;
    final roleColor = isInactive
        ? Colors.grey
        : user.role == 'leader'
            ? Colors.indigo
            : user.role == 'government'
                ? Colors.deepPurple
                : Colors.teal;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isInactive ? Colors.grey.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
            style: TextStyle(
              color: roleColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user.displayName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isInactive ? Colors.grey : null,
          ),
        ),
        subtitle: Text(
          user.phone + (user.ward != null ? ' · Ward ${user.ward}' : ''),
          style: TextStyle(
            color: isInactive ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isInactive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'INACTIVE',
                  style: TextStyle(color: Colors.red.shade600, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user.role.toUpperCase(),
                  style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            if (onEdit != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.edit_outlined,
                size: 18,
                color: isInactive ? Colors.grey.shade300 : Colors.grey.shade400,
              ),
            ],
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
