import 'package:flutter/material.dart';

import '../estilo.dart';
import '../services/auth_service.dart';
import '../services/datos_service.dart';
import '../widgets/dialogos.dart';

/// Se muestra la primera vez que alguien entra: elige cómo le verán los demás.
class NombreScreen extends StatefulWidget {
  final String uid;
  final String? sugerido;
  final String? email;

  const NombreScreen({super.key, required this.uid, this.sugerido, this.email});

  @override
  State<NombreScreen> createState() => _NombreScreenState();
}

class _NombreScreenState extends State<NombreScreen> {
  late final _ctrl = TextEditingController(text: (widget.sugerido ?? '').split(' ').first);
  bool _guardando = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _ctrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _guardando = true);
    try {
      await Datos.crearUsuario(uid: widget.uid, nombre: nombre, email: widget.email);
    } catch (_) {
      if (mounted) avisar(context, 'No se ha podido guardar. Inténtalo de nuevo.');
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Estilo.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('BIENVENIDA', style: s.etiqueta()),
              const SizedBox(height: 6),
              Text('¿Cómo quieres que te vean los demás?', style: s.titulo(size: 28)),
              const SizedBox(height: 24),
              TextField(
                controller: _ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _guardar(),
                decoration: InputDecoration(
                  labelText: 'Tu nombre',
                  filled: true,
                  fillColor: s.tarjeta,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(s.radio)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: Text(_guardando ? 'Guardando…' : 'Empezar'),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: TextButton(onPressed: AuthService.salir, child: const Text('Usar otra cuenta'))),
            ]),
          ),
        ),
      ),
    );
  }
}
