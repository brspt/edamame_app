import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Edamame Dashboard Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final MapController mapController = MapController();
  
  // State Data
  LatLng centerPoint = LatLng(50.0338, 82.5950);
  List<Polygon> gridPolygons = [];
  List<dynamic> rawFeatures = []; // Data mentah untuk deteksi klik
  
  bool isLoading = false;
  bool isSatelliteMode = false;
  double gridOpacity = 0.6; // Opacity Default

  // Multi-Select Sektor
  List<String> selectedSectors = ['20']; 
  final List<String> availableSectors = ['19', '20', '21'];

  // Data Tanggal & Lingkungan
  String selectedDate = '06-21';
  String displayUmur = "-";
  String displaySuhu = "-";

  final Map<String, String> dateOptions = {
    '06-08': '8 Juni (Fase Awal)',
    '06-21': '21 Juni (Vegetatif)',
    '07-12': '12 Juli (Berbunga)',
    '07-25': '25 Juli (Panen)',
  };

  @override
  void initState() {
    super.initState();
    fetchGridData();
  }

  // --- LOGIKA MULTI-SELECT DIALOG ---
  void _showSectorSelection() async {
    final List<String>? results = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return MultiSelectDialog(
          items: availableSectors,
          initialSelectedItems: selectedSectors,
        );
      },
    );

    if (results != null && results.isNotEmpty) {
      setState(() {
        selectedSectors = results;
      });
      fetchGridData(); 
    }
  }

  // --- API REQUEST ---
  Future<void> fetchGridData() async {
    setState(() { isLoading = true; });

    // ⚠️ PASTIKAN LINK NGROK V3 TERBARU DISINI ⚠️
    String baseUrl = "https://sauciest-maple-past.ngrok-free.dev"; 
    
    String sectorsParam = selectedSectors.join(',');
    String endpoint = "/get_grid_map?sectors=$sectorsParam&date=$selectedDate";

    try {
      var response = await http.get(Uri.parse(baseUrl + endpoint));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        
        List<dynamic> features = data['features'];
        rawFeatures = features; // Simpan data mentah untuk fitur Klik
        
        // Update Tampilan Polygon
        _updatePolygonDisplay();

        // Update Info Lingkungan
        var env = data['env_info'];
        
        setState(() {
          if (data['center_lat'] != 0) {
             centerPoint = LatLng(data['center_lat'], data['center_lng']);
             mapController.move(centerPoint, 17.5);
          }
          
          // --- PERBAIKAN: TAMBAHKAN .toString() ---
          displayUmur = env['umur'].toString(); 
          displaySuhu = env['suhu'].toString();
        });

      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() { isLoading = false; });
    }
  }

  // --- FUNGSI UPDATE TAMPILAN (Dipanggil saat Slider digeser) ---
  void _updatePolygonDisplay() {
    List<Polygon> newPolygons = [];
    
    for (var feature in rawFeatures) {
      List<dynamic> coords = feature['geometry']['coordinates'][0];
      List<LatLng> points = coords.map((c) => LatLng(c[1], c[0])).toList();
      
      String colorStr = feature['properties']['color'];
      Color polyColor = Colors.green;
      
      if (colorStr == 'red') polyColor = Colors.red;
      else if (colorStr == 'yellow') polyColor = Colors.orange;
      else if (colorStr == 'gray') polyColor = Colors.brown; // GANTI JADI COKELAT AGAR TERLIHAT (TANAH)

      newPolygons.add(Polygon(
        points: points,
        color: polyColor.withOpacity(gridOpacity),
        borderColor: Colors.white.withOpacity(0.2),
        borderStrokeWidth: 1,
        // isFilled: true, // Default di v8
      ));
    }

    setState(() {
      gridPolygons = newPolygons;
    });
  }

  // --- LOGIKA KLIK (INTERAKSI 10m2) ---
  void _handleTap(TapPosition tapPosition, LatLng point) {
    // Cari kotak mana yang diklik user
    for (var feature in rawFeatures) {
      List<dynamic> coords = feature['geometry']['coordinates'][0];
      
      // Cari batas bounding box kotak ini
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      for (var c in coords) {
        double lat = c[1]; double lng = c[0];
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lng < minLng) minLng = lng;
        if (lng > maxLng) maxLng = lng;
      }

      // Cek apakah klik ada di dalam kotak
      if (point.latitude >= minLat && point.latitude <= maxLat &&
          point.longitude >= minLng && point.longitude <= maxLng) {
        
        // KETEMU! Tampilkan Popup Detail
        _showBlockDetail(feature['properties']);
        return; 
      }
    }
  }

  // --- POPUP DETAIL (MODAL BOTTOM SHEET) ---
  // --- POPUP DETAIL (SAFE VERSION) ---
  // --- POPUP DETAIL (UPDATE SAVI) ---
  void _showBlockDetail(Map<String, dynamic> props) {
    Color statusColor = Colors.green;
    String cStr = props['color'] ?? 'green';
    
    if(cStr == 'red') statusColor = Colors.red;
    if(cStr == 'yellow') statusColor = Colors.orange;
    if(cStr == 'gray') statusColor = Colors.brown;

    // Ambil Data (Anti Crash)
    double valNDVI = (props['ndvi'] ?? 0.0).toDouble();
    double valNDRE = (props['ndre'] ?? 0.0).toDouble();
    double valNDWI = (props['ndwi'] ?? 0.0).toDouble();
    double valSAVI = (props['savi'] ?? 0.0).toDouble(); // ✅ AMBIL SAVI
    String statusTxt = (props['status'] ?? "Unknown").toUpperCase();

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.grid_on, color: statusColor, size: 30),
                  SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Detail Blok Area (10x10m)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(statusTxt, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: statusColor)),
                    ],
                  )
                ],
              ),
              Divider(height: 30),
              
              // Grid Parameter (Sekarang 4 Kolom termasuk SAVI)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                   _buildMetricBox("NDVI", valNDVI.toStringAsFixed(3), Icons.eco, Colors.green),
                   _buildMetricBox("NDRE", valNDRE.toStringAsFixed(3), Icons.grass, Colors.teal),
                   _buildMetricBox("NDWI", valNDWI.toStringAsFixed(3), Icons.water_drop, Colors.blue),
                   _buildMetricBox("SAVI", valSAVI.toStringAsFixed(3), Icons.layers, Colors.brown), // ✅ TAMPILKAN SAVI
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: statusColor, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context), 
                  child: Text("Tutup")
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricBox(String title, String value, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          SizedBox(height: 5),
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. PETA UTAMA
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: centerPoint,
              initialZoom: 17.5,
              onTap: _handleTap, // ✅ FITUR KLIK DIAKTIFKAN
            ),
            children: [
              TileLayer(
                urlTemplate: isSatelliteMode
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                maxNativeZoom: isSatelliteMode ? 20 : 19,
              ),
              PolygonLayer(polygons: gridPolygons),
            ],
          ),

          // 2. DASHBOARD PANEL ATAS (FILTER & OPACITY)
          SafeArea(
            child: Container(
              margin: EdgeInsets.all(12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Smart Monitoring AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      // Toggle Satelit
                      GestureDetector(
                        onTap: () => setState(() => isSatelliteMode = !isSatelliteMode),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: isSatelliteMode ? Colors.green : Colors.grey[300], borderRadius: BorderRadius.circular(20)),
                          child: Text(isSatelliteMode ? "Satelit" : "Peta", style: TextStyle(fontSize: 12, color: isSatelliteMode ? Colors.white : Colors.black)),
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 10),
                  
                  // Filter Sektor & Tanggal
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _showSectorSelection,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Sektor (${selectedSectors.length})", style: TextStyle(fontSize: 12)), Icon(Icons.arrow_drop_down)]),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedDate,
                              isExpanded: true,
                              style: TextStyle(fontSize: 12, color: Colors.black),
                              items: dateOptions.keys.map((key) => DropdownMenuItem(value: key, child: Text(dateOptions[key]!))).toList(),
                              onChanged: (val) { setState(() { selectedDate = val!; }); fetchGridData(); },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 10),
                  // ✅ SLIDER OPACITY DIKEMBALIKAN
                  Row(
                    children: [
                      Text("Transparansi:", style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 2),
                          child: Slider(
                            value: gridOpacity,
                            min: 0.1, max: 1.0,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              setState(() { gridOpacity = val; });
                              _updatePolygonDisplay(); // Render ulang saat digeser
                            },
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Info Parameter
                  Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniInfo(Icons.calendar_today, "Umur", displayUmur),
                      _buildMiniInfo(Icons.thermostat, "Suhu", displaySuhu),
                    ],
                  ),

                  if (isLoading) Padding(padding: EdgeInsets.only(top: 5), child: LinearProgressIndicator(minHeight: 2)),
                ],
              ),
            ),
          ),

          // 3. LEGEND (POJOK KANAN BAWAH) ✅ FITUR LEGEND DIKEMBALIKAN
          Positioned(
            bottom: 20,
            right: 20,
            child: Card(
              elevation: 5,
              color: Colors.white.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("KETERANGAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)),
                    SizedBox(height: 5),
                    _buildLegendItem(Colors.green, "Sehat (>0.33)"),
                    _buildLegendItem(Colors.orange, "Warning (0.28-0.33)"),
                    _buildLegendItem(Colors.red, "Kritis (<0.28)"),
                    _buildLegendItem(Colors.brown, "Tanah/Non-Veg"), // ✅ WARNA BARU UNTUK FASE AWAL
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color.withOpacity(0.8), shape: BoxShape.circle)),
          SizedBox(width: 8),
          Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        SizedBox(width: 4),
        Text("$label: ", style: TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// --- WIDGET DIALOG MULTI-SELECT ---
class MultiSelectDialog extends StatefulWidget {
  final List<String> items;
  final List<String> initialSelectedItems;

  MultiSelectDialog({required this.items, required this.initialSelectedItems});

  @override
  _MultiSelectDialogState createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  late List<String> _tempSelectedItems;

  @override
  void initState() {
    super.initState();
    _tempSelectedItems = List.from(widget.initialSelectedItems);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Pilih Sektor Aktif"),
      content: SingleChildScrollView(
        child: ListBody(
          children: widget.items.map((item) {
            return CheckboxListTile(
              value: _tempSelectedItems.contains(item),
              title: Text("Sektor $item"),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (isChecked) {
                setState(() {
                  if (isChecked!) {
                    _tempSelectedItems.add(item);
                  } else {
                    _tempSelectedItems.remove(item);
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Batal")),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _tempSelectedItems),
          child: Text("Terapkan"),
        ),
      ],
    );
  }
}