// Procurement AI System - Flutter Frontend
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/role_selection_screen.dart';
import 'screens/custom_seasonality_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const ProcurementApp());
}

class ProcurementApp extends StatelessWidget {
  const ProcurementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<ApiService>(
      create: (_) => ApiService(),
      child: MaterialApp(
        title: 'Procurement AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2C3E50),
            secondary: const Color(0xFF1ABC9C),
            brightness: Brightness.light,
            background: const Color(0xFFF5F7FA),
          ),
          scaffoldBackgroundColor: Colors.transparent,
          
          // FIXED: Use CardThemeData instead of CardTheme
          cardTheme: CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Colors.white,
          ),
          
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: false,
            backgroundColor: Colors.transparent,
            foregroundColor: Color(0xFF2C3E50),
          ),
          navigationRailTheme: const NavigationRailThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: Color(0xFF1E88E5),
            labelType: NavigationRailLabelType.all,
            unselectedLabelTextStyle: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500
            ),
            selectedLabelTextStyle: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12
            ),
            unselectedIconTheme: IconThemeData(color: Colors.white54),
            selectedIconTheme: IconThemeData(color: Colors.white),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: const Color(0xFF1E88E5).withOpacity(0.5),
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const TextStyle(color: Colors.white, fontWeight: FontWeight.bold);
              }
              return const TextStyle(color: Colors.white70);
            }),
            iconTheme: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const IconThemeData(color: Colors.white);
              }
              return const IconThemeData(color: Colors.white70);
            }),
          ),
        ),
        home: const RoleSelectionScreen(),
        routes: {
          '/custom-seasonality': (_) => const CustomSeasonalityScreen(),
        },
      ),
    );
  }
}
