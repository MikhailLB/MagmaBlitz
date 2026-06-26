import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/agent_client.dart';
import 'core/alerts_relay.dart';
import 'core/attribution_hub.dart';
import 'core/net_sensor.dart';
import 'core/vault.dart';
import 'core/verdict_gateway.dart';
import 'services/progress_service.dart';
import 'stage/ignition_stage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase + App Check: best-effort so the app still launches
  // if google-services.json hasn't been wired yet during dev.
  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (_) {
    // Continue — gray flow degrades gracefully without Firebase.
  }

  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await agentClient.warmUp();

  final vault = Vault();
  await vault.warmUp();

  // Warm the existing game-side progress store too — the white
  // mode UI reads it the moment the game enters LoadingScreen.
  await ProgressService.instance.init();

  final netSensor = NetSensor();
  final attribution = AttributionHub();
  final gateway = VerdictGateway(vault);
  final relay = AlertsRelay(vault);

  runApp(
    MagmaBlitzApp(
      vault: vault,
      netSensor: netSensor,
      attribution: attribution,
      gateway: gateway,
      relay: relay,
    ),
  );
}

class MagmaBlitzApp extends StatelessWidget {
  final Vault vault;
  final NetSensor netSensor;
  final AttributionHub attribution;
  final VerdictGateway gateway;
  final AlertsRelay relay;

  const MagmaBlitzApp({
    super.key,
    required this.vault,
    required this.netSensor,
    required this.attribution,
    required this.gateway,
    required this.relay,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magma Blitz',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: IgnitionStage(
        vault: vault,
        netSensor: netSensor,
        attribution: attribution,
        gateway: gateway,
        relay: relay,
      ),
    );
  }
}

/// Locks the app to vertical orientation for actual gameplay.
/// LoadingScreen → MenuScreen calls this once the gray gate has
/// routed the user into the native game.
Future<void> lockPortrait() async {
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}
