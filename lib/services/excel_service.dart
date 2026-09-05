class ExcelService {
  Future<String> exportInspection(List<Map<String, dynamic>> data) async {
    // Base service for Excel export.
    // Will integrate XLSX generation package.
    return 'Registros exportados: ${data.length}';
  }
}
