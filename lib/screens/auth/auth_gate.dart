import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_mesh_background.dart';
import '../main_layout.dart';
import 'login_screen.dart';

/// Single auth boundary for the whole app: [LoginScreen] when signed out,
/// [MainLayout] when signed in. Firestore Security Rules read role/org_id
/// custom claims off this same auth state (EVARAFLOW_GROUND_TRUTH.md
/// D-013), so nothing behind this gate can show real data until an account
/// exists with those claims set — a separate, one-time admin step, not
/// something this screen does.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthSplash();
        }
        if (snapshot.hasData) {
          return const MainLayout();
        }
        return const LoginScreen();
      },
    );
  }
}

class _AuthSplash extends StatelessWidget {
  const _AuthSplash();

  @override
  Widget build(BuildContext context) {
    return BrandMeshBackground(
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}
