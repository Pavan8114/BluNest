import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:blunest/services/feeding_controller.dart';
import 'package:blunest/main.dart' as app;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // ===============================
  // CONTROLLER - Use singleton instance
  // ===============================
  final FeedingController _controller = FeedingController();

  // ===============================
  // LOCAL STATE
  // ===============================
  String currentCareMode = "care";
  int currentCarouselIndex = 0;
  int feedCount = 2;

  // Fixed height for feeding card content
  static const double feedingContentHeight = 80;

  // ===============================
  // ANIMATION CONTROLLERS
  // ===============================
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _showWarning = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _initShakeAnimation();
    _initializeFeedingController();
    _startSensorMonitoring();
  }

  Future<void> _initializeFeedingController() async {
    final dbRef = FirebaseDatabase.instance.ref();

    await _controller.initialize(
      notifications: app.flutterLocalNotificationsPlugin,
      dbRef: dbRef,
    );
  }

  void _initShakeAnimation() {
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -14), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -14, end: 14), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 14, end: -14), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -14, end: 14), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 14, end: 0), weight: 1),
    ]).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  // ===============================
  // SENSOR MONITORING
  // ===============================
  void _startSensorMonitoring() {
    Future.delayed(const Duration(seconds: 30), _checkSensorAlerts);
  }

  void _checkSensorAlerts() {
    // Temperature checks
    final tempSensor = sensors.firstWhere((s) => s['id'] == 'tempCard');
    final tempValue = tempSensor['currentValue'];

    if (tempValue < 75) {
      _controller.showParameterAlert(
        title: '🌡 Temperature Alert',
        body: 'Water temperature is below optimal range.',
      );
    } else if (tempValue > 85) {
      _controller.showParameterAlert(
        title: '🌡 Temperature Alert',
        body: 'Water temperature is above optimal range.',
      );
    }

    // Clarity checks
    final claritySensor = sensors.firstWhere((s) => s['id'] == 'clarityCard');
    final clarityValue = claritySensor['currentValue'];

    if (clarityValue < 60) {
      _controller.showParameterAlert(
        title: '💧 Water Clarity Alert',
        body: 'Water turbidity is higher than recommended.',
      );
    }

    // Cleanliness checks
    final cleanlinessSensor = sensors.firstWhere((s) => s['id'] == 'cleanlinessCard');
    final cleanlinessValue = cleanlinessSensor['currentValue'];

    if (cleanlinessValue < 70) {
      _controller.showParameterAlert(
        title: '⚗ Water Quality Alert',
        body: 'TDS level is above safe limit.',
      );
    }

    // pH checks
    final balanceSensor = sensors.firstWhere((s) => s['id'] == 'balanceCard');
    final balanceValue = balanceSensor['currentValue'];

    if (balanceValue < 6.5) {
      _controller.showParameterAlert(
        title: '🧪 pH Alert',
        body: 'pH level is below optimal range.',
      );
    } else if (balanceValue > 7.5) {
      _controller.showParameterAlert(
        title: '🧪 pH Alert',
        body: 'pH level is above optimal range.',
      );
    }

    // Schedule next check
    Future.delayed(const Duration(minutes: 1), _checkSensorAlerts);
  }

  // ===============================
  // CARE/EXPERT TOGGLE
  // ===============================
  void toggleCareMode(bool value) {
    setState(() {
      currentCareMode = value ? "expert" : "care";
    });
  }

  // ===============================
  // SENSOR DATA
  // ===============================
  final List<Map<String, dynamic>> sensors = [
    {
      'id': 'tempCard',
      'title': 'Temperature',
      'currentValue': 78,
      'states': [
        {
          'range': [0, 75],
          'care': {'status': 'Too Cold', 'message': 'Water is colder than ideal.'},
          'expert': '74°F',
        },
        {
          'range': [75, 85],
          'care': {'status': 'Excellent', 'message': 'Perfect for your fish.'},
          'expert': '78°F',
        },
        {
          'range': [85, 200],
          'care': {'status': 'Too Hot', 'message': 'Water is warmer than ideal.'},
          'expert': '92°F',
        },
      ],
    },
    {
      'id': 'cleanlinessCard',
      'title': 'Water Cleanliness',
      'currentValue': 82,
      'states': [
        {
          'range': [0, 70],
          'care': {'status': 'Poor', 'message': 'Water needs cleaning.'},
          'expert': '65%',
        },
        {
          'range': [70, 90],
          'care': {'status': 'Good', 'message': 'Water is clean.'},
          'expert': '82%',
        },
        {
          'range': [90, 100],
          'care': {'status': 'Excellent', 'message': 'Water is pristine.'},
          'expert': '95%',
        },
      ],
    },
    {
      'id': 'clarityCard',
      'title': 'Water Clarity',
      'currentValue': 88,
      'states': [
        {
          'range': [0, 60],
          'care': {'status': 'Cloudy', 'message': 'Water appears cloudy.'},
          'expert': '45%',
        },
        {
          'range': [60, 85],
          'care': {'status': 'Fair', 'message': 'Slight haze visible.'},
          'expert': '72%',
        },
        {
          'range': [85, 100],
          'care': {'status': 'Good', 'message': 'Clear water.'},
          'expert': '88%',
        },
      ],
    },
    {
      'id': 'balanceCard',
      'title': 'Water Balance',
      'currentValue': 7.2,
      'states': [
        {
          'range': [0, 6.5],
          'care': {'status': 'Acidic', 'message': 'pH is too low.'},
          'expert': '6.2 pH',
        },
        {
          'range': [6.5, 7.5],
          'care': {'status': 'Healthy', 'message': 'Stable conditions.'},
          'expert': '7.2 pH',
        },
        {
          'range': [7.5, 14],
          'care': {'status': 'Alkaline', 'message': 'pH is too high.'},
          'expert': '8.1 pH',
        },
      ],
    },
  ];

  Map<String, dynamic> getSensorState(Map<String, dynamic> sensor, double value) {
    for (var state in sensor['states']) {
      final range = state['range'] as List;
      if (value >= range[0] && value < range[1]) {
        return state;
      }
    }
    return sensor['states'].last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf5f7fa),
      body: SafeArea(
        child: Center(
          child: Container(
            width: 390,
            color: Colors.white,
            child: Column(
              children: [
                // Header
                Container(
                  color: const Color(0xFFCAF0F8),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        'assets/images/typo.png',
                        height: 32,
                      ),
                      _buildToggleSwitch(),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Carousel Section
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _buildCarousel(),
                        ),
                        // Chart Container (Expert Mode)
                        if (currentCareMode == 'expert')
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildChartCard(),
                          ),
                        // Feeding Card - WRAPPED WITH ANIMATEDBUILDER
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) {
                              return _buildFeedingCard();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  width: double.infinity,
                  color: const Color(0xFFCAF0F8),
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    'Pathway Pioneers',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00B4D8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSwitch() {
    return GestureDetector(
      onTap: () => toggleCareMode(!(currentCareMode == 'expert')),
      child: Container(
        width: 56,
        height: 32,
        decoration: BoxDecoration(
          color: currentCareMode == 'expert'
              ? const Color(0xff00b4d8)
              : const Color(0xFFcccccc),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: currentCareMode == 'expert' ? 24 : 4,
              top: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarousel() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: CarouselSlider(
            options: CarouselOptions(
              height: 220,
              viewportFraction: 0.95,
              enableInfiniteScroll: false,
              onPageChanged: (index, reason) {
                setState(() {
                  currentCarouselIndex = index;
                });
              },
            ),
            items: sensors.map((sensor) {
              final state = getSensorState(sensor, sensor['currentValue'].toDouble());

              String statusText;
              String messageText;

              if (currentCareMode == 'care') {
                statusText = state['care']['status'];
                messageText = state['care']['message'];
              } else {
                if (sensor['id'] == 'tempCard') {
                  statusText = '28.87°C';
                } else {
                  statusText = state['expert'];
                }
                messageText = state['care']['message'];
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sensor['title'],
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      statusText,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16a34a),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      messageText,
                      style: const TextStyle(
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSmoothIndicator(
          activeIndex: currentCarouselIndex,
          count: sensors.length,
          effect: ExpandingDotsEffect(
            expansionFactor: 3.5,
            dotHeight: 8,
            dotWidth: 8,
            spacing: 6,
            radius: 12,
            dotColor: const Color(0xFFcbd5e1),
            activeDotColor: const Color(0xff00b4d8),
          ),
          onDotClicked: (index) {},
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Water Quality Trends',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 20,
                  verticalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0x0D000000),
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: const Color(0x0D000000),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(
                            days[value.toInt()],
                            style: const TextStyle(
                              color: Color(0xFF64748b),
                              fontSize: 12,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                            color: Color(0xFF64748b),
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: const Color(0x1A000000),
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 100,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 70),
                      FlSpot(1, 75),
                      FlSpot(2, 80),
                      FlSpot(3, 78),
                      FlSpot(4, 85),
                      FlSpot(5, 90),
                      FlSpot(6, 88),
                    ],
                    isCurved: true,
                    color: const Color(0xFFef4444),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFFef4444),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 30),
                      FlSpot(1, 40),
                      FlSpot(2, 35),
                      FlSpot(3, 50),
                      FlSpot(4, 45),
                      FlSpot(5, 55),
                      FlSpot(6, 60),
                    ],
                    isCurved: true,
                    color: const Color(0xFF84cc16),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF84cc16),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 60),
                      FlSpot(1, 65),
                      FlSpot(2, 70),
                      FlSpot(3, 75),
                      FlSpot(4, 72),
                      FlSpot(5, 68),
                      FlSpot(6, 66),
                    ],
                    isCurved: true,
                    color: const Color(0xff00b4d8),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xff00b4d8),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 50),
                      FlSpot(1, 52),
                      FlSpot(2, 55),
                      FlSpot(3, 53),
                      FlSpot(4, 54),
                      FlSpot(5, 56),
                      FlSpot(6, 58),
                    ],
                    isCurved: true,
                    color: const Color(0xFFeab308),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFFeab308),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with + button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Feeding Control',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Mode: ${_controller.isAutoMode ? 'Auto' : _controller.isCustomMode ? 'Custom' : 'Manual'}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              if (_controller.isCustomMode)
                InkWell(
                  onTap: () => _showTimePickerDialog(),
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF00B4D8), width: 2),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Center(
                      child: Text(
                        '+',
                        style: TextStyle(
                          fontSize: 24,
                          color: Color(0xFF00B4D8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Segmented Control with animated background
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFf1f5f9),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(4),
            child: Stack(
              children: [
                // Animated sliding background
                AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: Alignment(
                      _controller.isAutoMode ? -1.0 :
                      _controller.isCustomMode ? 0.0 : 1.0,
                      0
                  ),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 90) / 3,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCAF0F8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // Buttons
                Row(
                  children: [
                    _buildSegment('Auto', FeedingMode.auto),
                    _buildSegment('Custom', FeedingMode.custom),
                    _buildSegment('Manual', FeedingMode.manual),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Fixed height content area
          SizedBox(
            height: feedingContentHeight,
            child: Container(
              key: ValueKey(_controller.currentMode),
              alignment: Alignment.topLeft,
              child: _buildModeContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(String text, FeedingMode mode) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _controller.setMode(mode),
        child: Stack(
          children: [
            if (_controller.currentMode == mode)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFCAF0F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF00B4D8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeContent() {
    if (_controller.isAutoMode) return _buildAutoMode();
    if (_controller.isCustomMode) return _buildCustomMode();
    return _buildManualMode();
  }

  Widget _buildAutoMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Feeds per day: ',
              style: TextStyle(fontSize: 18, color: Color(0xFF555555)),
            ),
            Text(
              '2',
              style: const TextStyle(fontSize: 18, color: Color(0xFF555555)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Fixed times: 08:00 AM, 08:00 PM',
          style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
        ),
      ],
    );
  }

  Widget _buildCustomMode() {
    final times = _controller.customTimes;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ...times.asMap().entries.map((entry) {
          final index = entry.key;
          final time = entry.value;
          return InkWell(
            onTap: () => _showTimePickerDialog(existingTime: time, index: index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFf1f5f9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildManualMode() {
    String displayText;
    if (_showWarning) {
      displayText = "⚠️ It's not 10 hours yet. Avoid overfeeding your fish.";
    } else {
      final lastFeed = _controller.getMostRecentFeedTime();
      if (lastFeed != null) {
        displayText = 'Last fed at ${_controller.formatTime(lastFeed)}';
      } else {
        displayText = 'Last fed at 08:00 AM';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) async {
            setState(() => _isPressed = false);
            final success = await _controller.manualFeed();
            if (!success && mounted) {
              setState(() => _showWarning = true);
              _shakeController.forward();
              await Future.delayed(const Duration(seconds: 3));
              if (mounted) {
                setState(() => _showWarning = false);
                _shakeController.reset();
              }
            }
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _isPressed
                    ? const Color(0xFF00B4D8).withValues(alpha: 0.15)
                    : Colors.transparent,
                border: Border.all(
                  color: const Color(0xFF00B4D8),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'Feed Now',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF00B4D8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: AnimatedBuilder(
            key: ValueKey(_showWarning),
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_showWarning ? _shakeAnimation.value : 0, 0),
                child: child,
              );
            },
            child: SizedBox(
              width: double.infinity,
              child: Text(
                displayText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _showWarning
                      ? const Color(0xFFef4444)
                      : const Color(0xFF666666),
                  fontWeight:
                  _showWarning ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showTimePickerDialog({String? existingTime, int? index}) async {
    if (existingTime != null) {
      return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Edit Time'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose an option:'),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showTimePickerForEdit(existingTime, index);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B4D8),
                      ),
                      child: const Text('Edit'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _controller.removeCustomTime(index!);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFef4444),
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } else {
      return _showTimePickerForEdit(null, null);
    }
  }

  Future<void> _showTimePickerForEdit(String? existingTime, int? index) async {
    TimeOfDay initialTime = const TimeOfDay(hour: 8, minute: 0);

    if (existingTime != null) {
      final match = RegExp(r'(\d+):(\d+)\s+(AM|PM)').firstMatch(existingTime);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        final period = match.group(3)!;

        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;

        initialTime = TimeOfDay(hour: hour, minute: minute);
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00B4D8),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF333333),
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Colors.white,
            ),
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteColor: Color(0xFFf1f5f9),
              hourMinuteTextColor: Color(0xFF00B4D8),
              dayPeriodColor: Color(0xFFf1f5f9),
              dayPeriodTextColor: Color(0xFF00B4D8),
              dialHandColor: Color(0xFF00B4D8),
              dialBackgroundColor: Color(0xFFf1f5f9),
              dialTextColor: Color(0xFF333333),
              entryModeIconColor: Color(0xFF00B4D8),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      final period = picked.hour >= 12 ? 'PM' : 'AM';
      final hour = picked.hour % 12 == 0 ? 12 : picked.hour % 12;
      final timeString = '${hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')} $period';

      // Check for duplicates
      if (existingTime == null && _controller.customTimes.contains(timeString)) {
        _showErrorDialog('⚠️ This time already exists!');
        return;
      }

      // Check 10-hour gap with existing times
      final newTime = _controller.parseCustomTimeToDateTime(timeString);
      if (newTime != null) {
        for (final time in _controller.customTimes) {
          if (existingTime != null && time == existingTime) continue;
          final existingDateTime = _controller.parseCustomTimeToDateTime(time);
          if (existingDateTime != null) {
            final diff = (newTime.difference(existingDateTime).inHours).abs();
            if (diff < 10 && diff > 0) {
              _showErrorDialog('⚠️ Cannot add time within 10 hours of $time');
              return;
            }
          }
        }
      }

      if (existingTime != null) {
        await _controller.updateCustomTime(index!, timeString);
      } else {
        await _controller.addCustomTime(timeString);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Caution'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}