import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../models/user_profile.dart';
import '../../services/health_connect_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_sync_service.dart';
import '../../models/habit.dart';
import '../../utils/habit_icons.dart';

import 'package:flutter_svg/flutter_svg.dart';

String kOnboardingCompletedKey = 'onboarding_completed';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 6;

  // Step 2 — Profile
  final _nameController = TextEditingController();
  final _coachNameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _useKg = true;

  // Step 3 — Goals
  double _targetCalories = 1397;
  final List<String> _selectedHabitIds = ['sleep', 'walk', 'water'];

  // Step 4 — Health Connect
  bool _hcConnecting = false;
  bool _hcConnected = false;
  String _hcStatus = '';

  // Step 5 — AI
  final _geminiKeyController = TextEditingController();
  bool _geminiKeySaved = false;
  bool _obscureKey = true;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _coachNameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _geminiKeyController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_currentPage < _totalPages - 1) {
      if (_currentPage == 1) {
        // Validate & save profile on Step 2
        if (!_saveProfile()) return;
      }
      if (_currentPage == 2) {
        _saveGoals();
      }
      _pageController.nextPage(
        duration: Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      await _saveGeminiKey();
      _complete();
    }
  }

  void _goBack() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _saveProfile() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter your name'),
          backgroundColor: context.colors.red,
        ),
      );
      return false;
    }
    final height = double.tryParse(_heightController.text) ?? 160.0;
    final weight = double.tryParse(_weightController.text);
    final current = ref.read(profileProvider);
    ref.read(profileProvider.notifier).updateProfile(
          current.copyWith(
            name: name,
            coachName: _coachNameController.text.trim(),
            height: height,
            targetWeight: weight,
            useKg: _useKg,
          ),
        );
    return true;
  }

  void _saveGoals() {
    final current = ref.read(profileProvider);
    ref.read(profileProvider.notifier).updateProfile(
          current.copyWith(targetCalories: _targetCalories.round()),
        );
    // Save selected habits
    final habitRepo = ref.read(habitRepoProvider);
    
    // Remove any habits that were seeded but unselected by the user
    final currentHabits = habitRepo.getHabits();
    for (final habit in currentHabits) {
      if (!_selectedHabitIds.contains(habit.id)) {
        habitRepo.deleteHabit(habit.id);
      }
    }

    final selected = Habit.defaults
        .where((h) => _selectedHabitIds.contains(h.id))
        .toList();
    for (final habit in selected) {
      habitRepo.saveHabit(habit);
    }
  }

  Future<void> _connectHealthConnect() async {
    setState(() {
      _hcConnecting = true;
      _hcStatus = '';
    });
    try {
      final hcService = ref.read(healthConnectServiceProvider);
      final granted = await hcService.requestPermission();
      setState(() {
        _hcConnected = granted;
        _hcStatus = granted
            ? 'Connected! Steps and sleep will sync automatically.'
            : 'Permission denied. You can connect later in Settings.';
      });
    } catch (e) {
      setState(() {
        _hcStatus = 'Health Connect not available on this device.';
      });
    } finally {
      setState(() => _hcConnecting = false);
    }
  }

  Future<void> _saveGeminiKey() async {
    final key = _geminiKeyController.text.trim();
    if (key.isNotEmpty) {
      try {
        await ref.read(geminiFoodServiceProvider).verifyApiKey(key);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
          );
        }
        return; // Abort save if key is invalid
      }
      await ref.read(profileProvider.notifier).updateGeminiKey(key);
      setState(() => _geminiKeySaved = true);
    }
  }

  Future<void> _complete() async {
    await ref.read(onboardingCompletedProvider.notifier).completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            _ProgressDots(current: _currentPage, total: _totalPages),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(),
                  _ProfilePage(
                    nameController: _nameController,
                    coachNameController: _coachNameController,
                    heightController: _heightController,
                    weightController: _weightController,
                    useKg: _useKg,
                    onToggleUnit: () => setState(() => _useKg = !_useKg),
                  ),
                  _GoalsPage(
                    targetCalories: _targetCalories,
                    selectedHabitIds: _selectedHabitIds,
                    onCaloriesChanged: (v) =>
                        setState(() => _targetCalories = v),
                    onHabitToggled: (id, selected) {
                      setState(() {
                        if (selected) {
                          _selectedHabitIds.add(id);
                        } else {
                          _selectedHabitIds.remove(id);
                        }
                      });
                    },
                  ),
                  _HealthConnectPage(
                    connecting: _hcConnecting,
                    connected: _hcConnected,
                    status: _hcStatus,
                    onConnect: _connectHealthConnect,
                  ),
                  _AiSetupPage(
                    controller: _geminiKeyController,
                    keySaved: _geminiKeySaved,
                    obscure: _obscureKey,
                    onToggleObscure: () =>
                        setState(() => _obscureKey = !_obscureKey),
                    onSaveKey: _saveGeminiKey,
                  ),
                  _CloudSyncPage(),
                ],
              ),
            ),
            // Navigation buttons
            _NavButtons(
              currentPage: _currentPage,
              totalPages: _totalPages,
              onBack: _goBack,
              onNext: _goNext,
              onSkip: _goNext,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Progress Dots ───────────────────────────────────────────────────────────

class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          total,
          (i) => AnimatedContainer(
            duration: Duration(milliseconds: 250),
            margin: EdgeInsets.symmetric(horizontal: 4),
            width: i == current ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == current ? context.colors.primary : context.colors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Nav Buttons ─────────────────────────────────────────────────────────────

class _NavButtons extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _NavButtons({
    required this.currentPage,
    required this.totalPages,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  bool get _isOptionalPage => currentPage == 3 || currentPage == 4;
  bool get _isLastPage => currentPage == totalPages - 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          if (currentPage > 0)
            TextButton(
              onPressed: onBack,
              child: Text('Back',
                  style: TextStyle(color: context.colors.textMedium)),
            )
          else
            SizedBox(width: 64),
          Spacer(),
          if (_isOptionalPage && !_isLastPage)
            TextButton(
              onPressed: onSkip,
              child: Text('Skip',
                  style: TextStyle(color: context.colors.primary.withValues(alpha: 0.7))),
            ),
          SizedBox(width: 8),
          _PrimaryButton(
            label: _isLastPage ? 'Get Started' : 'Next',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: context.colors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            color: context.colors.onPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ─── Step 1: Welcome ─────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          SizedBox(height: 40),
          // Logo
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: context.colors.border, width: 2),
            ),
            child: Center(
              child: Image.asset(
                'assets/icon/logo.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(height: 32),
          Text(
            'Sthira',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'स्थिर · steady, every day',
            style: TextStyle(
              fontSize: 16,
              color: context.colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 48),
          ...[
            _FeaturePill(
              icon: Icons.play_circle_outline_rounded,
              title: 'No accounts, ever',
              subtitle: 'Your data never leaves your device',
            ),
            _FeaturePill(
              icon: Icons.camera_alt_outlined,
              title: 'Works fully offline',
              subtitle: 'No internet required for workouts & tracking',
            ),
            _FeaturePill(
              icon: Icons.lock_outline_rounded,
              title: 'You own your data',
              subtitle: 'Export & restore any time with one tap',
            ),
          ],
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeaturePill({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            child: Center(child: Icon(icon, size: 28, color: context.colors.textDark)),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textDark,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Profile Setup ────────────────────────────────────────────────────

class _ProfilePage extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController coachNameController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final bool useKg;
  final VoidCallback onToggleUnit;

  const _ProfilePage({
    required this.nameController,
    required this.coachNameController,
    required this.heightController,
    required this.weightController,
    required this.useKg,
    required this.onToggleUnit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 24),
          _StepHeader(icon: Icons.person_outline_rounded, title: "Let's set up\nyour profile"),
          SizedBox(height: 32),
          _FieldLabel('Your Name *'),
          _InputField(
            controller: nameController,
            hint: '',
            capitalization: TextCapitalization.words,
          ),
          SizedBox(height: 20),
          _FieldLabel('Coach name (optional)'),
          _InputField(
            controller: coachNameController,
            hint: '',
            capitalization: TextCapitalization.words,
          ),
          SizedBox(height: 8),
          Text(
            'Shown on daily coach notes (e.g. "Coach Shravan").',
            style: TextStyle(fontSize: 12, color: context.colors.textMedium),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Height (cm)'),
                    _InputField(
                      controller: heightController,
                      hint: '175',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FieldLabel('Target Weight (opt.)'),
                    _InputField(
                      controller: weightController,
                      hint: useKg ? '70 kg' : '154 lb',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _FieldLabel('Weight Unit'),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withValues(alpha: 0.06),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                _UnitTab(label: 'KG', selected: useKg, onTap: () { if (!useKg) onToggleUnit(); }),
                _UnitTab(label: 'LB', selected: !useKg, onTap: () { if (useKg) onToggleUnit(); }),
              ],
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _UnitTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UnitTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? context.colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? context.colors.onPrimary : context.colors.textMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Step 3: Goals ────────────────────────────────────────────────────────────

class _GoalsPage extends StatelessWidget {
  final double targetCalories;
  final List<String> selectedHabitIds;
  final ValueChanged<double> onCaloriesChanged;
  final void Function(String id, bool selected) onHabitToggled;

  const _GoalsPage({
    required this.targetCalories,
    required this.selectedHabitIds,
    required this.onCaloriesChanged,
    required this.onHabitToggled,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 24),
          _StepHeader(icon: Icons.flag_outlined, title: 'Set your\ndaily goals'),
          SizedBox(height: 32),
          _SectionCard(
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department_outlined, color: context.colors.primary, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Daily Calorie Target',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDark,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.colors.lavender,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${targetCalories.round()} kcal',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: context.colors.primary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: context.colors.primary,
                  thumbColor: context.colors.primary,
                  inactiveTrackColor: context.colors.border,
                  overlayColor: context.colors.primary.withValues(alpha: 0.1),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: targetCalories,
                  min: 1200,
                  max: 2500,
                  divisions: 130,
                  onChanged: onCaloriesChanged,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1200', style: TextStyle(fontSize: 11, color: context.colors.textLight)),
                  Text('2500', style: TextStyle(fontSize: 11, color: context.colors.textLight)),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          Text(
            'Default Habits',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textDark,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Pick habits to track daily',
            style: TextStyle(fontSize: 13, color: context.colors.textMedium),
          ),
          SizedBox(height: 12),
          ...Habit.defaults.map((habit) {
            final selected = selectedHabitIds.contains(habit.id);
            return GestureDetector(
              onTap: () => onHabitToggled(habit.id, !selected),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? context.colors.lavender : context.colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? context.colors.primary : context.colors.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      HabitIcons.resolve(habit.icon),
                      size: 22,
                      color: selected
                          ? context.colors.primary
                          : context.colors.textMedium,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        habit.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? context.colors.primary : context.colors.textDark,
                        ),
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle_rounded,
                          color: context.colors.primary, size: 20),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Step 4: Health Connect ───────────────────────────────────────────────────

class _HealthConnectPage extends StatelessWidget {
  final bool connecting;
  final bool connected;
  final String status;
  final VoidCallback onConnect;

  const _HealthConnectPage({
    required this.connecting,
    required this.connected,
    required this.status,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 24),
          _StepHeader(icon: Icons.favorite_border_rounded, title: 'Sync health\ndata (optional)'),
          SizedBox(height: 12),
          Text(
            'Connect to Health Connect to automatically sync your daily steps and sleep hours from Samsung Health or other health apps.',
            style: TextStyle(fontSize: 14, color: context.colors.textMedium, height: 1.5),
          ),
          SizedBox(height: 32),
          _SectionCard(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.colors.mint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Icon(Icons.directions_walk_rounded, color: Colors.white, size: 24)),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily Steps', style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.textDark)),
                        Text('Auto-synced from Samsung Health', style: TextStyle(fontSize: 12, color: context.colors.textMedium)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.colors.lavenderCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Icon(Icons.nights_stay_rounded, color: Colors.white, size: 22)),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sleep Hours', style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.textDark)),
                        Text('Auto-synced from Health Connect', style: TextStyle(fontSize: 12, color: context.colors.textMedium)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),
          if (status.isNotEmpty)
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: connected ? context.colors.greenLight : context.colors.lavender,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    connected ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: connected ? context.colors.green : context.colors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        color: connected ? context.colors.green : context.colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 20),
          if (!connected)
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: context.colors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: connecting ? null : onConnect,
                  icon: connecting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: context.colors.onPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.link_rounded, color: context.colors.onPrimary),
                  label: Text(
                    connecting ? 'Connecting...' : 'Connect Health Connect',
                    style: TextStyle(
                      color: context.colors.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Step 5: AI Setup ─────────────────────────────────────────────────────────

class _AiSetupPage extends StatelessWidget {
  final TextEditingController controller;
  final bool keySaved;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSaveKey;

  const _AiSetupPage({
    required this.controller,
    required this.keySaved,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSaveKey,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 24),
          _StepHeader(icon: Icons.auto_awesome_outlined, title: 'AI-powered\nfeatures (optional)'),
          SizedBox(height: 12),
          Text(
            'Add a free Gemini API key to unlock AI meal scanning from photos and personalized daily coach notes. (Skip this if you plan to use Cloud Sync on the next step!)',
            style: TextStyle(fontSize: 14, color: context.colors.textMedium, height: 1.5),
          ),
          SizedBox(height: 24),
          _SectionCard(
            children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: context.colors.pink, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20)),
                ),
                SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meal Photo Scanning', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.colors.textDark)),
                    Text('AI estimates calories from photos', style: TextStyle(fontSize: 12, color: context.colors.textMedium)),
                  ],
                )),
              ]),
              SizedBox(height: 12),
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: context.colors.lavenderCard, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Icon(Icons.psychology_outlined, color: Colors.white, size: 22)),
                ),
                SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Coach Notes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: context.colors.textDark)),
                    Text('Personalized encouragement every day', style: TextStyle(fontSize: 12, color: context.colors.textMedium)),
                  ],
                )),
              ]),
            ],
          ),
          SizedBox(height: 24),
          _FieldLabel('Gemini API Key'),
          SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: TextStyle(color: context.colors.textDark, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste your API key here...',
              hintStyle: TextStyle(color: context.colors.textLight),
              filled: true,
              fillColor: context.colors.inputFill,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: context.colors.primary, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: context.colors.textLight,
                ),
                onPressed: onToggleObscure,
              ),
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: () => launchUrl(Uri.parse('https://aistudio.google.com/app/apikey')),
                child: Text(
                  'Get a free key from Google AI Studio →',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.primary,
                    decoration: TextDecoration.underline,
                    decorationColor: context.colors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          if (!keySaved)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.primary,
                  side: BorderSide(color: context.colors.primary),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: Icon(Icons.save_outlined),
                label: Text('Save API Key', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: onSaveKey,
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.greenLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: context.colors.green, size: 18),
                  SizedBox(width: 10),
                  Text('API key saved securely 🔒',
                      style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.green)),
                ],
              ),
            ),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _StepHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 36, color: context.colors.primary),
        SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: context.colors.textDark,
            height: 1.15,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colors.textMedium,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final List<TextInputFormatter> inputFormatters;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.inputFormatters = const [],
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      inputFormatters: inputFormatters,
      style: TextStyle(color: context.colors.textDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colors.textLight),
        filled: true,
        fillColor: context.colors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: context.colors.primary, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ─── Step 6: Cloud Sync ─────────────────────────────────────────────────────────

class _CloudSyncPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends ConsumerState<_CloudSyncPage> {
  bool _isSyncing = false;
  String _syncStatus = '';

  Future<void> _handleSignIn() async {
    setState(() { _isSyncing = true; _syncStatus = 'Signing in...'; });
    try {
      final user = await ref.read(authServiceProvider).signInWithGoogle();
      if (user != null && mounted) {
        setState(() { _syncStatus = 'Syncing data...'; });
        final syncService = ref.read(firestoreSyncServiceProvider);
        
        final hasCloudData = await syncService.hasCloudData();
        if (hasCloudData) {
          // Pull down to device
          final profile = await syncService.pullProfile();
          await ref.read(profileRepoProvider).importProfileFromCloud(profile);
          final dailyLogs = await syncService.pullCollection('daily_logs');
          await ref.read(dailyLogRepoProvider).importFromCloud(dailyLogs);
          final mealLogs = await syncService.pullCollection('meal_logs');
          await ref.read(mealRepoProvider).importLogsFromCloud(mealLogs);
          final stats = await syncService.pullCollection('body_stats');
          await ref.read(bodyStatsRepoProvider).importStatsFromCloud(stats);
          
          final workoutPlans = await syncService.pullCollection('workout_plans');
          await ref.read(workoutRepoProvider).importPlansFromCloud(workoutPlans);
          
          final mealPlans = await syncService.pullCollection('meal_plans');
          await ref.read(mealRepoProvider).importPlansFromCloud(mealPlans);
          
          ref.invalidate(profileProvider);
          ref.invalidate(dailyLogProvider);
          ref.invalidate(dailyMealLogProvider);
          ref.invalidate(latestBodyStatsProvider);
        } else {
          // Upload local seeded data
          syncService.syncProfile(ref.read(profileRepoProvider).exportProfileForCloud());
          await syncService.bulkSync('habit_config', ref.read(habitRepoProvider).exportConfigForCloud());
          await syncService.bulkSync('workout_plans', ref.read(workoutRepoProvider).exportPlansForCloud());
          await syncService.bulkSync('meal_plans', ref.read(mealRepoProvider).exportPlansForCloud());
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully signed in & synced!'), backgroundColor: context.colors.primary),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e'), backgroundColor: context.colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isSyncing = false; _syncStatus = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final userEmail = ref.watch(userEmailProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 24),
          _StepHeader(icon: Icons.cloud_queue_rounded, title: 'Cloud Sync\n(optional)'),
          SizedBox(height: 12),
          Text(
            'Keep your data safe. Sign in to sync your progress, habits, and logs across devices securely.',
            style: TextStyle(fontSize: 14, color: context.colors.textMedium, height: 1.5),
          ),
          SizedBox(height: 32),
          if (_isSyncing)
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(_syncStatus, style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else if (!isSignedIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  foregroundColor: context.colors.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: Icon(Icons.login),
                label: Text('Sign in with Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          else
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.green.withValues(alpha: 0.5), width: 2),
              ),
              child: Column(
                children: [
                  Icon(Icons.cloud_done_rounded, color: context.colors.green, size: 48),
                  SizedBox(height: 12),
                  Text('Signed In!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.colors.textDark)),
                  SizedBox(height: 8),
                  Text(userEmail ?? '', style: TextStyle(color: context.colors.textMedium)),
                  SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => ref.read(authServiceProvider).signOut(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.colors.red,
                      side: BorderSide(color: context.colors.red),
                    ),
                    child: Text('Sign Out'),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }
}
