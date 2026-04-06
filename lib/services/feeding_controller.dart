import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum FeedingMode { auto, custom, manual }

class FeedingController extends ChangeNotifier {
  // Singleton
  static final FeedingController _instance = FeedingController._internal();
  factory FeedingController() => _instance;
  FeedingController._internal();

  // Global instance getter
  static FeedingController get instance => _instance;

  // ===============================
  // STATE
  // ===============================
  FeedingMode _currentMode = FeedingMode.auto;
  DateTime? _lastFeedTime;
  List<String> _customTimes = ["08:00 AM", "08:00 PM"];

  // Getters - return unmodifiable copies to prevent direct mutation
  FeedingMode get currentMode => _currentMode;
  DateTime? get lastFeedTime => _lastFeedTime;
  List<String> get customTimes => List.unmodifiable(_customTimes);
  bool get isAutoMode => _currentMode == FeedingMode.auto;
  bool get isCustomMode => _currentMode == FeedingMode.custom;
  bool get isManualMode => _currentMode == FeedingMode.manual;

  // ===============================
  // TIMERS
  // ===============================
  Timer? _autoTimer8AM;
  Timer? _autoTimer8PM;
  final List<Timer> _customTimers = [];

  // ===============================
  // FIREBASE
  // ===============================
  late DatabaseReference _dbRef;
  bool _isFirebaseInitialized = false;
  StreamSubscription? _feedingSubscription;

  // ===============================
  // NOTIFICATIONS
  // ===============================
  late FlutterLocalNotificationsPlugin _notifications;
  DateTime? _lastNotificationTime;
  static const Duration notificationDebounce = Duration(minutes: 30);

  // ===============================
  // INITIALIZATION
  // ===============================
  Future<void> initialize({
    required FlutterLocalNotificationsPlugin notifications,
    required DatabaseReference dbRef,
  }) async {
    _notifications = notifications;
    _dbRef = dbRef;
    _isFirebaseInitialized = true;

    await _loadFromPreferences();
    await _loadLastNotificationTime();
    await _syncWithFirebase();
    _startTimersForCurrentMode();
    _listenToFirebase();
  }

  Future<void> _loadFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final modeIndex = prefs.getInt('selectedMode') ?? 0;
    _currentMode = FeedingMode.values[modeIndex];

    final savedTime = prefs.getString('lastFeedTime');
    if (savedTime != null) {
      _lastFeedTime = DateTime.parse(savedTime);
    }

    final savedCustomTimes = prefs.getStringList('customTimes');
    if (savedCustomTimes != null) {
      _customTimes = savedCustomTimes;
    }
  }

  Future<void> _loadLastNotificationTime() async {
    final prefs = await SharedPreferences.getInstance();
    final time = prefs.getInt('lastNotificationTime');
    if (time != null) {
      _lastNotificationTime = DateTime.fromMillisecondsSinceEpoch(time);
    }
  }

  Future<void> _saveLastNotificationTime() async {
    if (_lastNotificationTime == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'lastNotificationTime',
      _lastNotificationTime!.millisecondsSinceEpoch,
    );
  }

  Future<void> _syncWithFirebase() async {
    if (!_isFirebaseInitialized) return;

    try {
      final snapshot = await _dbRef.child('feeding').get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        bool shouldNotify = false;

        if (data.containsKey('mode')) {
          final modeStr = data['mode'] as String;
          final mode = FeedingMode.values.firstWhere(
                (e) => e.toString().split('.').last == modeStr,
            orElse: () => _currentMode,
          );
          if (mode != _currentMode) {
            _currentMode = mode;
            shouldNotify = true;
            _cancelAllTimers();
            _startTimersForCurrentMode();
          }
        }

        if (data.containsKey('lastFeedTime')) {
          final timestamp = data['lastFeedTime'] as int;
          final firebaseTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          if (_lastFeedTime == null || firebaseTime.isAfter(_lastFeedTime!)) {
            _lastFeedTime = firebaseTime;
            shouldNotify = true;
          }
        }

        if (data.containsKey('customTimes')) {
          final times = List<String>.from(data['customTimes']);
          if (times.length != _customTimes.length ||
              !times.every((t) => _customTimes.contains(t))) {
            _customTimes = times;
            shouldNotify = true;
          }
        }

        if (shouldNotify) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Firebase sync error: $e');
    }
  }

  void _listenToFirebase() {
    if (!_isFirebaseInitialized) return;

    _feedingSubscription = _dbRef.child('feeding').onValue.listen((event) {
      if (event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      bool shouldNotify = false;

      if (data.containsKey('mode')) {
        final modeStr = data['mode'] as String;
        final remoteMode = FeedingMode.values.firstWhere(
              (e) => e.toString().split('.').last == modeStr,
        );

        if (remoteMode != _currentMode) {
          _currentMode = remoteMode;
          shouldNotify = true;
          _cancelAllTimers();
          _startTimersForCurrentMode();
        }
      }

      if (data.containsKey('lastFeedTime')) {
        final timestamp = data['lastFeedTime'] as int;
        final remoteTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

        if (_lastFeedTime == null || remoteTime.isAfter(_lastFeedTime!)) {
          _lastFeedTime = remoteTime;
          shouldNotify = true;
        }
      }

      if (data.containsKey('customTimes')) {
        final times = List<String>.from(data['customTimes']);

        if (times.length != _customTimes.length ||
            !times.every((t) => _customTimes.contains(t))) {

          _customTimes = times;

          _cancelAllTimers();
          _startTimersForCurrentMode();

          shouldNotify = true;
        }
      }

      if (shouldNotify) {
        notifyListeners();
      }
    });
  }

  // ===============================
  // MODE MANAGEMENT
  // ===============================
  Future<void> setMode(FeedingMode mode, {bool fromRemote = false}) async {
    if (_currentMode == mode) return;

    _cancelAllTimers();
    _currentMode = mode;
    notifyListeners(); // UI update immediately

    _startTimersForCurrentMode();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selectedMode', mode.index);

    if (!fromRemote && _isFirebaseInitialized) {
      await _dbRef.child('feeding/mode').set(mode.toString().split('.').last);
    }
  }

  void _startTimersForCurrentMode() {
    switch (_currentMode) {
      case FeedingMode.auto:
        _startAutoTimers();
        break;
      case FeedingMode.custom:
        _startCustomTimers();
        break;
      case FeedingMode.manual:
        break;
    }
  }

  void _cancelAllTimers() {
    _autoTimer8AM?.cancel();
    _autoTimer8AM = null;
    _autoTimer8PM?.cancel();
    _autoTimer8PM = null;

    for (final timer in _customTimers) {
      timer.cancel();
    }
    _customTimers.clear();
  }

  // ===============================
  // AUTO MODE
  // ===============================
  void _startAutoTimers() {
    _scheduleAutoFeed(8, 0, isAM: true);
    _scheduleAutoFeed(20, 0, isAM: false);
  }

  void _scheduleAutoFeed(int hour, int minute, {required bool isAM}) {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final delay = scheduledTime.difference(now);

    final timer = Timer(delay, () async {
      if (_currentMode == FeedingMode.auto) {
        final success = await _performFeed(
          source: 'auto',
          notificationTitle: '🐠 Feeding Complete',
          notificationBody: 'Automatic feeding completed successfully.',
        );

        if (success) {
          _scheduleAutoFeed(hour, minute, isAM: isAM);
        }
      }
    });

    if (isAM) {
      _autoTimer8AM = timer;
    } else {
      _autoTimer8PM = timer;
    }
  }

  // ===============================
  // CUSTOM MODE
  // ===============================
  void _startCustomTimers() {
    for (final timeString in _customTimes) {
      _scheduleCustomFeed(timeString);
    }
  }

  void _scheduleCustomFeed(String timeString) {
    final time = _parseCustomTime(timeString);
    if (time == null) return;

    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final delay = scheduledTime.difference(now);

    final timer = Timer(delay, () async {
      if (_currentMode == FeedingMode.custom) {
        final success = await _performFeed(
          source: 'custom',
          notificationTitle: '🐠 Feeding Complete',
          notificationBody: 'Scheduled feeding completed successfully.',
        );

        if (success) {
          _scheduleCustomFeed(timeString);
        }
      }
    });

    _customTimers.add(timer);
  }

  TimeOfDay? _parseCustomTime(String timeString) {
    try {
      final match = RegExp(r'(\d+):(\d+)\s+(AM|PM)').firstMatch(timeString);
      if (match == null) return null;

      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)!;

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  bool _canFeedNow() {
    if (_lastFeedTime == null) return true;
    final diff = DateTime.now().difference(_lastFeedTime!);
    return diff.inHours >= 10;
  }

  // ===============================
  // CORE FEEDING LOGIC
  // ===============================
  Future<bool> _performFeed({
    required String source,
    required String notificationTitle,
    required String notificationBody,
  }) async {
    final now = DateTime.now();

    if (!_canFeedNow()) {
      debugPrint('Feed blocked: Less than 10 hours since last feed');
      return false;
    }

    _lastFeedTime = now;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastFeedTime', now.toIso8601String());

    if (_isFirebaseInitialized) {
      await _dbRef.child('feeding/lastFeedTime').set(now.millisecondsSinceEpoch);
    }

    await _showNotification(
      id: 1,
      title: notificationTitle,
      body: notificationBody,
      payload: source,
    );

    notifyListeners();
    return true;
  }

  Future<bool> manualFeed() async {
    if (_currentMode != FeedingMode.manual) return false;
    return await _performFeed(
      source: 'manual',
      notificationTitle: '🐠 Feeding Complete',
      notificationBody: 'Manual feeding completed successfully.',
    );
  }

  DateTime? getMostRecentFeedTime() {
    return _lastFeedTime;
  }

  // ===============================
  // CUSTOM TIMES MANAGEMENT
  // ===============================
  Future<void> addCustomTime(String timeString) async {
    if (_customTimes.contains(timeString)) return;

    _customTimes.add(timeString);
    _customTimes.sort(_compareTimes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('customTimes', _customTimes);

    if (_isFirebaseInitialized) {
      await _dbRef.child('feeding/customTimes').set(_customTimes);
    }

    if (_currentMode == FeedingMode.custom) {
      _cancelAllTimers();
      _startCustomTimers();
    }

    notifyListeners(); // CRITICAL: UI update immediately
  }

  Future<void> removeCustomTime(int index) async {
    if (index < 0 || index >= _customTimes.length) return;

    _customTimes.removeAt(index);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('customTimes', _customTimes);

    if (_isFirebaseInitialized) {
      await _dbRef.child('feeding/customTimes').set(_customTimes);
    }

    if (_currentMode == FeedingMode.custom) {
      _cancelAllTimers();
      _startCustomTimers();
    }

    notifyListeners(); // CRITICAL: UI update immediately
  }

  Future<void> updateCustomTime(int index, String newTime) async {
    if (index < 0 || index >= _customTimes.length) return;
    if (_customTimes.contains(newTime)) return;

    _customTimes[index] = newTime;
    _customTimes.sort(_compareTimes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('customTimes', _customTimes);

    if (_isFirebaseInitialized) {
      await _dbRef.child('feeding/customTimes').set(_customTimes);
    }

    if (_currentMode == FeedingMode.custom) {
      _cancelAllTimers();
      _startCustomTimers();
    }

    notifyListeners(); // CRITICAL: UI update immediately
  }

  int _compareTimes(String a, String b) {
    final timeA = _parseCustomTime(a);
    final timeB = _parseCustomTime(b);
    if (timeA == null || timeB == null) return 0;

    if (timeA.hour != timeB.hour) return timeA.hour.compareTo(timeB.hour);
    return timeA.minute.compareTo(timeB.minute);
  }

  // ===============================
  // NOTIFICATIONS
  // ===============================
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'blunest_channel',
      'BluNest Notifications',
      channelDescription: 'Feeding and water quality alerts',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Future<void> showParameterAlert({
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();

    if (_lastNotificationTime != null) {
      if (now.difference(_lastNotificationTime!) < notificationDebounce) {
        return;
      }
    }

    await _showNotification(
      id: title.hashCode,
      title: title,
      body: body,
      payload: 'parameter_alert',
    );

    _lastNotificationTime = now;
    await _saveLastNotificationTime();
  }

  // ===============================
  // UTILITY
  // ===============================
  String formatTime(DateTime time) {
    int hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute $period';
  }

  DateTime? parseCustomTimeToDateTime(String timeString, {DateTime? referenceDate}) {
    final time = _parseCustomTime(timeString);
    if (time == null) return null;

    final date = referenceDate ?? DateTime.now();
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  void dispose() {
    _feedingSubscription?.cancel();
    _cancelAllTimers();
    super.dispose();
  }
}