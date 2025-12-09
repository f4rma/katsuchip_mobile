import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'admin_appbar_actions.dart';

class MenuSales {
  final String name;
  final int quantity;
  final double revenue;
  
  MenuSales({
    required this.name,
    required this.quantity,
    required this.revenue,
  });
}

class AdminReportsPage extends StatelessWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orange = const Color(0xFFFF7A00);
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        title: const Text('Laporan Penjualan'),
        backgroundColor: orange,
        foregroundColor: Colors.white,
        actions: adminAppBarActions(context),
      ),
      body: FutureBuilder<_Report>(
        future: _Report.loadLast30Days(),
        builder: (context, snap) {
          if (snap.hasError) {
            final err = snap.error;
            String msg = 'Gagal memuat laporan';
            if (err is FirebaseException) {
              msg = err.message ?? msg;
            }
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),
                    const SizedBox(height: 10),
                    Text(msg, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text(
                      'Pastikan aturan Firestore mengizinkan admin membaca collectionGroup("orders").',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _metric('Total Pendapatan', r.revenue, color: Colors.green),
              const SizedBox(height: 10),
              _metric('Total Pesanan', r.count.toDouble(), color: Colors.blue),
              const SizedBox(height: 10),
              _metric('Menu Terjual (item)', r.totalItemsSold.toDouble(), color: orange),
              const SizedBox(height: 16),
              _SalesChart(dailyData: r.dailyRevenue),
              const SizedBox(height: 16),
              _TopMenusChart(topMenus: r.topMenus),
            ],
          );
        },
      ),
    );
  }

  Widget _metric(String label, double v, {Color color = Colors.orange}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
  CircleAvatar(backgroundColor: color.withValues(alpha: .15), child: Icon(Icons.bar_chart_rounded, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(label.contains('Pendapatan') ? _rupiah(v) : v.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ])),
      ]),
    );
  }
}

class _Report {
  final int count;
  final double revenue;
  final int totalItemsSold;
  final Map<int, double> dailyRevenue; // day -> revenue
  final List<MenuSales> topMenus; // top selling menus
  
  _Report({
    required this.count, 
    required this.revenue, 
    required this.totalItemsSold,
    required this.dailyRevenue,
    required this.topMenus,
  });

  static Future<_Report> loadLast30Days() async {
    final now = DateTime.now();
    final since = now.subtract(const Duration(days: 30));
    final db = FirebaseFirestore.instance;
    QuerySnapshot<Map<String, dynamic>> qs;
    try {
      // Jalur utama: butuh single-field index COLLECTION_GROUP_ASC(createdAt)
      qs = await db
          .collectionGroup('orders')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .get();
    } on FirebaseException catch (e) {
      // Fallback sementara bila index ASC belum siap: ambil DESC (butuh index DESC)
      // lalu filter di memori. Batasi jumlah untuk menjaga performa.
      if (e.code == 'failed-precondition') {
        qs = await db
            .collectionGroup('orders')
            .orderBy('createdAt', descending: true)
            .limit(1000)
            .get();
      } else {
        rethrow;
      }
    }

    int count = 0;
    double revenue = 0;
    int items = 0;
    final Map<int, double> dailyRevenue = {}; // daysAgo -> revenue
    final Map<String, MenuSales> menuSalesMap = {}; // menuName -> MenuSales
    final sinceMs = since.millisecondsSinceEpoch;
    
    for (final d in qs.docs) {
      final data = d.data();
      final ts = data['createdAt'];
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();
      if (ts is int) dt = DateTime.fromMillisecondsSinceEpoch(ts);
      if (ts is num) dt = DateTime.fromMillisecondsSinceEpoch(ts.toInt());
      if (dt == null || dt.millisecondsSinceEpoch < sinceMs) {
        // Jika fallback DESC, dokumen lebih lama dari 30 hari akan di-skip
        continue;
      }
      
      count += 1;
      final orderTotal = ((data['total'] ?? 0) as num).toDouble();
      revenue += orderTotal;
      
      // Hitung hari ke belakang dari sekarang (0 = hari ini, 1 = kemarin, dst)
      final daysAgo = now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      dailyRevenue[daysAgo] = (dailyRevenue[daysAgo] ?? 0) + orderTotal;
      
      final its = (data['items'] as List?) ?? const [];
      for (final it in its) {
        final itemMap = it as Map;
        final qty = ((itemMap['qty'] ?? 0) as num).toInt();
        final name = (itemMap['name'] ?? 'Unknown') as String;
        final price = ((itemMap['price'] ?? 0) as num).toDouble();
        final itemRevenue = price * qty;
        
        items += qty;
        
        // Aggregate menu sales
        if (menuSalesMap.containsKey(name)) {
          final existing = menuSalesMap[name]!;
          menuSalesMap[name] = MenuSales(
            name: name,
            quantity: existing.quantity + qty,
            revenue: existing.revenue + itemRevenue,
          );
        } else {
          menuSalesMap[name] = MenuSales(
            name: name,
            quantity: qty,
            revenue: itemRevenue,
          );
        }
      }
    }
    
    // Sort by quantity dan ambil top 5
    final topMenus = menuSalesMap.values.toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    final top5 = topMenus.take(5).toList();
    
    return _Report(
      count: count, 
      revenue: revenue, 
      totalItemsSold: items,
      dailyRevenue: dailyRevenue,
      topMenus: top5,
    );
  }
}

String _rupiah(num n) {
  final s = n.toInt().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final idx = s.length - i;
    b.write(s[i]);
    if (idx > 1 && idx % 3 == 1) b.write('.');
  }
  return 'Rp $b';
}

class _SalesChart extends StatelessWidget {
  final Map<int, double> dailyData; // daysAgo -> revenue
  
  const _SalesChart({required this.dailyData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grafik Penjualan 30 Hari Terakhir',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: dailyData.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada data penjualan',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : LineChart(
                    _buildLineChartData(),
                  ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, size: 10, color: Color(0xFFFF7A00)),
              SizedBox(width: 6),
              Text(
                'Pendapatan Harian',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData() {
    // Siapkan data untuk 30 hari (dari hari ini mundur 29 hari)
    final List<FlSpot> spots = [];
    double maxY = 0;
    
    // Loop dari hari ini (daysAgo=0) sampai 29 hari lalu (daysAgo=29)
    for (int daysAgo = 29; daysAgo >= 0; daysAgo--) {
      final revenue = dailyData[daysAgo] ?? 0;
      // X-axis: 0 = 30 hari lalu, 29 = hari ini
      final xValue = (29 - daysAgo).toDouble();
      spots.add(FlSpot(xValue, revenue));
      if (revenue > maxY) maxY = revenue;
    }

    // Jika tidak ada data, set default
    if (maxY == 0) maxY = 100000;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY / 4,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              // Format Y-axis (revenue)
              if (value == 0) return const Text('0');
              final k = value / 1000;
              return Text(
                '${k.toStringAsFixed(0)}k',
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 5, // Tampilkan setiap 5 hari
            getTitlesWidget: (value, meta) {
              // value: 0 = 30 hari lalu, 29 = hari ini
              final daysAgo = 29 - value.toInt();
              
              // Tampilkan label setiap 5 hari
              if (value % 5 != 0 && value != 29) {
                return const SizedBox.shrink();
              }
              
              if (value == 29) {
                return const Text(
                  'Hari ini',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                );
              }
              
              return Text(
                '-${daysAgo}h',
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      minX: 0,
      maxX: 29,
      minY: 0,
      maxY: maxY * 1.2, // Tambah 20% padding atas
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: const Color(0xFFFF7A00),
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 3,
                color: const Color(0xFFFF7A00),
                strokeWidth: 1,
                strokeColor: Colors.white,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFFFF7A00).withOpacity(0.1),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (spot) => Colors.black87,
          tooltipRoundedRadius: 8,
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((spot) {
              final daysAgo = 29 - spot.x.toInt();
              final date = DateTime.now().subtract(Duration(days: daysAgo));
              final dateStr = '${date.day}/${date.month}';
              
              return LineTooltipItem(
                '$dateStr\n${_rupiah(spot.y)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }
}

class _TopMenusChart extends StatelessWidget {
  final List<MenuSales> topMenus;
  
  const _TopMenusChart({required this.topMenus});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 Menu Terlaris',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: topMenus.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada data penjualan',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : BarChart(
                    _buildBarChartData(),
                  ),
          ),
        ],
      ),
    );
  }

  BarChartData _buildBarChartData() {
    final barGroups = <BarChartGroupData>[];
    int maxQty = 0;
    
    for (int i = 0; i < topMenus.length; i++) {
      final menu = topMenus[i];
      if (menu.quantity > maxQty) maxQty = menu.quantity;
      
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: menu.quantity.toDouble(),
              color: const Color(0xFFFF7A00),
              width: 40,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxQty * 1.1,
                color: Colors.grey.shade100,
              ),
            ),
          ],
        ),
      );
    }

    return BarChartData(
      alignment: BarChartAlignment.spaceEvenly,
      maxY: maxQty * 1.2,
      minY: 0,
      groupsSpace: 20,
      barGroups: barGroups,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxQty > 0 ? (maxQty / 4) : 1,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              if (value == 0) return const Text('0');
              return Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 60,
            getTitlesWidget: (value, meta) {
              if (value.toInt() >= topMenus.length) {
                return const SizedBox.shrink();
              }
              
              final menu = topMenus[value.toInt()];
              final name = menu.name;
              
              // Truncate nama menu jika terlalu panjang
              final displayName = name.length > 15 
                  ? '${name.substring(0, 12)}...' 
                  : name;
              
              return SideTitleWidget(
                axisSide: meta.axisSide,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          left: BorderSide(color: Colors.grey.shade300),
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => Colors.black87,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.all(8),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final menu = topMenus[group.x.toInt()];
            return BarTooltipItem(
              '${menu.name}\n',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: 'Terjual: ${menu.quantity} item\n',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                TextSpan(
                  text: 'Revenue: ${_rupiah(menu.revenue)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
