import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/courier_models.dart';
import '../../service/directions_service.dart';

/// Halaman visualisasi rute batch delivery dengan peta interaktif
/// Menampilkan polyline rute + numbered markers
class BatchRouteMapPage extends StatefulWidget {
  final List<CourierOrder> orders;
  final String batchId;

  const BatchRouteMapPage({
    super.key,
    required this.orders,
    required this.batchId,
  });

  @override
  State<BatchRouteMapPage> createState() => _BatchRouteMapPageState();
}

class _BatchRouteMapPageState extends State<BatchRouteMapPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoadingRoute = true;
  LatLng? _currentLocation;
  
  // Check apakah semua pesanan sudah on_delivery
  bool get _isActiveDelivery => widget.orders.every(
    (order) => order.deliveryStatus == 'on_delivery'
  );
  
  // lokasi toko katsuchip
  static const LatLng _storeLocation = LatLng(-0.9059128990717297, 100.36016218288833);

  @override
  void initState() {
    super.initState();
    print(' BatchRouteMapPage initialized with ${widget.orders.length} orders');
    
    // Delayed initialization untuk kasih waktu widget tree ready
    Future.microtask(() => _initializeMap());
  }

  Future<void> _initializeMap() async {
    print('Initializing map...');
    
    // ambil lokasi sekarang
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      if (mounted) {
        _currentLocation = LatLng(position.latitude, position.longitude);
        print('Got current location: $_currentLocation');
      }
    } catch (e) {
      print('Cannot get current location: $e');
      _currentLocation = _storeLocation; // Fallback ke lokasi toko
    }

    print('Loading route and markers...');
    await _loadRouteAndMarkers();
    print('Map initialization complete');
  }

  Future<void> _loadRouteAndMarkers() async {
    if (!mounted) return;

    final markers = <Marker>{};
    
    // filter orders
    final validOrders = widget.orders.where((o) {
      final lat = o.latitude;
      final lng = o.longitude;
      final isValid = lat != null && lng != null && lat != 0 && lng != 0;
      if (!isValid) {
        print('?? Invalid coordinates for ${o.recipientName}: ($lat, $lng)');
      }
      return isValid;
    }).toList();

    print('?? Valid orders: ${validOrders.length} / ${widget.orders.length}');

    if (validOrders.isEmpty) {
      print('? No valid coordinates found!');
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
          _markers = markers;
        });
      }
      return;
    }

    // Marker untuk lokasi start point si kurir
    final startLocation = _currentLocation ?? _storeLocation;
    print('?? Start marker at: $startLocation');
    
    markers.add(Marker(
      markerId: const MarkerId('current_location'),
      position: startLocation,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: const InfoWindow(
        title: 'Lokasi Anda',
        snippet: 'Mulai dari sini',
      ),
    ));

    // Markers untuk setiap order dengan nomor urut
    for (int i = 0; i < validOrders.length; i++) {
      final order = validOrders[i];
      final lat = order.latitude!;
      final lng = order.longitude!;
      
      print('?? Marker ${i + 1}: ${order.recipientName} at ($lat, $lng)');

      markers.add(Marker(
        markerId: MarkerId(order.orderId),
        position: LatLng(lat, lng),
        icon: await _getNumberedMarker(i + 1),
        infoWindow: InfoWindow(
          title: '${i + 1}. ${order.recipientName}',
          snippet: order.address,
        ),
      ));
    }

    print('? Created ${markers.length} markers');

    if (mounted) {
      setState(() {
        _markers = markers;
      });
    }

    // Fetch polyline dari Directions API
    print('??? Fetching route polyline...');
    await _fetchRoutePolyline(validOrders);

    // Zoom ke bounds yang mencakup semua marker
    if (_mapController != null) {
      print('?? Fitting bounds...');
      _fitBounds();
    }

    if (mounted) {
      setState(() => _isLoadingRoute = false);
    }
    
    print('? Route loading complete');
  }

  Future<void> _fetchRoutePolyline(List<CourierOrder> validOrders) async {
    if (validOrders.isEmpty || !mounted) return;

    final origin = _currentLocation ?? _storeLocation;
    final destination = LatLng(
      validOrders.last.latitude!,
      validOrders.last.longitude!,
    );

    // Waypoints (semua kecuali yang terakhir)
    final waypoints = validOrders
        .take(validOrders.length - 1)
        .map((o) => LatLng(o.latitude!, o.longitude!))
        .toList();

    print('??? Fetching directions:');
    print('   Origin: $origin');
    print('   Waypoints: ${waypoints.length}');
    print('   Destination: $destination');

    // Coba fetch dari Google Directions API
    List<LatLng>? routePoints = await DirectionsService.getDirections(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
    );

    if (!mounted) return;

    // Fallback: jika API gagal, buat garis lurus
    if (routePoints == null) {
      print('?? Directions API failed, using straight lines');
      routePoints = DirectionsService.createStraightLines(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );
    } else {
      print('? Got ${routePoints.length} polyline points from API');
    }

    // Buat polyline
    final polyline = Polyline(
      polylineId: const PolylineId('batch_route'),
      points: routePoints,
      color: const Color(0xFFFF7A00), // Orange KatsuChip
      width: 5,
      patterns: [PatternItem.dot, PatternItem.gap(10)],
    );

    if (mounted) {
      setState(() {
        _polylines = {polyline};
      });
      print('? Polyline added to map (${routePoints.length} points)');
    }
  }

  /// Generate numbered marker icon
  Future<BitmapDescriptor> _getNumberedMarker(int number) async {
    // Untuk simplicity, gunakan hue berbeda per nomor
    // Untuk custom numbered icon, perlu buat canvas/image
    final hue = (number * 30) % 360.0;
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  void _fitBounds() {
    if (_markers.isEmpty || _mapController == null) {
      print('? Cannot fit bounds: markers=${_markers.length}, controller=${_mapController != null}');
      return;
    }

    final positions = _markers.map((m) => m.position).toList();
    
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    print('?? Bounds: SW($minLat,$minLng) NE($maxLat,$maxLng)');

    // Try immediate animation first
    try {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80), // 80px padding
      );
      print('? Camera animation success');
    } catch (e) {
      print('?? Camera animation error: $e');
      // Fallback: move to center
      try {
        final center = LatLng(
          (minLat + maxLat) / 2,
          (minLng + maxLng) / 2,
        );
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(center, 14),
        );
        print('? Fallback camera move success');
      } catch (e2) {
        print('? Fallback camera move failed: $e2');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rute Batch ${widget.orders.length} Pesanan'),
        backgroundColor: const Color(0xFFFF7A00),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Always show map widget with FIXED initial position
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _storeLocation, // Use const static location
              zoom: 12,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            buildingsEnabled: false,
            trafficEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (controller) async {
              if (!mounted) return;
              
              print('??? Map created');
              _mapController = controller;
              
              // Wait a bit then fit bounds
              await Future.delayed(const Duration(milliseconds: 1000));
              if (mounted && _markers.isNotEmpty) {
                print('??? Fitting bounds to ${_markers.length} markers');
                _fitBounds();
              }
            },
          ),
          
          // Loading indicator
          if (_isLoadingRoute)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Memuat rute...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Info panel di bawah
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.route,
                        color: Color(0xFFFF7A00),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Urutan Pengiriman',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // List order sequence
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      itemCount: widget.orders.length,
                      itemBuilder: (context, index) {
                        final order = widget.orders[index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFF7A00),
                            radius: 16,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          title: Text(
                            order.recipientName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            order.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            order.code,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Action buttons
                  Row(
                    children: [
                      // Navigate in Google Maps
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _openInGoogleMaps,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4285F4), // Google blue
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.navigation, size: 20),
                            label: const Text(
                              'Navigasi',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Close or Start button
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context, _isActiveDelivery ? false : true);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF7A00),
                              side: const BorderSide(color: Color(0xFFFF7A00), width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              _isActiveDelivery ? Icons.close : Icons.check_circle_outline,
                              size: 20,
                            ),
                            label: Text(
                              _isActiveDelivery ? 'Tutup' : 'Mulai',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openInGoogleMaps() async {
    try {
      // Validate coordinates
      final validOrders = widget.orders.where((o) {
        final lat = o.latitude;
        final lng = o.longitude;
        return lat != null && lng != null && lat != 0 && lng != 0;
      }).toList();

      if (validOrders.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada koordinat valid untuk navigasi')),
          );
        }
        return;
      }

      // Build Google Maps URL dengan waypoints
      // Format: https://www.google.com/maps/dir/?api=1&origin=LAT,LNG&destination=LAT,LNG&waypoints=LAT,LNG|LAT,LNG&travelmode=driving
      
      final origin = _currentLocation ?? _storeLocation;
      final destination = validOrders.last;
      
      // Waypoints (semua kecuali yang terakhir)
      final waypoints = validOrders
          .take(validOrders.length - 1)
          .map((o) => '${o.latitude},${o.longitude}')
          .join('|');

      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '${waypoints.isNotEmpty ? '&waypoints=$waypoints' : ''}'
        '&travelmode=driving'
      );

      print('??? Opening Google Maps: $url');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: Open in browser
        final webUrl = Uri.parse(url.toString());
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } else {
          throw 'Tidak dapat membuka Google Maps';
        }
      }
    } catch (e) {
      print('? Error opening Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka Google Maps: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    // Proper cleanup untuk mencegah memory leak
    _mapController?.dispose();
    _mapController = null;
    _markers.clear();
    _polylines.clear();
    super.dispose();
  }
}
