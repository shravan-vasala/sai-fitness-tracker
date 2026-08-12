import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../models/body_stats.dart';

class BodyStatsScreen extends ConsumerStatefulWidget {
  const BodyStatsScreen({super.key});

  @override
  ConsumerState<BodyStatsScreen> createState() => _BodyStatsScreenState();
}

class _BodyStatsScreenState extends ConsumerState<BodyStatsScreen> {
  final _controllers = <String, TextEditingController>{};
  bool _isEditing = false;

  final _fields = [
    'Waist',
    'Hips',
    'Chest',
    'Left Arm',
    'Right Arm',
    'Left Thigh',
    'Right Thigh',
    'Neck',
  ];

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      _controllers[f] = TextEditingController();
    }
    _loadData();
  }

  void _loadData() {
    final stats = ref.read(bodyStatsRepoProvider).getLatestStats();
    if (stats != null) {
      final m = stats.allMeasurements;
      for (final f in _fields) {
        if (m[f] != null) {
          _controllers[f]!.text = m[f]!.toStringAsFixed(1);
        }
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: Text('Body Stats'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_isEditing) {
                _save();
              }
              setState(() => _isEditing = !_isEditing);
            },
            child: Text(
              _isEditing ? 'Save' : 'Edit',
              style: TextStyle(
                color: context.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        physics: BouncingScrollPhysics(),
        padding: EdgeInsets.all(20),
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.lavender,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.straighten_rounded,
                  color: context.colors.primary,
                  size: 36,
                ),
                SizedBox(height: 8),
                Text(
                  'Body Measurements',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textDark,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'All measurements in cm',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textMedium,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 96,
            ),
            itemCount: _fields.length,
            itemBuilder: (ctx, i) => _buildField(_fields[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String field) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            field,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textMedium,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6),
          _isEditing
              ? SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _controllers[field],
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      suffixText: 'cm',
                      suffixStyle: TextStyle(
                        fontSize: 13,
                        color: context.colors.textLight,
                      ),
                    ),
                  ),
                )
              : Text(
                  _controllers[field]!.text.isEmpty
                      ? '-- cm'
                      : '${_controllers[field]!.text} cm',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _controllers[field]!.text.isEmpty
                        ? context.colors.textLight
                        : context.colors.primary,
                  ),
                ),
        ],
      ),
    );
  }

  void _save() {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final stats = BodyStats(
      date: date,
      waist: double.tryParse(_controllers['Waist']!.text),
      hips: double.tryParse(_controllers['Hips']!.text),
      chest: double.tryParse(_controllers['Chest']!.text),
      leftArm: double.tryParse(_controllers['Left Arm']!.text),
      rightArm: double.tryParse(_controllers['Right Arm']!.text),
      leftThigh: double.tryParse(_controllers['Left Thigh']!.text),
      rightThigh: double.tryParse(_controllers['Right Thigh']!.text),
      neck: double.tryParse(_controllers['Neck']!.text),
    );
    ref.read(bodyStatsRepoProvider).saveStats(stats);
  }
}
