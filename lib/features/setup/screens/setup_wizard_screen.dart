import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/vendor_registry.dart';
import '../../../services/supabase_client.dart';
import '../../../config/config_store.dart';
import '../../../shared/widgets/widgets.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int _step = 0;
  bool _isLoading = false;
  String? _error;
  String? _generatedCollegeId;

  // Step field controllers
  final _accessCode = TextEditingController();
  final _collegeName = TextEditingController();
  final _contactEmail = TextEditingController();
  final _supabaseUrl = TextEditingController();
  final _anonKey = TextEditingController();
  bool _connectionTested = false;

  final _steps = ['Access Code', 'College Info', 'Supabase Config', 'Registration', 'Done'];

  void _nextStep() => setState(() { _step++; _error = null; });
  void _setError(String e) => setState(() { _error = e; _isLoading = false; });

  Future<void> _verifyAccessCode() async {
    final valid = VendorRegistry.instance.verifyAccessCode(_accessCode.text.trim());
    if (!valid) { _setError('Invalid access code.'); return; }
    _nextStep();
  }

  Future<void> _testConnection() async {
    if (_supabaseUrl.text.isEmpty || _anonKey.text.isEmpty) {
      _setError('Fill in both fields.'); return;
    }
    setState(() { _isLoading = true; _error = null; });
    final ok = await SupabaseClientManager.testConnection(
        _supabaseUrl.text.trim(), _anonKey.text.trim());
    if (!ok) { _setError('Could not connect. Check URL and anon key.'); return; }
    setState(() { _connectionTested = true; _isLoading = false; });
  }

  Future<void> _register() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final collegeId = await VendorRegistry.instance.registerCollege(
        collegeName: _collegeName.text.trim(),
        contactEmail: _contactEmail.text.trim(),
        supabaseUrl: _supabaseUrl.text.trim(),
        anonKey: _anonKey.text.trim(),
      );
      await ConfigStore.instance.set(AppConfig(
        supabaseUrl: _supabaseUrl.text.trim(),
        supabaseAnonKey: _anonKey.text.trim(),
        collegeName: _collegeName.text.trim(),
        collegeId: collegeId,
        setupComplete: true,
      ));
      SupabaseClientManager.instance.reset();
      setState(() { _generatedCollegeId = collegeId; _isLoading = false; });
      _nextStep(); // Done step
    } catch (e) {
      _setError(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _step > 0
                          ? setState(() => _step--)
                          : context.go('/'),
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('College Setup',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          Text('Step ${_step + 1} of ${_steps.length}: ${_steps[_step]}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_step + 1) / _steps.length,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _buildStep(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    final content = switch (_step) {
      0 => _StepAccessCode(controller: _accessCode, onNext: _verifyAccessCode),
      1 => _StepCollegeInfo(
          name: _collegeName, email: _contactEmail,
          onNext: () {
            if (_collegeName.text.isEmpty || _contactEmail.text.isEmpty) {
              _setError('Fill all fields.'); return;
            }
            _nextStep();
          }),
      2 => _StepSupabaseConfig(
          url: _supabaseUrl, anonKey: _anonKey,
          tested: _connectionTested,
          onTest: _testConnection,
          onNext: _connectionTested ? () => _nextStep() : null,
          isLoading: _isLoading),
      3 => _StepRegister(
          collegeName: _collegeName.text,
          onRegister: _register,
          isLoading: _isLoading),
      _ => _StepDone(collegeId: _generatedCollegeId ?? '', onGo: () => context.go('/login')),
    };

    return Column(
      children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
            ]),
          ),
        content.animate().fadeIn(duration: 350.ms).slideX(begin: 0.05, end: 0),
      ],
    );
  }
}

// ── Step Widgets ───────────────────────────────────────────────────────────

class _StepAccessCode extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onNext;
  const _StepAccessCode({required this.controller, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lock_outline, color: AppColors.primary, size: 36),
        const SizedBox(height: 16),
        const Text('Access Code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Enter the vendor access code to begin college setup.',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        AppTextField(controller: controller, label: 'Access Code',
            hint: 'SCHEDULIFY2025', prefixIcon: Icons.key_rounded,
            obscureText: true),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Verify', icon: Icons.arrow_forward_rounded,
            width: double.infinity, onPressed: onNext),
      ]),
    );
  }
}

class _StepCollegeInfo extends StatelessWidget {
  final TextEditingController name, email;
  final VoidCallback onNext;
  const _StepCollegeInfo({required this.name, required this.email, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.school_rounded, color: AppColors.primary, size: 36),
        const SizedBox(height: 16),
        const Text('College Information', style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 24),
        AppTextField(controller: name, label: 'College Name',
            hint: 'Delhi Institute of Technology', prefixIcon: Icons.business_rounded),
        const SizedBox(height: 16),
        AppTextField(controller: email, label: 'Contact Email',
            hint: 'admin@college.edu', keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined),
        const SizedBox(height: 20),
        PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded,
            width: double.infinity, onPressed: onNext),
      ]),
    );
  }
}

class _StepSupabaseConfig extends StatelessWidget {
  final TextEditingController url, anonKey;
  final bool tested, isLoading;
  final VoidCallback onTest;
  final VoidCallback? onNext;
  const _StepSupabaseConfig({
    required this.url, required this.anonKey, required this.tested,
    required this.onTest, required this.onNext, required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.cloud_outlined, color: AppColors.primary, size: 36),
        const SizedBox(height: 16),
        const Text('Supabase Configuration', style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Enter your college Supabase project credentials.',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        AppTextField(controller: url, label: 'Supabase URL',
            hint: 'https://xxxx.supabase.co', prefixIcon: Icons.link_rounded),
        const SizedBox(height: 16),
        AppTextField(controller: anonKey, label: 'Anon Key',
            hint: 'eyJhbGci...', prefixIcon: Icons.vpn_key_outlined, obscureText: true),
        const SizedBox(height: 20),
        if (!tested)
          PrimaryButton(label: 'Test Connection', icon: Icons.network_check_rounded,
              width: double.infinity, isLoading: isLoading, onPressed: onTest)
        else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.success.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text('Connection successful!', style: TextStyle(color: AppColors.success)),
            ]),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Continue', icon: Icons.arrow_forward_rounded,
              width: double.infinity, onPressed: onNext),
        ],
      ]),
    );
  }
}

class _StepRegister extends StatelessWidget {
  final String collegeName;
  final VoidCallback onRegister;
  final bool isLoading;
  const _StepRegister({required this.collegeName, required this.onRegister, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.app_registration_rounded, color: AppColors.primary, size: 36),
        const SizedBox(height: 16),
        const Text('Register College', style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text('Ready to register "$collegeName" on Schedulify.',
            style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Register & Generate ID', icon: Icons.rocket_launch_rounded,
            width: double.infinity, isLoading: isLoading, onPressed: onRegister),
      ]),
    );
  }
}

class _StepDone extends StatelessWidget {
  final String collegeId;
  final VoidCallback onGo;
  const _StepDone({required this.collegeId, required this.onGo});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(children: [
        const Icon(Icons.celebration_rounded, color: AppColors.success, size: 48),
        const SizedBox(height: 16),
        const Text('Setup Complete!', style: TextStyle(fontSize: 24,
            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 16),
        const Text('Your College ID:', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(collegeId, style: const TextStyle(fontSize: 28,
              fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 3)),
        ),
        const SizedBox(height: 16),
        const Text('Share this ID with your faculty and students to join.',
            style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Go to Login', icon: Icons.login_rounded,
            width: double.infinity, onPressed: onGo),
      ]),
    );
  }
}
