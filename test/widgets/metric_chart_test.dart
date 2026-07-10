import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:aricie/widgets/metric_chart.dart';

void main() {
  group('MetricChart Widget', () {
    testWidgets('renders title and LineChart correctly', (WidgetTester tester) async {
      final dataPoints = [
        const FlSpot(0, 1.2),
        const FlSpot(1, 2.5),
        const FlSpot(2, 1.8),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricChart(
              data: dataPoints,
              title: 'Consommation Électrique',
              color: Colors.blue,
            ),
          ),
        ),
      );

      // Verify that the title is rendered
      expect(find.text('Consommation Électrique'), findsOneWidget);

      // Verify that the LineChart is rendered
      expect(find.byType(LineChart), findsOneWidget);
    });
  });
}
