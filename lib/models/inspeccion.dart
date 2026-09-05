class Inspeccion {
  final String fecha;
  final String area;
  final String hallazgo;
  final String accionCorrectiva;
  final String evidencia;
  final String responsable;

  Inspeccion({
    required this.fecha,
    required this.area,
    required this.hallazgo,
    required this.accionCorrectiva,
    required this.evidencia,
    required this.responsable,
  });

  Map<String, dynamic> toMap() => {
    'fecha': fecha,
    'area': area,
    'hallazgo': hallazgo,
    'accionCorrectiva': accionCorrectiva,
    'evidencia': evidencia,
    'responsable': responsable,
  };
}
