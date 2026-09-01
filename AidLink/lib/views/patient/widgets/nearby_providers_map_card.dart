import 'package:cloud_firestore/cloud_firestore.dart';
// Purpose: Reusable map card widget displaying nearby doctors and clinics.
// File: lib/views/patient/widgets/nearby_providers_map_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_values.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../core/localization/app_text.dart';

class NearbyProvidersMapCard extends StatefulWidget {
  final bool compact;
  final bool showTitle;
  final VoidCallback? onOpenFullMap;

  const NearbyProvidersMapCard({
    Key? key,
    this.compact = false,
    this.showTitle = true,
    this.onOpenFullMap,
  }) : super(key: key);

  @override
  State<NearbyProvidersMapCard> createState() => _NearbyProvidersMapCardState();
}

class _NearbyProvidersMapCardState extends State<NearbyProvidersMapCard> {
  static const LatLng _fallbackCenter = LatLng(31.5204, 74.3587);

  final MapController _mapController = MapController();
  bool _loading = true;
  String? _error;
  Position? _position;
  LatLng _mapCenter = _fallbackCenter;
  bool _mapReady = false;
  LatLng? _pendingMapCenter;
  double? _pendingMapZoom;
  _ProviderItem? _selectedItem;
  List<_ProviderItem> _items = <_ProviderItem>[];
  double _zoom = 13.0;

  String t(String english) => AppText.of(context, english);

  @override
  void initState() {
    super.initState();
    // --- Load current location and nearby providers ---
    _load();
  }

  // --- Fetch doctors/clinics and prepare map/list data ---
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Position? pos = await _resolveCurrentPosition();

      final QuerySnapshot<Map<String, dynamic>> doctorsSnap =
          await FirebaseFirestore.instance
              .collection(FirestoreCollections.doctors)
              .get();

      QuerySnapshot<Map<String, dynamic>>? clinicsSnap;
      try {
        clinicsSnap = await FirebaseFirestore.instance
            .collection('clinics')
            .get();
      } catch (_) {}

      final List<_ProviderItem> items = <_ProviderItem>[];

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in doctorsSnap.docs) {
        final Map<String, dynamic> data = doc.data();
        final dynamic geo = data['location'];

        final String first = (data['firstName'] ?? '').toString().trim();
        final String last = (data['lastName'] ?? '').toString().trim();
        final String fullName = '$first $last'.trim();

        if (geo is! GeoPoint) {
          continue;
        }

        final double distanceKm = pos == null
            ? 0.0
            : Geolocator.distanceBetween(
                    pos.latitude,
                    pos.longitude,
                    geo.latitude,
                    geo.longitude,
                  ) /
                  1000;

        items.add(
          _ProviderItem(
            id: doc.id,
            isDoctor: true,
            title: fullName.isEmpty ? 'Doctor' : 'Dr. $fullName',
            subtitle: (data['specialization'] ?? 'General').toString(),
            location: LatLng(geo.latitude, geo.longitude),
            distanceKm: distanceKm,
          ),
        );
      }

      if (clinicsSnap != null) {
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in clinicsSnap.docs) {
          final Map<String, dynamic> data = doc.data();
          final dynamic geo = data['location'];
          if (geo is! GeoPoint) {
            continue;
          }

          final double distanceKm = pos == null
              ? 0.0
              : Geolocator.distanceBetween(
                      pos.latitude,
                      pos.longitude,
                      geo.latitude,
                      geo.longitude,
                    ) /
                    1000;

          items.add(
            _ProviderItem(
              id: doc.id,
              isDoctor: false,
              title: (data['name'] ?? 'Clinic').toString(),
              subtitle: (data['address'] ?? '').toString(),
              location: LatLng(geo.latitude, geo.longitude),
              distanceKm: distanceKm,
            ),
          );
        }
      }

      items.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      final LatLng center = pos != null
          ? LatLng(pos.latitude, pos.longitude)
          : (items.isNotEmpty ? items.first.location : _fallbackCenter);

      if (!mounted) {
        return;
      }

      setState(() {
        _position = pos;
        _items = items;
        _loading = false;
        _selectedItem = null;
        _mapCenter = center;
        if (_position == null && items.isNotEmpty) {
          _zoom = 12.0;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (pos != null) {
          setState(() => _zoom = 13.0);
        }
        _moveMap(_mapCenter, _zoom);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '${t('Unable to load nearby providers.')} $e';
      });
    }
  }

  Future<Position?> _resolveCurrentPosition() async {
    try {
      final bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      final bool allowed =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
      if (!allowed) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  void _showProviderDetails(_ProviderItem item) {
    setState(() {
      _selectedItem = item;
      _mapCenter = item.location;
    });
    final double targetZoom = item.isDoctor ? 15.0 : 14.0;
    _moveMap(item.location, targetZoom);
  }

  void _hideProviderDetails() {
    if (_selectedItem == null) {
      return;
    }
    setState(() {
      _selectedItem = null;
    });
  }

  Future<void> _locateMe() async {
    final Position? pos = await _resolveCurrentPosition();
    if (pos == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('Unable to get your current location.')),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() => _position = pos);
    _moveMap(LatLng(pos.latitude, pos.longitude), 14.0);
  }

  void _onMapReady() {
    _mapReady = true;
    if (_pendingMapCenter != null) {
      _mapController.move(_pendingMapCenter!, _pendingMapZoom ?? _zoom);
      _pendingMapCenter = null;
      _pendingMapZoom = null;
    }
  }

  void _moveMap(LatLng center, double zoom) {
    _mapCenter = center;
    _zoom = zoom;

    if (!_mapReady) {
      _pendingMapCenter = center;
      _pendingMapZoom = zoom;
      return;
    }

    _mapController.move(center, zoom);
  }

  List<Marker> _markers() {
    final List<Marker> markers = <Marker>[];

    if (_position != null) {
      markers.add(
        Marker(
          point: LatLng(_position!.latitude, _position!.longitude),
          width: 42,
          height: 42,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.my_location, color: Colors.white, size: 20),
          ),
        ),
      );
    }

    for (final _ProviderItem item in _items) {
      markers.add(
        Marker(
          point: item.location,
          width: 42,
          height: 42,
          child: GestureDetector(
            onTap: () {
              _showProviderDetails(item);
            },
            child: Container(
              decoration: BoxDecoration(
                color: item.isDoctor
                    ? AppColors.primaryGreen
                    : Colors.deepOrange,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                item.isDoctor ? Icons.medical_services : Icons.local_hospital,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final LatLng center = _position == null
        ? _mapCenter
        : LatLng(_position!.latitude, _position!.longitude);

    final double mapHeight = widget.compact ? 260.0 : 440.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderGray),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showTitle) ...[
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('Nearby Doctors & Clinics'),
                      style: AppTypography.heading3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('Free live map powered by OpenStreetMap'),
                      style: AppTypography.bodyText.copyWith(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                TextButton(onPressed: _load, child: Text(t('Refresh'))),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          SizedBox(
            height: mapHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: _zoom,
                        onMapReady: _onMapReady,
                        onTap: (_, __) => _hideProviderDetails(),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.aidlink.app',
                        ),
                        MarkerLayer(markers: _markers()),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MapActionButton(
                        icon: Icons.add,
                        onPressed: () {
                          final double newZoom = (_zoom + 1).clamp(3.0, 18.0);
                          _moveMap(_currentCenter(), newZoom);
                        },
                      ),
                      const SizedBox(height: 8),
                      _MapActionButton(
                        icon: Icons.remove,
                        onPressed: () {
                          final double newZoom = (_zoom - 1).clamp(3.0, 18.0);
                          _moveMap(_currentCenter(), newZoom);
                        },
                      ),
                      const SizedBox(height: 8),
                      _MapActionButton(
                        icon: Icons.my_location,
                        onPressed: _locateMe,
                        accent: true,
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  Container(
                    color: Colors.white.withOpacity(0.75),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                if (!_loading && _error != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.all(AppSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyText.copyWith(fontSize: 13),
                      ),
                    ),
                  ),
                if (_selectedItem != null)
                  Positioned(
                    left: AppSpacing.sm,
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      offset: const Offset(0, 0),
                      child: _buildProviderSheet(_selectedItem!),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MapLegendChip(label: t('You'), color: Colors.blue),
              _MapLegendChip(label: t('Doctor'), color: AppColors.primaryGreen),
              _MapLegendChip(label: t('Clinic'), color: Colors.deepOrange),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${_items.length} ${t('nearby providers')}',
                style: AppTypography.bodyText.copyWith(color: Colors.grey[700]),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onOpenFullMap,
                child: Text(t('See all nearby')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  LatLng _currentCenter() {
    if (_position == null) {
      return _mapCenter;
    }
    return LatLng(_position!.latitude, _position!.longitude);
  }

  Widget _buildProviderSheet(_ProviderItem item) {
    return Material(
      elevation: 10,
      borderRadius: BorderRadius.circular(18),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: item.isDoctor
                      ? AppColors.primaryGreen
                      : Colors.deepOrange,
                  child: Icon(
                    item.isDoctor
                        ? Icons.medical_services
                        : Icons.local_hospital,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyText.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyText.copyWith(
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _hideProviderDetails,
                  child: Text(t('Close')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${item.distanceKm.toStringAsFixed(1)} km away',
              style: AppTypography.bodyText.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (item.isDoctor)
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/doctor-detail',
                          arguments: {
                            'doctorId': item.id,
                            'name': item.title,
                            'specialization': item.subtitle,
                          },
                        );
                      },
                      child: Text(t('View Profile')),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _hideProviderDetails,
                      child: Text(t('Keep Browsing')),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool accent;

  const _MapActionButton({
    required this.icon,
    required this.onPressed,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? AppColors.primaryGreen : Colors.white,
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: accent ? Colors.white : Colors.black87,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _MapLegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MapLegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.bodyText.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderItem {
  final String id;
  final bool isDoctor;
  final String title;
  final String subtitle;
  final LatLng location;
  final double distanceKm;

  const _ProviderItem({
    required this.id,
    required this.isDoctor,
    required this.title,
    required this.subtitle,
    required this.location,
    required this.distanceKm,
  });
}
