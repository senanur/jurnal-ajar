import 'package:flutter/material.dart';

class DashboardGuru extends StatefulWidget {
  const DashboardGuru({super.key});

  @override
  State<DashboardGuru> createState() => _DashboardGuruState();
}

class _DashboardGuruState extends State<DashboardGuru> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text("Dashboard Guru")));
  }
}
