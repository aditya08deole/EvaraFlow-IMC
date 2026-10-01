import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LiquidGlassWidgets.initialize();
  runApp(
    LiquidGlassWidgets.wrap(child: const EvaraFlowApp(), adaptiveQuality: true),
  );
}
