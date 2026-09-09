import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'admin_tracking_service.dart';
import 'reminder_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final Set<String> _shownToday = {};
  bool _initialized = false;
  bool _permissionRequested = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showAdminReminder(List<TrainingReminder> alerts) async {
    if (alerts.isEmpty || !_markOnce('admin')) return;
    await _prepareAndroid();
    final overdue = alerts.where((item) => item.level == 'VENCIDO').length;
    final critical = alerts.where((item) => item.level == 'CRÍTICO').length;
    final pending = alerts.fold<int>(
      0,
      (total, item) => total + item.training.pending,
    );
    await _show(
      1601,
      'Alertas SSOMA pendientes',
      '$pending firmas pendientes. $overdue capacitaciones vencidas y $critical próximas a vencer.',
    );
  }

  Future<void> showWorkerReminder(List<AssignedTraining> trainings) async {
    final pending = trainings.where((item) => item.canSign).toList();
    if (pending.isEmpty || !_markOnce('worker')) return;
    await _prepareAndroid();
    pending.sort((a, b) => a.deadline.compareTo(b.deadline));
    final nearest = pending.first.deadline.toLocal();
    await _show(
      1602,
      'Tienes firmas SSOMA pendientes',
      '${pending.length} ${pending.length == 1 ? 'capacitación requiere' : 'capacitaciones requieren'} tu firma. Próximo plazo: ${_date(nearest)}.',
    );
  }

  Future<void> _prepareAndroid() async {
    await initialize();
    if (_permissionRequested) return;
    _permissionRequested = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _show(int id, String title, String body) => _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'ssoma_reminders',
            'Recordatorios SSOMA',
            channelDescription:
                'Alertas de capacitaciones y firmas SSOMA pendientes',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );

  bool _markOnce(String audience) {
    final now = DateTime.now();
    return _shownToday.add('$audience-${now.year}-${now.month}-${now.day}');
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
