import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'estilo.dart';
import 'firebase_options.dart';
import 'models/usuario.dart';
import 'screens/login_screen.dart';
import 'screens/nombre_screen.dart';
import 'screens/reservas_screen.dart';
import 'services/auth_service.dart';
import 'services/datos_service.dart';
import 'tema.dart';
import 'widgets/cargando.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AulaApp());
}

/// Decide qué pantalla mostrar (inicio de sesión, elegir nombre o la app)
/// y con qué estilo, según la ficha del usuario.
class AulaApp extends StatelessWidget {
  const AulaApp({super.key});

  Widget _app(Estilo estilo, Widget inicio) {
    return MaterialApp(
      title: 'Aula de contrabajo',
      debugShowCheckedModeBanner: false,
      theme: crearTema(estilo),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: inicio,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.cambios,
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) {
          return _app(Estilo.concierto, const Cargando());
        }
        final user = auth.data;
        if (user == null) return _app(Estilo.concierto, const LoginScreen());

        return StreamBuilder<Usuario?>(
          stream: Datos.usuario(user.uid),
          builder: (context, perfil) {
            if (perfil.connectionState == ConnectionState.waiting) {
              return _app(Estilo.concierto, const Cargando());
            }
            final yo = perfil.data;
            if (yo == null) {
              return _app(
                Estilo.concierto,
                NombreScreen(uid: user.uid, sugerido: user.displayName, email: user.email),
              );
            }
            return _app(Estilo.porId(yo.estilo), ReservasScreen(yo: yo));
          },
        );
      },
    );
  }
}
