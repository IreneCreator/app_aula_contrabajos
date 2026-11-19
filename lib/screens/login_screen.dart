import 'package:flutter/material.dart';

import '../estilo.dart';
import '../services/auth_service.dart';
import '../widgets/dialogos.dart';
import '../widgets/mascota.dart';
import '../widgets/titulo_app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _entrando = false;

  Future<void> _entrar() async {
    setState(() => _entrando = true);
    try {
      await AuthService.entrarConGoogle();
    } catch (_) {
      if (mounted) avisar(context, 'No se ha podido iniciar sesión. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _entrando = false);
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
              // Aquí irá tu ilustración para el estilo Concierto.
              if (s.esTamagotchi) ...[
                const Mascota(alto: 120),
                const SizedBox(height: 24),
              ],
              Text('RESERVAS DEL AULA', style: s.etiqueta()),
              const SizedBox(height: 6),
              const TituloApp(size: 38),
              const SizedBox(height: 12),
              Text(
                'Entra con tu cuenta de Google para ver y reservar las franjas del aula.',
                style: s.texto(size: 15, color: s.suave),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _entrando ? null : _entrar,
                  child: Text(_entrando ? 'Entrando…' : 'Entrar con Google'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
