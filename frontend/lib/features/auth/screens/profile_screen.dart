import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../../../core/models/user.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/language_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AuthCubit>().loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.navMap,
          onPressed: () => context.canPop() ? context.pop() : context.go('/map'),
        ),
        title: Text(l10n.profile),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<AuthCubit>().logout();
              if (context.mounted) context.go('/login');
            },
            child: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          if (state is AuthLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          User? user;
          if (state is AuthAuthenticated) user = state.user;
          if (state is AuthProfileLoaded) user = state.user;
          if (user == null) return Center(child: Text(l10n.profileNotFound));

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : user.phone[0],
                    style: TextStyle(fontSize: 36, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(user.fullName.isNotEmpty ? user.fullName : user.phone,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isLeader ? Colors.blue.shade100 : Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user.isLeader ? l10n.leader.toUpperCase() : l10n.citizen.toUpperCase(),
                    style: TextStyle(
                      color: user.isLeader ? Colors.blue.shade800 : Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _infoTile(l10n.phone, user.phone, Icons.phone),
              _infoTile(l10n.panchayat, user.panchayatName ?? l10n.notSet, Icons.location_city),
              _infoTile(l10n.ward, user.ward?.toString() ?? l10n.notSet, Icons.map),
              // Language picker replaces the static language tile
              const LanguagePickerButton(),
              const SizedBox(height: 32),
              if (user.isLeader)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/dashboard'),
                    icon: const Icon(Icons.dashboard),
                    label: Text(l10n.openLeaderDashboard),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Colors.green.shade700),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }
}
