import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class PickLocationPage extends StatefulWidget {
  final LatLng? initialPosition;
  final String? initialAddress;

  const PickLocationPage({
    super.key,
    this.initialPosition,
    this.initialAddress,
  });

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  final MapController _mapController = MapController();
  LatLng _currentPosition = LatLng(-0.9471136, 100.4172356); // Default: Padang
  String _currentAddress = 'Memuat alamat...';
  bool _loadingAddress = false;
  bool _showMap = false;
  bool _isDragging = false;

  // Address input controllers
  final _streetController = TextEditingController();
  final _detailController = TextEditingController();
  final _provinceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _currentPosition = widget.initialPosition!;
      _showMap = true;
      if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
        _currentAddress = widget.initialAddress!;
      } else {
        _getAddressFromLatLng(_currentPosition);
      }
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _streetController.dispose();
    _detailController.dispose();
    _provinceController.dispose();
    super.dispose();
  }

  Future<void> _searchAndShowMap() async {
    final province = _provinceController.text.trim();
    final street = _streetController.text.trim();
    final detail = _detailController.text.trim();

    if (province.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mohon isi minimal Provinsi, Kota, Kecamatan'),
        ),
      );
      return;
    }

    setState(() => _loadingAddress = true);

    try {
      // Build full address query
      final parts = <String>[];
      if (street.isNotEmpty) parts.add(street);
      if (detail.isNotEmpty) parts.add(detail);
      parts.add(province);

      final query = parts.join(', ');

      // Geocode address to coordinates
      List<Location> locations = await locationFromAddress(query);

      if (locations.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alamat tidak ditemukan. Coba masukkan alamat yang lebih spesifik'),
            ),
          );
        }
        setState(() => _loadingAddress = false);
        return;
      }

      // Use first result
      final location = locations.first;
      final position = LatLng(location.latitude, location.longitude);

      setState(() {
        _currentPosition = position;
        _loadingAddress = false;
        _showMap = true;
      });

      // Wait for map to render, then move to position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showMap) {
          _mapController.move(position, 17);
        }
      });

      // Get address from coordinates
      _getAddressFromLatLng(position);
    } catch (e) {
      print('Error geocoding address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      setState(() => _loadingAddress = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS tidak aktif. Silakan aktifkan GPS.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Izin lokasi ditolak')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin lokasi ditolak permanen. Silakan ubah di pengaturan.'),
            ),
          );
        }
        return;
      }

      setState(() => _loadingAddress = true);

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final newPosition = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentPosition = newPosition;
        _showMap = true;
        _loadingAddress = false;
      });

      // Wait for map to render, then move to position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showMap) {
          _mapController.move(newPosition, 17);
        }
      });
      
      _getAddressFromLatLng(newPosition);
    } catch (e) {
      print('Error getting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendapatkan lokasi: $e')),
        );
      }
      setState(() => _loadingAddress = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() => _loadingAddress = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];

        // Build address string
        final parts = <String>[];

        if (_streetController.text.isNotEmpty) {
          parts.add(_streetController.text);
        } else if (place.street != null && place.street!.isNotEmpty) {
          parts.add(place.street!);
        }

        if (_detailController.text.isNotEmpty) {
          parts.add(_detailController.text);
        }

        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          parts.add(place.subLocality!);
        }

        if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          parts.add(place.subAdministrativeArea!);
        }

        if (place.locality != null && place.locality!.isNotEmpty) {
          parts.add(place.locality!);
        }

        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          parts.add(place.administrativeArea!);
        }

        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          parts.add(place.postalCode!);
        }

        setState(() {
          _currentAddress = parts.join(', ');
          _loadingAddress = false;
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _currentAddress = 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
        _loadingAddress = false;
      });
    }
  }

  void _onMapPositionChanged(MapCamera position, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _isDragging = true;
        _currentPosition = position.center;
      });
    }
  }

  void _onMapPositionChangedEnd(MapCamera position) {
    setState(() {
      _isDragging = false;
      _currentPosition = position.center;
    });
    _getAddressFromLatLng(_currentPosition);
  }

  void _confirmLocation() {
    Navigator.of(context).pop({
      'position': _currentPosition,
      'address': _currentAddress,
      'latitude': _currentPosition.latitude,
      'longitude': _currentPosition.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alamat Baru'),
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
      ),
      body: _showMap ? _buildMapView() : _buildAddressForm(),
    );
  }

  Widget _buildAddressForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Instruksi
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, color: Color(0xFFFF7A00), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Isi alamat lengkap di bawah, lalu tap "Cari Lokasi" untuk konfirmasi titik di map',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'Alamat',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: 12),

        // Nama Jalan, Gedung, No. Rumah
        TextField(
          controller: _streetController,
          decoration: InputDecoration(
            labelText: 'Nama Jalan, Gedung, No. Rumah',
            hintText: 'Jl. Kesehatan blok A/1',
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        // Detail Lainnya
        TextField(
          controller: _detailController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Detail Lainnya (Cth: Blok / Unit No., Patokan)',
            hintText: 'RT.1/ RW.2',
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),

        // Provinsi, Kota, Kecamatan, Kode Pos
        TextField(
          controller: _provinceController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Kecamatan, Kota, Provinsi, Kode Pos',
            hintText: 'Nanggalo, Kota Padang, Sumatera Barat, 25142',
            hintStyle: const TextStyle(color: Colors.grey),
            suffixIcon: const Icon(Icons.arrow_forward_ios, size: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        const SizedBox(height: 24),

        // Tombol Cari Lokasi
        ElevatedButton.icon(
          onPressed: _loadingAddress ? null : _searchAndShowMap,
          icon: _loadingAddress
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.map),
          label: Text(_loadingAddress ? 'Mencari lokasi...' : 'Cari Lokasi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7A00),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Tombol GPS
        OutlinedButton.icon(
          onPressed: _loadingAddress ? null : _getCurrentLocation,
          icon: const Icon(Icons.my_location),
          label: const Text('Gunakan Lokasi Saat Ini'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFFF7A00),
            side: const BorderSide(color: Color(0xFFFF7A00)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        // Flutter Map (OpenStreetMap)
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentPosition,
            initialZoom: 17,
            onPositionChanged: _onMapPositionChanged,
            onMapEvent: (event) {
              if (event is MapEventMoveEnd) {
                _onMapPositionChangedEnd(event.camera);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.katsuchip_app',
            ),
          ],
        ),

        // Center Pin (Fixed in center) - Shopee style
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(0, _isDragging ? -20 : 0, 0),
                child: const Icon(
                  Icons.location_pin,
                  size: 48,
                  color: Color(0xFFFF7A00),
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48), // Offset untuk pin di tengah
            ],
          ),
        ),

        // Floating message when dragging
        if (_isDragging)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 100),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A00),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Geser peta untuk memilih lokasi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Address Card at Top
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your Address Input',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _currentAddress,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_loadingAddress)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() => _showMap = false);
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // My Location Button (Right side)
        Positioned(
          right: 16,
          bottom: 100,
          child: FloatingActionButton(
            heroTag: 'myLocation',
            onPressed: _getCurrentLocation,
            backgroundColor: Colors.white,
            mini: true,
            elevation: 4,
            child: const Icon(Icons.my_location, color: Color(0xFFFF7A00)),
          ),
        ),

        // Confirm Button (Bottom)
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: ElevatedButton(
            onPressed: _loadingAddress ? null : _confirmLocation,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
