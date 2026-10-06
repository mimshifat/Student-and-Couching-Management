import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        final profile = profileProvider.profile;
        final instituteName = profile?.instituteName ?? 'Coaching Management';
        final ownerName = profile?.ownerName ?? 'Admin';

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.school, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      instituteName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ownerName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Exams'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/exams');
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text('Result Analytics'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/result-analytics');
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Routine'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/routine');
            },
          ),
          ListTile(
            leading: const Icon(Icons.notes),
            title: const Text('My Notes'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushNamed(context, '/notes');
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backup Settings'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.pushNamed(context, '/backup');
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded),
            title: const Text('Annual Report'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/annual-report');
            },
          ),
          ListTile(
            leading: const Icon(Icons.domain),
            title: const Text('Institute Profile'),
            onTap: () {
              Navigator.pop(context);
              // Instead of creating a new Edit screen, we can reuse ProfileSetupScreen
              // by passing some context or it will just prefill its fields if we read from provider
              // Actually, I'll create an Edit profile screen or just navigate to ProfileSetupScreen 
              // Wait, ProfileSetupScreen has PopScope(canPop:false), which would prevent back button if reused directly!
              // I should navigate to a dedicated Edit screen, or just create it here inline.
              Navigator.push(context, MaterialPageRoute(builder: (_) => const _EditProfileScreen()));
            },
          ),
        ],
      ),
    );
      },
    );
  }
}

class _EditProfileScreen extends StatefulWidget {
  const _EditProfileScreen();

  @override
  State<_EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<_EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _instituteNameController = TextEditingController();
  final _instituteShortNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    if (profile != null) {
      _instituteNameController.text = profile.instituteName;
      _instituteShortNameController.text = profile.instituteShortName ?? '';
      _ownerNameController.text = profile.ownerName;
      _phoneController.text = profile.phone ?? '';
      _addressController.text = profile.address ?? '';
    }
  }

  @override
  void dispose() {
    _instituteNameController.dispose();
    _instituteShortNameController.dispose();
    _ownerNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    
    final profileProvider = context.read<ProfileProvider>();
    final existing = profileProvider.profile;
    
    // We import from domain/entities, but wait we need to use InstituteProfile which is in profile feature.
    // I will use ProfileSetupScreen structure but allow popping.
    
    try {
      // Create new profile with updated info
      // wait, InstituteProfile needs to be imported
      
      final updatedProfile = existing!.copyWith(
        instituteName: _instituteNameController.text.trim(),
        instituteShortName: _instituteShortNameController.text.trim().isEmpty ? null : _instituteShortNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await profileProvider.saveProfile(updatedProfile);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _instituteNameController,
                decoration: const InputDecoration(labelText: 'Institute Name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _instituteShortNameController,
                decoration: const InputDecoration(labelText: 'Short Name (Optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ownerNameController,
                decoration: const InputDecoration(labelText: 'Owner Name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone (Optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address (Optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving ? const CircularProgressIndicator() : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
