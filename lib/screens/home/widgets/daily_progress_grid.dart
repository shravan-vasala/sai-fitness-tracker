import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/layout_insets.dart';
import '../../../providers/app_providers.dart';
import '../../../services/health_connect_service.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../weight_entry_dialog.dart';
import '../steps_entry_dialog.dart';
import 'sync_status_sheet.dart';

class DailyProgressGrid extends ConsumerWidget {
  const DailyProgressGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches:
    // - dailyLogProvider.select((l) => l.weight)
    final weight = ref.watch(dailyLogProvider.select((l) => l.weight));

    final selectedDateStr = ref.watch(dateStringProvider);
    final selectedDate = DateTime.parse(selectedDateStr);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isFuture = selectedDate.isAfter(today);
    final isToday = selectedDate.isAtSameMomentAs(today);

    String weightSubtitle;
    if (weight != null) {
      weightSubtitle = '${weight.toStringAsFixed(1)} kg';
    } else if (isFuture) {
      weightSubtitle = 'No data';
    } else {
      final lastWeight = _lastLoggedWeight(ref, selectedDateStr);
      weightSubtitle = lastWeight != null
          ? 'Last: ${lastWeight.toStringAsFixed(1)} kg'
          : 'Tap to log';
    }
    
    final mediaRepo = ref.watch(mediaRepoProvider);
    final allPhotos = mediaRepo.getAllProgressPhotos();
    final flattenedPhotos = allPhotos.expand((e) => e.value).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: kScreenPadding),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ProgressCard(
                    title: 'Body Stats',
                    icon: Icons.straighten_rounded,
                    color: context.colors.pink,
                    iconColor: context.colors.pinkIcon,
                    subtitle: 'Tap to view',
                    onTap: () => context.go('/home/body-stats'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ProgressCard(
                    title: 'Physique\nPictures',
                    icon: Icons.camera_alt_rounded,
                    color: context.colors.pink,
                    iconColor: context.colors.pinkIcon,
                    subtitle: 'Progress photos',
                    thumbnails: flattenedPhotos,
                    onTap: () => context.go('/home/physique-pictures'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ProgressCard(
                    title: 'Body Weight',
                    icon: Icons.monitor_weight_rounded,
                    color: context.colors.lavenderCard,
                    iconColor: context.colors.primary,
                    subtitle: weightSubtitle,
                    onTap: isFuture
                        ? () {}
                        : () {
                            showAppBottomSheet(
                              context: context,
                              builder: (_) => WeightEntryDialog(),
                            );
                          },
                    onChartTap: () => context.push('/progress?metric=weight'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StepsCard(
                    isFuture: isFuture,
                    isToday: isToday,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double? _lastLoggedWeight(WidgetRef ref, String beforeOrOnDate) {
    final repo = ref.read(dailyLogRepoProvider);
    final end = DateTime.parse(beforeOrOnDate);
    final start = end.subtract(const Duration(days: 90));
    final startStr =
        '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final logs = repo.getLogsInRange(startStr, beforeOrOnDate);
    for (int i = logs.length - 1; i >= 0; i--) {
      final w = logs[i].weight;
      if (w != null) return w;
    }
    return null;
  }
}

/// Special Steps card that handles the Health Connect first-run CTA.
class _StepsCard extends ConsumerStatefulWidget {
  const _StepsCard({
    required this.isFuture,
    required this.isToday,
  });

  final bool isFuture;
  final bool isToday;

  @override
  ConsumerState<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends ConsumerState<_StepsCard> {
  bool _showSyncCta = false;
  bool _checkingPermission = true;
  bool _isAuth = false;

  @override
  void initState() {
    super.initState();
    _checkHealthConnectStatus();
  }

  Future<void> _checkHealthConnectStatus() async {
    final hcService = ref.read(healthConnectServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final everConnected = prefs.getBool('hc_connected') ?? false;

    // hasPermissions is flaky on Android after process death — also trust
    // a prior successful sync, and probe read access when unsure.
    var connected = everConnected || await hcService.isAuthorized();
    if (!connected) {
      connected = await hcService.canReadSteps();
      if (connected) {
        await prefs.setBool('hc_connected', true);
      }
    }

    if (mounted) {
      setState(() {
        _isAuth = connected;
        _showSyncCta = !connected && widget.isToday;
        _checkingPermission = false;
      });
    }
  }

  Future<void> _handleSyncTap() async {
    final hcService = ref.read(healthConnectServiceProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    
    // Check if Health Connect is installed
    final available = await hcService.isAvailable();
    if (!available) {
      // Deep link to Play Store
      final uri = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // Request permission
    final granted = await hcService.requestPermission();
    if (!granted) return;

    // Trigger sync
    final dailyLogRepo = ref.read(dailyLogRepoProvider);
    final habitRepo = ref.read(habitRepoProvider);
    final steps = await hcService.syncTodayAndAutoCompleteHabit(dailyLogRepo, habitRepo);
    await hcService.syncLast7Days(dailyLogRepo, habitRepo);

    await prefs.setBool('hc_connected', true);
    await prefs.setString('last_hc_sync_time', DateTime.now().toIso8601String());
    if (steps != null) {
      ref.read(stepsSourceProvider.notifier).state = StepsSource.healthConnect;
    }

    if (mounted) {
      setState(() {
        _isAuth = true;
        _showSyncCta = false;
      });
    }
    
    // Backfill in background
    if (!hcService.isBackfillDone) {
      hcService.backfillLast90Days(dailyLogRepo, habitRepo).then((_) {
        ref.invalidate(dailyLogProvider);
        ref.invalidate(habitCompletionsProvider);
      });
    }
    
    ref.invalidate(dailyLogProvider);
    ref.invalidate(habitCompletionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final steps = ref.watch(dailyLogProvider.select((l) => l.steps));
    final stepsSource = ref.watch(dailyLogProvider.select((l) => l.stepsSource));

    // Hide Sync CTA once we have Health Connect data (covers race with async permission check)
    final showSyncCta = _showSyncCta &&
        !_checkingPermission &&
        !(steps != null && stepsSource == 'healthConnect');

    // Show the sync CTA card if permission not granted (today only)
    if (showSyncCta) {
      return GestureDetector(
        onTap: _handleSyncTap,
        child: Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: context.colors.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: context.colors.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colors.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.sync_rounded, color: context.colors.onPrimary, size: 22),
              ),
              SizedBox(height: 14),
              Text(
                'Sync Steps',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.onPrimary,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'from Health Connect',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: context.colors.onPrimary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Determine subtitle
    String stepsSubtitle;
    String? sourceHint;

    if (steps != null) {
      stepsSubtitle = '$steps steps';
      if (stepsSource == 'healthConnect') {
        sourceHint = 'Synced via Health Connect';
      } else if (stepsSource == 'manual') {
        sourceHint = 'manual';
      }
    } else {
      stepsSubtitle = widget.isFuture ? 'No data' : 'Tap to log';
      if (_isAuth) {
        sourceHint = 'Synced';
      } else {
        sourceHint = widget.isToday ? 'Health Connect or manual' : null;
      }
    }

    return GestureDetector(
      onTap: widget.isFuture
          ? () {}
          : () {
              if (_isAuth) {
                showAppBottomSheet(
                  context: context,
                  isScrollControlled: false,
                  builder: (_) => SyncStatusSheet(),
                );
              } else {
                showAppBottomSheet(
                  context: context,
                  builder: (_) => StepsEntryDialog(),
                );
              }
            },
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.mint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.mintIcon.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.directions_walk_rounded, color: context.colors.mintIcon, size: 22),
                ),
                GestureDetector(
                  onTap: () => context.push('/progress?metric=steps'),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.show_chart_rounded, color: context.colors.mintIcon, size: 18),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Text(
              'Steps',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.colors.textDark,
                height: 1.3,
              ),
            ),
            SizedBox(height: 4),
            Text(
              stepsSubtitle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.colors.textMedium,
              ),
            ),
            if (sourceHint != null) ...[
              SizedBox(height: 2),
              Text(
                sourceHint,
                style: TextStyle(
                  fontSize: 10,
                  color: sourceHint == 'Synced via Health Connect' || sourceHint == 'Synced'
                      ? context.colors.green
                      : context.colors.textLight,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.subtitle,
    required this.onTap,
    this.thumbnails,
    this.onChartTap,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final String subtitle;
  final VoidCallback onTap;
  final List<String>? thumbnails;
  final VoidCallback? onChartTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                if (onChartTap != null)
                  GestureDetector(
                    onTap: onChartTap,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.show_chart_rounded, color: iconColor, size: 18),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.colors.textDark,
                height: 1.3,
              ),
            ),
            SizedBox(height: 4),
            if (thumbnails != null && thumbnails!.isNotEmpty)
              Row(
                children: [
                  ...thumbnails!.take(3).map((path) => Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: kIsWeb
                              ? Image.network(
                                  path,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(path),
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  cacheWidth: 96,
                                  cacheHeight: 96,
                                ),
                        ),
                      )),
                  if (thumbnails!.length > 3)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '+${thumbnails!.length - 3}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                ],
              )
            else
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
