import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../models/child_device.dart';
import '../../models/app_usage_log.dart';
import '../../providers/device_provider.dart';
import '../../core/utils/date_utils.dart';

class UsageScreen extends StatefulWidget {
  final ChildDevice device;

  const UsageScreen({super.key, required this.device});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceProvider>().loadUsageLogs(widget.device.id);
    });
  }

  /// Package bo'yicha guruhlab, umumiy vaqtni hisoblaydi
  Map<String, int> _aggregateByPackage(List<AppUsageLog> logs) {
    final Map<String, int> totals = {};
    for (final log in logs) {
      totals[log.packageName] =
          (totals[log.packageName] ?? 0) + log.totalTimeMs;
    }
    // Sort descending
    final sorted = Map.fromEntries(
      totals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)),
    );
    return sorted;
  }

  String _shortPackageName(String pkg) {
    final parts = pkg.split('.');
    if (parts.length >= 2) return parts.last;
    return pkg;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Foydalanish - ${widget.device.deviceName.isNotEmpty ? widget.device.deviceName : "Qurilma"}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<DeviceProvider>().loadUsageLogs(widget.device.id),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.usageLogs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart, size: 60, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('Foydalanish ma\'lumotlari topilmadi'),
                    ],
                  ),
                )
              : _UsageContent(
                  logs: provider.usageLogs,
                  aggregated: _aggregateByPackage(provider.usageLogs),
                  shortName: _shortPackageName,
                ),
    );
  }
}

class _UsageContent extends StatelessWidget {
  final List<AppUsageLog> logs;
  final Map<String, int> aggregated;
  final String Function(String) shortName;

  const _UsageContent({
    required this.logs,
    required this.aggregated,
    required this.shortName,
  });

  @override
  Widget build(BuildContext context) {
    final top5 = aggregated.entries.take(5).toList();
    final maxVal =
        top5.isEmpty ? 1 : top5.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    return RefreshIndicator(
      onRefresh: () =>
          context.read<DeviceProvider>().loadUsageLogs(logs.first.deviceId),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bar Chart
            if (top5.isNotEmpty) ...[
              Text(
                'Top 5 ilova (foydalanish vaqti)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: maxVal.toDouble() * 1.2,
                    barGroups: top5.asMap().entries.map((e) {
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.value.toDouble(),
                            color: colors[e.key % colors.length],
                            width: 24,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < top5.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  shortName(top5[idx].key),
                                  style: const TextStyle(fontSize: 10),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 30,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final minutes = (value / 60000).round();
                            return Text(
                              '${minutes}d',
                              style: const TextStyle(fontSize: 9),
                            );
                          },
                          reservedSize: 35,
                        ),
                      ),
                      topTitles:
                          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            // Total list
            Text(
              'Barcha ilovalar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...aggregated.entries.map((e) {
              final pct = maxVal > 0 ? e.value / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          AppDateUtils.formatDuration(e.value),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.toDouble(),
                        minHeight: 8,
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.teal.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
