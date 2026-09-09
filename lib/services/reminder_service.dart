import 'admin_tracking_service.dart';

class TrainingReminder {
  final TrainingProgress training;
  final int daysRemaining;
  final String level;

  const TrainingReminder({
    required this.training,
    required this.daysRemaining,
    required this.level,
  });
}

class ReminderService {
  Future<List<TrainingReminder>> loadAlerts() async {
    final trainings = await AdminTrackingService().loadTrainings();
    final today = _dateOnly(DateTime.now());
    final alerts = <TrainingReminder>[];
    for (final training in trainings) {
      if (training.pending <= 0 || training.status == 'CERRADO') continue;
      final deadline = _dateOnly(training.deadline.toLocal());
      final days = deadline.difference(today).inDays;
      final level = days < 0
          ? 'VENCIDO'
          : days <= 5
              ? 'CRÍTICO'
              : days <= 10
                  ? 'PRÓXIMO'
                  : 'EN PLAZO';
      alerts.add(TrainingReminder(
        training: training,
        daysRemaining: days,
        level: level,
      ));
    }
    alerts.sort((a, b) {
      final byDays = a.daysRemaining.compareTo(b.daysRemaining);
      return byDays != 0
          ? byDays
          : a.training.course.compareTo(b.training.course);
    });
    return alerts;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
