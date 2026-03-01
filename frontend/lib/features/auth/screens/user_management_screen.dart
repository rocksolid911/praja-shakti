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

  _ManagedUser({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.ward,
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
      final users = (resp.data as List)
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

  Future<bool> updateRole(int userId, String newRole) async {
    try {
      await _api.patch('/auth/users/$userId/', data: {'role': newRole});
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

class _UMView extends StatelessWidget {
  const _UMView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User Management', style: TextStyle(fontSize: 16)),
            Text('Manage village members & roles', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(state.msg, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.read<_UMCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is _UMLoaded) return _buildList(context, state.users);
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddUserSheet(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add User'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildList(BuildContext context, List<_ManagedUser> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No users yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Tap + Add User to register village members',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    // Group by role
    final leaders = users.where((u) => u.role == 'leader').toList();
    final citizens = users.where((u) => u.role == 'citizen').toList();
    final others = users.where((u) => u.role != 'leader' && u.role != 'citizen').toList();

    return RefreshIndicator(
      onRefresh: () => context.read<_UMCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (leaders.isNotEmpty) ...[
            _SectionLabel('Leaders', leaders.length, Colors.indigo),
            ...leaders.map((u) => _UserTile(user: u, onEdit: () => _showEditRoleSheet(context, u))),
            const SizedBox(height: 12),
          ],
          if (citizens.isNotEmpty) ...[
            _SectionLabel('Citizens', citizens.length, Colors.teal),
            ...citizens.map((u) => _UserTile(user: u, onEdit: () => _showEditRoleSheet(context, u))),
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
            builder: (ctx, setState) => Container(
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
                  const Text('Add New User',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                          onChanged: (v) => setState(() => selectedRole = v ?? 'citizen'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: selectedWard,
                          decoration: const InputDecoration(
                            labelText: 'Ward',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('—')),
                            ...List.generate(10, (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text('Ward ${i + 1}'),
                            )),
                          ],
                          onChanged: (v) => setState(() => selectedWard = v),
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

  void _showEditRoleSheet(BuildContext context, _ManagedUser user) {
    final cubit = context.read<_UMCubit>();
    String selectedRole = user.role;

    // Prevent editing yourself
    final currentUser = context.read<AuthCubit>().currentUser;
    if (currentUser?.id == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot change your own role.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => BlocProvider.value(
        value: cubit,
        child: StatefulBuilder(
          builder: (ctx, setState) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
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
                    CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                        style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(user.phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Change Role', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: ['citizen', 'leader'].map((role) {
                    final selected = selectedRole == role;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(role == 'citizen' ? 'Citizen' : 'Leader'),
                          selected: selected,
                          onSelected: (_) => setState(() => selectedRole = role),
                          selectedColor: Colors.indigo.shade100,
                          labelStyle: TextStyle(
                            color: selected ? Colors.indigo.shade800 : Colors.grey.shade700,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: selectedRole == user.role
                        ? null
                        : () async {
                            Navigator.pop(sheetCtx);
                            await cubit.updateRole(user.id, selectedRole);
                          },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Role'),
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
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

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
    final roleColor = user.role == 'leader'
        ? Colors.indigo
        : user.role == 'government'
            ? Colors.deepPurple
            : Colors.teal;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
            style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          user.phone + (user.ward != null ? ' · Ward ${user.ward}' : ''),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade400),
            ],
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
