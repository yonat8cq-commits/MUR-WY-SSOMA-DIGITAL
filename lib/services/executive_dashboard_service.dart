import 'admin_tracking_service.dart';
import 'worker_admin_service.dart';

class ExecutiveSummary {
  final int workers;
  final int activeWorkers;
  final int trainings;
  final int signed;
  final int pending;
  final int completed;
  final int expired;
  final int closed;

  const ExecutiveSummary({required this.workers, required this.activeWorkers,
    required this.trainings, required this.signed, required this.pending,
    required this.completed, required this.expired, required this.closed});

  double get signatureProgress =>
      signed + pending == 0 ? 0 : signed / (signed + pending);
}

class ExecutiveDashboardService {
  Future<ExecutiveSummary> load() async {
    final workers = await WorkerAdminService().loadWorkers();
    final trainings = await AdminTrackingService().loadTrainings();
    return ExecutiveSummary(
      workers: workers.length,
      activeWorkers: workers.where((item) => item.active).length,
      trainings: trainings.length,
      signed: trainings.fold(0, (total, item) => total + item.signed),
      pending: trainings.fold(0, (total, item) => total + item.pending),
      completed: trainings.where((item) => item.status == 'COMPLETO').length,
      expired: trainings.where((item) => item.status == 'VENCIDO').length,
      closed: trainings.where((item) => item.status == 'CERRADO').length,
    );
  }
}
