import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../devices/device_list_screen.dart';
import '../devices/pair_device_screen.dart';
import '../settings/telegram_settings_screen.dart';

/// Ota-onaning asosiy ekrani.
///
/// Bu yerda BARCHA bo'limlar ko'rinadi. Ilgari 6 ta bo'lim bor edi, hozir
/// yana qo'shildi: xavfsizlik zonalari, vaqt limitlari, SOS signallari,
/// hodisa tarixi, kontaktlar, bildirishnomalar.
///
/// Muhim o'zgarish: yuqorida **boshqaruv paneli** kartasi bor. Oldin har bir
/// bo'limga o'tish uchun avval bitta qurilma tanlash kerak edi, shuning
/// uchun bir nechta farzandni bir vaqtda ko'rib bo'lmasdi.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    // Panel birinchi ochilishda ham yuklanishi SHART. Aks holda yuqoridagi
    // kartasi doim "kirish" holatida qolardi va "0 farzand" deb yolg'on
    // ko'rsatilardi (ma'lumot umuman kelmagan).
    //
    // `addPostFrameCallback` kerak: `context.read` initState da Provider
    // hali tepaga bog'lanmagan bo'lishi mumkin.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final conn = context.watch<ConnectivityProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FamilyControl'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: Icon(
                conn.isOnline ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: conn.isOnline ? Colors.green : Colors.red,
              ),
              label: Text(
                conn.statusText,
                style: TextStyle(
                  fontSize: 11,
                  color: conn.isOnline ? Colors.green : Colors.red,
                ),
              ),
              backgroundColor: conn.isOnline
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Bildirishnoma sozlamalari',
            onPressed: () async {
              await context.read<NotificationSettingsProvider>().load();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const TelegramSettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Chiqish',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Chiqish'),
                  content: const Text('Tizimdan chiqmoqchimisiz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Bekor'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Ha, chiqish'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<AuthProvider>().logout();
                // Boshqaruv paneli ma'lumotini tozalash — keyingi ota-ona
                // (boshqa akkaunt bilan) eski oilaning ma'lumatini
                // ko'rmasligi kerak.
                if (context.mounted) {
                  context.read<DashboardProvider>().clear();
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Ikkalasi bir vaqtda: panel o'z ma'lumotini, ro'yxat esa
          // `devices/` dan oladi. Ketma-ket kutamiz — parallel so'rovlar
          // sekin tarmoqlarda bir-birini bekor qilishi mumkin.
          await context.read<DashboardProvider>().load();
          if (context.mounted) {
            await context.read<DeviceProvider>().loadDevices();
          }
          // Boshqa bo'limlarda ota-ona nomini tahrirlagan bo'lishi mumkin.
          // Panel o'z ma'lumotini serverdan oladi, shuning uchun qayta
          // o'qish kerak — aks holda eski nom ko'rinib turadi.
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _WelcomeCard(username: auth.username),
            const SizedBox(height: 16),
            const _DashboardPreview(),
            const SizedBox(height: 24),
            Text(
              'Bo\'limlar',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _HomeCard(
                  icon: Icons.dashboard,
                  title: 'Boshqaruv paneli',
                  subtitle: 'Barcha farzandlar bir ekranda',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DashboardScreen()),
                  ),
                ),
                _HomeCard(
                  icon: Icons.devices,
                  title: 'Qurilmalar',
                  subtitle: 'Bolalar qurilmalarini ko\'rish',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const DeviceListScreen()),
                  ),
                ),
                _HomeCard(
                  icon: Icons.link,
                  title: 'Qurilma ulash',
                  subtitle: 'Pairing code bilan ulash',
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PairDeviceScreen()),
                  ),
                ),
                _HomeCard(
                  icon: Icons.location_on,
                  title: 'Joylashuv',
                  subtitle: 'Bolalar joylashuvini kuzatish',
                  color: Colors.orange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DeviceListScreen(openMonitoring: 'location'),
                    ),
                  ),
                ),
                _HomeCard(
                  icon: Icons.apps,
                  title: 'Ilovalar',
                  subtitle: 'Ilovalarni bloklash',
                  color: Colors.purple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DeviceListScreen(openMonitoring: 'apps'),
                    ),
                  ),
                ),
                _HomeCard(
                  icon: Icons.bar_chart,
                  title: 'Foydalanish',
                  subtitle: 'Ilova foydalanish vaqti',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DeviceListScreen(openMonitoring: 'usage'),
                    ),
                  ),
                ),
                _HomeCard(
                  icon: Icons.shield,
                  title: 'Xavfsizlik zonalari',
                  subtitle: 'Bolangiz bo\'lishi kerak joylar',
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DeviceListScreen(openMonitoring: 'zones'),
                    ),
                  ),
                ),
                _HomeCard(
                  icon: Icons.timer,
                  title: 'Vaqt limitlari',
                  subtitle: 'Ilovalar uchun kunlik limit',
                  color: Colors.deepOrange,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DeviceListScreen(openMonitoring: 'limits'),
                    ),
                  ),
                ),
                _HomeCard(
                  icon: Icons.sos,
                  title: 'SOS signallari',
                  subtitle: 'Yordam so\'ralgan signallar',
                  color: Colors.red,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DeviceListScreen(openMonitoring: 'sos'),
                    ),
                  ),
                ),
                _HomeCard(
                  icon: Icons.history,
                  title: 'Hodisa tarixi',
                  subtitle: 'Nima bo\'lganini ko\'rish',
                  color: Colors.brown,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DeviceListScreen(openMonitoring: 'events'),
                    ),
                  ),
                ),
                _HomeCard(
                  icon: Icons.contacts,
                  title: 'Kontaktlar',
                  subtitle: 'Bolangiz kontaktlari',
                  color: Colors.cyan,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DeviceListScreen(openMonitoring: 'contacts'),
                    ),
                  ),
                ),
                _HomeCard(
                  icon: Icons.notifications_off,
                  title: 'Bildirishnomalar',
                  subtitle: 'Yig\'ilmaydi (maxfiylik)',
                  color: Colors.grey,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeviceListScreen(
                          openMonitoring: 'notifications'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String? username;

  const _WelcomeCard({this.username});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xush kelibsiz!',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  username ?? 'Ota-ona',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asosiy ekrandagi boshqaruv paneli qisqacha ko'rinishi.
///
/// To'liq panel alohida ekranda. Bu yerda faqat umumiy raqamlar —
/// foydalanuvchi asosiy ekranda qolib ham oila holatini ko'ra oladi.
class _DashboardPreview extends StatelessWidget {
  const _DashboardPreview();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DashboardProvider>();
    final dashboard = provider.dashboard;

    if (dashboard == null) {
      // Panel yuklanmagan bo'lsa — faqat kirish tugmasi. Bo'sh joy yoki
      // "0 farzand" ko'rsatish yolg'on bo'lardi (ma'lumot kelmagan).
      return Card(
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.dashboard, color: Colors.indigo[700], size: 32),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boshqaruv paneli',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Barcha farzandlarni bir ekranda ko\'rish',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
    }

    final summary = dashboard.summary;

    return Card(
      color: dashboard.hasActiveSos ? Colors.red[50] : null,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    dashboard.hasActiveSos ? Icons.sos : Icons.dashboard,
                    color: dashboard.hasActiveSos
                        ? Colors.red[700]
                        : Colors.indigo[700],
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dashboard.hasActiveSos
                          ? '${summary.activeSosCount} ta yordam signali!'
                          : '${summary.childrenCount} ta farzand · '
                              '${summary.onlineCount} ta faol qurilma',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: dashboard.hasActiveSos
                            ? Colors.red[900]
                            : null,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.schedule,
                      label: 'Bugun',
                      value: AppDateUtils.formatDuration(
                        summary.todayScreenTimeMs,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.block,
                      label: 'Bloklangan',
                      value: '${summary.blockedAppsCount}',
                    ),
                  ),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.battery_alert,
                      label: 'Batareya past',
                      value: '${summary.lowBatteryCount}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dashboard.hasChildren
                    ? 'Batafsil uchun bosing'
                    : 'Hali farzand ulanmagan — "Qurilma ulash" orqali boshlang',
                style: TextStyle(
                  fontSize: 11,
                  color: dashboard.hasChildren ? Colors.grey : Colors.orange[800],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
