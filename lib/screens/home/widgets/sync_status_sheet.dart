import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import '../../../services/health_connect_service.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../steps_entry_dialog.dart';
import '../../../widgets/async_error_card.dart';

class SyncStatusSheet extends ConsumerStatefulWidget {
  const SyncStatusSheet({super.key});

  @override
  ConsumerState<SyncStatusSheet> createState() => _SyncStatusSheetState();
}

class _SyncStatusSheetState extends ConsumerState<SyncStatusSheet> {
  String? _errorMessage;
  String? _errorAction;

  @override
  Widget build(BuildContext context) {
    final dailyLog = ref.watch(dailyLogProvider);
    final steps = dailyLog.steps ?? 0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.sync_rounded, color: context.colors.green, size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Synced Automatically',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textDark,
                        ),
                      ),
                      Text(
                        'via Health Connect',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.colors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    '$steps',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: context.colors.primary,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Steps Today',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              SizedBox(height: 20),
              AsyncErrorCard(
                title: 'Sync Failed',
                message: _errorMessage!,
                actionText: _errorAction,
                onRetry: _errorAction != null ? () async {
                  final hcService = ref.read(healthConnectServiceProvider);
                  if (_errorAction == 'Install Health Connect') {
                    // Provide a way to get it, or just show message
                    setState(() => _errorMessage = 'Please install Health Connect from the Play Store.');
                  } else if (_errorAction == 'Grant Permission') {
                    await hcService.requestPermission();
                    if (mounted) setState(() => _errorMessage = null);
                  }
                } : null,
              ),
            ],
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  setState(() => _errorMessage = null);
                  final hcService = ref.read(healthConnectServiceProvider);
                  final dailyLogRepo = ref.read(dailyLogRepoProvider);
                  final habitRepo = ref.read(habitRepoProvider);
                  final prefs = ref.read(sharedPreferencesProvider);

                  try {
                    final isAvail = await hcService.isAvailable();
                    if (!isAvail) {
                      setState(() {
                        _errorMessage =
                            'Health Connect is not available on this device.';
                        _errorAction = 'Install Health Connect';
                      });
                      return;
                    }

                    // hasPermissions / isAuthorized is flaky after process death.
                    // Trust prior successful sync, then probe a real steps read.
                    final everConnected =
                        prefs.getBool('hc_connected') ?? false;
                    var canSync =
                        everConnected || await hcService.isAuthorized();
                    if (!canSync) {
                      canSync = await hcService.canReadSteps();
                      if (canSync) {
                        await prefs.setBool('hc_connected', true);
                      }
                    }

                    if (!canSync) {
                      setState(() {
                        _errorMessage =
                            'Missing permissions to read steps.';
                        _errorAction = 'Grant Permission';
                      });
                      return;
                    }

                    final steps =
                        await hcService.syncTodayAndAutoCompleteHabit(
                      dailyLogRepo,
                      habitRepo,
                    );
                    if (steps != null) {
                      await prefs.setBool('hc_connected', true);
                      ref.read(stepsSourceProvider.notifier).state =
                          StepsSource.healthConnect;
                    }

                    ref.invalidate(dailyLogProvider);
                    ref.invalidate(habitCompletionsProvider);
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (e) {
                    setState(() {
                      _errorMessage =
                          'An unexpected error occurred during sync.';
                      _errorAction = null;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Refresh Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  showAppBottomSheet(
                    context: context,
                    builder: (_) => StepsEntryDialog(),
                  );
                },
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Log Manually Instead',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
