import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MaterialApp(home: EdamamePage()));
}

class EdamamePage extends StatefulWidget {
  const EdamamePage({super.key});

  @override
  State<EdamamePage> createState() => _EdamamePageState();
}

class _EdamamePageState extends State<EdamamePage> {
  // Koordinat Ladang (Contoh: Jakarta, bisa diganti nanti)
  final LatLng lokasiLadang = const LatLng(-6.200000, 106.816666); 
  
  String statusTanaman = "Siap Analisis";
  Color warnaMarker = Colors.blue; // Biru = Belum ada data

  // Fungsi Simulasi Cek ke Backend
  Future<void> cekKesehatan() async {
    setState(() {
      statusTanaman = "Menghubungi AI...";
    });

    // Simulasi delay (nanti diganti request ke Colab)
    await Future.delayed(const Duration(seconds: 2));

    // Logika dummy: Random Sehat/Sakit
    bool isSehat = DateTime.now().second % 2 == 0; 

    setState(() {
      if (isSehat) {
        statusTanaman = "TANAMAN SEHAT";
        warnaMarker = Colors.green;
      } else {
        statusTanaman = "HAMA TERDETEKSI!";
        warnaMarker = Colors.red;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Monitoring Edamame")),
      body: Stack(
        children: [
          // 1. PETA
          FlutterMap(
            options: MapOptions(
              initialCenter: lokasiLadang,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.edamame.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: lokasiLadang,
                    width: 80,
                    height: 80,
                    child: Icon(Icons.location_on, color: warnaMarker, size: 50),
                  ),
                ],
              ),
            ],
          ),
          // 2. PANEL KONTROL
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text("Status: $statusTanaman", 
                         style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: cekKesehatan,
                      child: const Text("Cek Kondisi Ladang"),
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}