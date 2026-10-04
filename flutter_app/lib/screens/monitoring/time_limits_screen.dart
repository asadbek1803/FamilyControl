import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/child_device.dart';
import '../../models/app_time_limit.dart';
import '../../models/installed_app.dart';
import '../../providers/device_provider.dart';

/// Ilovalar uchun kunlik vaqt limitlari.
///
/// Serverdagi chegara: `max_daily_minutes` 1..1440 oralig'ida bo'lishi
/// kerak. Bu ilovada ham tekshiriladi — aks holda server 400 qaytaradi va
/// foydalanuvchi nima uchun saqlanmaganini tushunmaydi.
class TimeLimitsScreen extends StatefulWidget {
  final ChildDevice device;

  const TimeLimitsScreen({super.key, required this.device});

  @override
  State<TimeLimitsScreen> createState() => _TimeLimitsScreenState();
}

class _TimeLimitsScreenState extends State<TimeLimitsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadTimeLimits(widget.device.id);
      // Ilova tanlash uchun o'rnatilgan ilovalar kerak.
      context.read<DeviceProvider>().loadApps(widget.device.id);
    });
  }

  Future<void> _showLimitDialog({AppTimeLimit? limit}) async {
    final provider = context.read<DeviceProvider>();
    final result = await showDialog<_LimitResult>(
      context: context,
      builder: (_) => _LimitDialog(
        limit: limit,
        apps: provider.apps,
      ),
    );

    if (result == null || !mounted) return;

    final data = <String, dynamic>{
      'package_name': result.packageName,
      'max_daily_minutes': result.minutes,
      'is_active': true,
      if (result.blockAfterTime != null)
        'block_after_time': result.blockAfterTime,
    };

    final ok = limit == null
        ? await provider.setAppLimit(widget.device.id, data)
        : await provider.updateTimeLimit(widget.device.id, limit.id, data);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (limit == null ? 'Limit qo\'shildi' : 'Limit yangilandi')
            : 'Saqlanmadi. Serverga ulanib, qayta urinib ko\'ring.'),
      ),
    );
  }

  Future<void> _deleteLimit(AppTimeLimit limit) async {
    final ok = await context
        .read<DeviceProvider>()
        .deleteTimeLimit(widget.device.id, limit.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Limit o\'chirildi' : 'O\'chirilmadi')),
    );
  }

  /// Limitni o'chirishsiz vaqtini to'xtatish (`is_active = false`).
  ///
  /// Foydalanuvchi ko'pincha limitni butunlay o'chirmasdan, faqat vaqtini
  /// to'xtatmoqchi bo'ladi — o'chirsa, keyin yana kiritish kerak.
  Future<void> _toggleActive(AppTimeLimit limit) async {
    final ok = await context.read<DeviceProvider>().updateTimeLimit(
          widget.device.id,
          limit.id,
          {'is_active': !limit.isActive},
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (limit.isActive ? 'Limit to\'xtatildi' : 'Limit yoqildi')
            : 'O\'zgartirilmadi'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Vaqt limitlari - ${widget.device.displayName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yangilash',
            onPressed: () =>
                context.read<DeviceProvider>().loadTimeLimits(widget.device.id),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLimitDialog(),
        icon: const Icon(Icons.timer),
        label: const Text('Limit qo\'shish'),
      ),
      body: _buildBody(provider),
    );
  }

  Widget _buildBody(DeviceProvider provider) {
    if (provider.isLoading && provider.timeLimits.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final limits = provider.timeLimits;

    if (limits.isEmpty) {
      return RefreshIndicator(
        onRefresh: () =>
            context.read<DeviceProvider>().loadTimeLimits(widget.device.id),
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Icon(Icons.timer_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Vaqt limiti yo\'q',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Masalan, YouTube\'ga kuniga 60 daqiqa.\n'
              'Limit tugach ilova avtomatik bloklanadi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          context.read<DeviceProvider>().loadTimeLimits(widget.device.id),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: limits.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, index) {
          final limit = limits[index];
          return _LimitTile(
            limit: limit,
            onTap: () => _showLimitDialog(limit: limit),
            onToggle: () => _toggleActive(limit),
            onDelete: () => _deleteLimit(limit),
          );
        },
      ),
    );
  }
}

class _LimitTile extends StatelessWidget {
  final AppTimeLimit limit;
  final VoidCallback onTap;
  final Future<void> Function() onToggle;
  final Future<void> Function() onDelete;

  const _LimitTile({
    required this.limit,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final minutes = limit.maxDailyMinutes;
    final hours = minutes ~/ 60;
    final rest = minutes % 60;

    final durationText = hours > 0
        ? (rest > 0 ? '$hours soat $rest daqiqa' : '$hours soat')
        : '$minutes daqiqa';

    return Dismissible(
      key: ValueKey(limit.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await onDelete();
        // Ro'yxatdan butunlay olib tashlash o'rniga serverga so'rov yuborish
        // kerak; u muvaffaqiyatsiz bo'lsa qator joyida qolishi kerak.
        return false;
      },
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          limit.isActive ? Icons.timer : Icons.timer_off,
          color: limit.isActive ? Colors.teal : Colors.grey,
          size: 28,
        ),
        title: Text(
          _prettyName(limit.packageName),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: limit.isActive ? null : Colors.grey,
            decoration: limit.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'Kuniga $durationText'
              '${limit.blockAfterTime != null ? ' · ${limit.blockAfterTime} dan keyin bloklanadi' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: limit.isActive,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }

  /// `com.google.android.youtube` -> `YouTube`.
  ///
  /// Bundle id o'zi ota-ona uchun ma'nosiz; nomni ilova ro'yxatidan olish
  /// kerak. Bu yerda umumiy qoidalar bilan taxmin qilinadi, `showDialog`
  /// esa haqiqiy nomni ilova ro'yxatidan ko'rsatadi.
  static String _prettyName(String packageName) {
    final lastDot = packageName.lastIndexOf('.');
    if (lastDot == -1) return packageName;
    final raw = packageName.substring(lastDot + 1);
    if (raw.isEmpty) return packageName;

    // `youtube` -> `You Tube` (to'ldiruvchi belgilar ajratiladi)
    return raw
        .split(RegExp(r'[_.\-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

class _LimitResult {
  final String packageName;
  final int minutes;
  final String? blockAfterTime;

  const _LimitResult({
    required this.packageName,
    required this.minutes,
    this.blockAfterTime,
  });
}

class _LimitDialog extends StatefulWidget {
  final AppTimeLimit? limit;
  final List<InstalledApp> apps;

  const _LimitDialog({this.limit, required this.apps});

  @override
  State<_LimitDialog> createState() => _LimitDialogState();
}

class _LimitDialogState extends State<_LimitDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minutesController;
  late String _packageName;
  late bool _useBlockTime;
  late final TextEditingController _blockTimeController;

  @override
  void initState() {
    super.initState();
    final limit = widget.limit;

    _packageName = limit?.packageName ?? '';
    _minutesController =
        TextEditingController(text: (limit?.maxDailyMinutes ?? 60).toString());
    _useBlockTime = limit?.blockAfterTime != null;
    _blockTimeController =
        TextEditingController(text: limit?.blockAfterTime ?? '21:00');
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _blockTimeController.dispose();
    super.dispose();
  }

  /// Server chegarasi: 1..1440.
  String? _validateMinutes(String? value) {
    final minutes = int.tryParse(value ?? '');
    if (minutes == null) return 'Raqam kiriting';
    if (minutes < 1) return 'Kamida 1 daqiqa';
    if (minutes > 1440) return 'Ko\'pi bilan 24 soat (1440 daqiqa)';
    return null;
  }

  /// `HH:MM` formatini tekshirish.
  String? _validateBlockTime(String? value) {
    if (!_useBlockTime) return null;

    final match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$').firstMatch(
      (value ?? '').trim(),
    );
    if (match == null) return 'Format: HH:MM (masalan 21:00)';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_packageName.isEmpty) return;

    Navigator.pop(
      context,
      _LimitResult(
        packageName: _packageName,
        minutes: int.parse(_minutesController.text),
        blockAfterTime:
            _useBlockTime ? _blockTimeController.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.limit == null ? 'Yangi limit' : 'Limitni tahrirlash'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AppPicker(
                apps: widget.apps,
                selected: _packageName,
                onSelected: (value) => setState(() => _packageName = value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minutesController,
                decoration: const InputDecoration(
                  labelText: 'Kunlik limit (daqiqa)',
                  helperText: '1 daqiqadan 1440 daqiqagacha',
                ),
                keyboardType: TextInputType.number,
                validator: _validateMinutes,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Belgilangan vaqtdan keyin bloklanadigan',
                  style: TextStyle(fontSize: 13),
                ),
                value: _useBlockTime,
                onChanged: (value) => setState(() => _useBlockTime = value),
              ),
              if (_useBlockTime) ...[
                TextFormField(
                  controller: _blockTimeController,
                  decoration: const InputDecoration(
                    labelText: 'Bloklash vaqti (HH:MM)',
                    hintText: '21:00',
                  ),
                  validator: _validateBlockTime,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.limit == null ? 'Qo\'shish' : 'Saqlash'),
        ),
      ],
    );
  }
}

/// O'rnatilgan ilovalardan tanlash.
///
/// Serverdagi ilova ro'yxati (`installed_apps`) bo'lmasa, foydalanuvchi
/// bundle id ni qo'lda kiritishi kerak — aks holda limit yaratib bo'lmaydi.
class _AppPicker extends StatelessWidget {
  final List<InstalledApp> apps;
  final String selected;
  final ValueChanged<String> onSelected;

  const _AppPicker({
    required this.apps,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      // Serverdagi ilova ro'yxati kelmagan. Bundle id ni qo'lda kiritish
      // yanada ham mumkin — aks holda limit yaratib bo'lmasdi.
      return TextFormField(
        initialValue: selected,
        decoration: const InputDecoration(
          labelText: 'Ilova paket nomi',
          hintText: 'com.google.android.youtube',
          helperText: 'O\'rnatilgan ilovalar ro\'yxati kelmagan',
        ),
        onChanged: onSelected,
      );
    }

    // Tanlangan ilova o'rnatilgan ilovalar orasida yo'q bo'lishi mumkin
    // (ilova keyin o'chirilgan). Uni ro'yxatga qo'shaman — aks holda
    // `DropdownButtonFormField` qiymatni topa olmay xato beradi va mavjud
    // limitni tahrirlash mumkin bo'lmay qoladi.
    final options = <(String, String)>[
      for (final app in apps)
        (app.packageName, app.appName.isNotEmpty ? app.appName : app.packageName),
    ];
    final hasSelected = options.any((o) => o.$1 == selected);
    if (selected.isNotEmpty && !hasSelected) {
      options.insert(0, (selected, '(o\'chirilgan) $selected'));
    }

    return DropdownButtonFormField<String>(
      initialValue: hasSelected ? selected : null,
      decoration: const InputDecoration(labelText: 'Ilova'),
      isExpanded: true,
      items: [
        for (final (value, label) in options)
          DropdownMenuItem(
            value: value,
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }
}
