import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Library Peta
import 'package:latlong2/latlong.dart';       // Library Koordinat
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- 1. FUNGSI UTAMA ---
void main() {
  runApp(MyApp());
}

// --- 2. KERANGKA APLIKASI ---
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Farming Grid',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: MonitoringPage(),
    );
  }
}

// --- 3. HALAMAN MONITORING UTAMA ---
class MonitoringPage extends StatefulWidget {
  @override
  _MonitoringPageState createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  // Koordinat Tengah Lahan (Sesuai Metadata Anda)
  final LatLng centerPoint = LatLng(50.0338, 82.5950);
  
  // --- VARIABEL STATE ---
  List<Polygon> gridPolygons = []; // List kotak yang ditampilkan
  List<dynamic> rawGridData = [];  // Data mentah dari API (untuk dirender ulang saat opacity berubah)
  
  bool isLoading = false;
  String infoStatus = "Tekan tombol untuk scan area";
  
  // Fitur Baru: Satelit & Opacity
  bool isSatelliteMode = false;
  double gridOpacity = 0.5; // Default 50% transparan

  // --- FUNGSI UPDATE TAMPILAN GRID ---
  // Fungsi ini dipanggil saat Data baru masuk ATAU saat Slider digeser
  void updatePolygonDisplay() {
    List<Polygon> newPolygons = [];
    int sehat = 0, warning = 0, kritis = 0;

    for (var feature in rawGridData) {
      // 1. Parsing Koordinat (GeoJSON [Lon, Lat] -> Flutter [Lat, Lon])
      List<dynamic> coords = feature['geometry']['coordinates'][0];
      List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList(); 

      // 2. Parsing Warna & Terapkan Opacity Slider
      String colorStr = feature['properties']['color'];
      Color polyColor;
      
      if (colorStr == 'red') {
        polyColor = Colors.red.withOpacity(gridOpacity);
        kritis++;
      } else if (colorStr == 'yellow') {
        polyColor = Colors.orange.withOpacity(gridOpacity);
        warning++;
      } else {
        polyColor = Colors.green.withOpacity(gridOpacity);
        sehat++;
      }

      newPolygons.add(
        Polygon(
          points: points,
          color: polyColor,
          borderColor: Colors.white.withOpacity(0.5), // Garis pinggir tipis
          borderStrokeWidth: 1,
          // isFilled: true (Sudah dihapus karena default di v8)
        ),
      );
    }

    setState(() {
      gridPolygons = newPolygons;
      // Jangan update text status jika sedang menggeser slider (biar smooth)
      if (!isLoading) {
         infoStatus = "Hasil: $sehat Sehat, $warning Warning, $kritis Kritis";
      }
    });
  }

  // --- FUNGSI API ---
  Future<void> scanAreaGrid() async {
    setState(() { 
      isLoading = true; 
      infoStatus = "Sedang memindai blok..."; 
      rawGridData = []; // Reset data lama
      gridPolygons = [];
    });

    // ⚠️ GANTI LINK INI DENGAN LINK NGROK TERBARU DARI COLAB ⚠️
    String baseUrl = "https://sauciest-maple-past.ngrok-free.dev"; 
    String endpoint = "/get_grid_map";

    try {
      var response = await http.get(Uri.parse(baseUrl + endpoint));

      if (response.statusCode == 200) {
        var geoJson = json.decode(response.body);
        
        // Simpan data mentah ke memori
        rawGridData = geoJson['features'];

        // Generate tampilan pertama kali
        updatePolygonDisplay();
        
      } else {
        setState(() { infoStatus = "Server Error: ${response.statusCode}"; });
      }
    } catch (e) {
      print("Error: $e");
      setState(() { infoStatus = "Gagal memuat grid (Cek Koneksi)"; });
    } finally {
      setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Grid Monitoring Sektor 20"),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
        actions: [
          // Tombol Reset Zoom (Opsional)
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
               // Logika reset map controller bisa ditambahkan di sini
            },
          )
        ],
      ),
      body: Stack(
        children: [
          // --- LAYER 1: PETA & GRID ---
          FlutterMap(
            options: MapOptions(
              initialCenter: centerPoint,
              initialZoom: 18.0,
            ),
            children: [
              // A. Layer Peta (Dinamis: Jalan / Satelit)
              TileLayer(
                // Logika Ganti URL
                urlTemplate: isSatelliteMode 
                  // OPSI 1: Google Hybrid (Biasanya lebih lengkap daripada Esri)
                  ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}' 
                  // OPSI 2: Tetap pakai Esri (Jika ingin open source murni)
                  // ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', 
                
                userAgentPackageName: 'com.example.edamame_app',
                
                // --- PERBAIKAN PENTING ---
                // Paksa aplikasi menggunakan tile resolusi rendah jika resolusi tinggi tidak ada
                maxNativeZoom: isSatelliteMode ? 17 : 19, 
                maxZoom: 22, // Bolehkah user zoom lebih dalam dari data yang ada? Boleh (Stretch)
              ),
              
              // B. Layer Grid Polygon (Hasil AI)
              PolygonLayer(polygons: gridPolygons),
            ],
          ),

          // --- LAYER 2: PANEL KONTROL DI BAWAH ---
          Positioned(
            bottom: 20, left: 15, right: 15,
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white.withOpacity(0.95), // Sedikit transparan biar keren
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Status Text
                    Text(
                      infoStatus, 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    Divider(),

                    // 2. Kontrol Tampilan (Switch & Slider)
                    Row(
                      children: [
                        // Toggle Satelit
                        Column(
                          children: [
                            Text("Satelit", style: TextStyle(fontSize: 12)),
                            Switch(
                              value: isSatelliteMode,
                              activeColor: Colors.purple,
                              onChanged: (val) {
                                setState(() { isSatelliteMode = val; });
                              },
                            ),
                          ],
                        ),
                        SizedBox(width: 10),
                        // Slider Opacity
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Transparansi Grid: ${(gridOpacity*100).toInt()}%", style: TextStyle(fontSize: 12)),
                              Slider(
                                value: gridOpacity,
                                min: 0.1,
                                max: 1.0,
                                activeColor: Colors.purple,
                                onChanged: (val) {
                                  setState(() {
                                    gridOpacity = val;
                                  });
                                  // Update tampilan grid secara realtime saat digeser
                                  if (rawGridData.isNotEmpty) updatePolygonDisplay();
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 5),
                    
                    // 3. Tombol Scan
                    isLoading 
                    ? LinearProgressIndicator(color: Colors.purple, minHeight: 5)
                    : ElevatedButton.icon(
                        icon: Icon(Icons.grid_view),
                        label: Text("Scan Analisis Grid (10m)"),
                        onPressed: scanAreaGrid,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
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