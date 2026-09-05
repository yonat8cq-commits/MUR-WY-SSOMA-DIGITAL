class Capacitacion {
  final String titulo;
  final String fecha;
  final String instructor;

  Capacitacion({
    required this.titulo,
    required this.fecha,
    required this.instructor,
  });

  Map<String, dynamic> toMap() => {
    'titulo': titulo,
    'fecha': fecha,
    'instructor': instructor,
  };
}
