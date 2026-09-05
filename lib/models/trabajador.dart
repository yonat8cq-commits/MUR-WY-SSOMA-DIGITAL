class Trabajador {
  final String dni;
  final String nombres;
  final String cargo;
  final String area;

  Trabajador({
    required this.dni,
    required this.nombres,
    required this.cargo,
    required this.area,
  });

  Map<String, dynamic> toMap() => {
    'dni': dni,
    'nombres': nombres,
    'cargo': cargo,
    'area': area,
  };
}
