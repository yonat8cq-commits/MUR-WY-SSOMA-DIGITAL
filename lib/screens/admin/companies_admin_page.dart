import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../services/company_service.dart';

class CompaniesAdminPage extends StatefulWidget {
  const CompaniesAdminPage({super.key});

  @override
  State<CompaniesAdminPage> createState() => _CompaniesAdminPageState();
}

class _CompaniesAdminPageState extends State<CompaniesAdminPage> {
  final _service = CompanyService();
  List<CompanyProfile> _companies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final companies = await _service.loadCompanies();
    if (!mounted) return;
    setState(() {
      _companies = companies;
      _loading = false;
    });
  }

  Future<void> _edit(CompanyProfile? company) async {
    final name = TextEditingController(text: company?.businessName ?? '');
    final ruc = TextEditingController(text: company?.ruc ?? '');
    final address = TextEditingController(text: company?.address ?? '');
    final activity =
        TextEditingController(text: company?.economicActivity ?? '');
    final employees = TextEditingController(
      text: (company?.employeeCount ?? 0).toString(),
    );
    Uint8List? selectedLogo;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(company == null ? 'Agregar empresa' : 'Editar empresa'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 90,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: selectedLogo != null
                        ? Image.memory(selectedLogo!, fit: BoxFit.contain)
                        : company?.logoPng != null
                            ? Image.memory(company!.logoPng!, fit: BoxFit.contain)
                            : const Text('LOGO NO CARGADO'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      const types = XTypeGroup(
                        label: 'Logo',
                        extensions: ['png', 'jpg', 'jpeg'],
                        mimeTypes: ['image/png', 'image/jpeg'],
                      );
                      final file =
                          await openFile(acceptedTypeGroups: const [types]);
                      if (file == null) return;
                      final bytes = await file.readAsBytes();
                      setDialogState(() => selectedLogo = bytes);
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('SELECCIONAR LOGO'),
                  ),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Razón social'),
                  ),
                  TextField(
                    controller: ruc,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'RUC'),
                  ),
                  TextField(
                    controller: address,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Domicilio'),
                  ),
                  TextField(
                    controller: activity,
                    decoration:
                        const InputDecoration(labelText: 'Actividad económica'),
                  ),
                  TextField(
                    controller: employees,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'N° de trabajadores del centro laboral',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await _service.save(
                  id: company?.id,
                  businessName: name.text.trim(),
                  ruc: ruc.text.trim(),
                  address: address.text.trim(),
                  economicActivity: activity.text.trim(),
                  employeeCount: int.tryParse(employees.text.trim()) ?? 0,
                  logoPng: selectedLogo,
                );
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    ruc.dispose();
    address.dispose();
    activity.dispose();
    employees.dispose();
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Empresas y formatos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('AGREGAR EMPRESA'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
              children: [
                const Text(
                  'Datos del empleador',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Cada capacitación conservará la empresa que se le asigne.',
                  style: TextStyle(color: Color(0xFF626B7A)),
                ),
                const SizedBox(height: 16),
                ..._companies.map(
                  (company) => Card(
                    elevation: 0,
                    color: Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 86,
                            height: 70,
                            child: company.logoPng == null
                                ? const Icon(Icons.business_outlined, size: 48)
                                : Image.memory(
                                    company.logoPng!,
                                    fit: BoxFit.contain,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  company.businessName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text('RUC: ${company.ruc}'),
                                Text(company.economicActivity),
                                Text(
                                  company.address,
                                  style: const TextStyle(
                                    color: Color(0xFF626B7A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => _edit(company),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
