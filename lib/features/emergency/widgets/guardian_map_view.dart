import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GuardianMapView extends StatefulWidget {
  const GuardianMapView({
    super.key,
    required this.markers,
    this.polylines = const <Polyline>{},
    this.focusPoints = const <LatLng>[],
    this.initialCenter,
    this.initialZoom = 14,
    this.initialTilt = 0,
    this.initialBearing = 0,
    this.mapType = MapType.normal,
    this.buildingsEnabled = true,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = false,
    this.trafficEnabled = false,
    this.compassEnabled = false,
    this.zoomControlsEnabled = false,
    this.fitBoundsOnUpdate = true,
    this.borderRadius = BorderRadius.zero,
    this.onMapCreated,
  });

  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final List<LatLng> focusPoints;
  final LatLng? initialCenter;
  final double initialZoom;
  final double initialTilt;
  final double initialBearing;
  final MapType mapType;
  final bool buildingsEnabled;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool trafficEnabled;
  final bool compassEnabled;
  final bool zoomControlsEnabled;
  final bool fitBoundsOnUpdate;
  final BorderRadius borderRadius;
  final ValueChanged<GoogleMapController>? onMapCreated;

  @override
  State<GuardianMapView> createState() => _GuardianMapViewState();
}

class _GuardianMapViewState extends State<GuardianMapView> {
  GoogleMapController? _controller;

  @override
  void didUpdateWidget(covariant GuardianMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fitBoundsOnUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  Future<void> _fitBounds() async {
    if (!widget.fitBoundsOnUpdate) {
      return;
    }

    final controller = _controller;
    final points = widget.focusPoints;

    if (controller == null || points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: points.first,
            zoom: widget.initialZoom,
            tilt: widget.initialTilt,
            bearing: widget.initialBearing,
          ),
        ),
      );
      return;
    }

    final latitudes = points.map((point) => point.latitude);
    final longitudes = points.map((point) => point.longitude);
    final bounds = LatLngBounds(
      southwest: LatLng(
        latitudes.reduce((value, element) => value < element ? value : element),
        longitudes.reduce(
          (value, element) => value < element ? value : element,
        ),
      ),
      northeast: LatLng(
        latitudes.reduce((value, element) => value > element ? value : element),
        longitudes.reduce(
          (value, element) => value > element ? value : element,
        ),
      ),
    );

    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target:
              widget.initialCenter ??
              widget.focusPoints.firstOrNull ??
              const LatLng(5.9631, 10.1591),
          zoom: widget.initialZoom,
          tilt: widget.initialTilt,
          bearing: widget.initialBearing,
        ),
        markers: widget.markers,
        polylines: widget.polylines,
        mapType: widget.mapType,
        buildingsEnabled: widget.buildingsEnabled,
        myLocationEnabled: widget.myLocationEnabled,
        myLocationButtonEnabled: widget.myLocationButtonEnabled,
        trafficEnabled: widget.trafficEnabled,
        compassEnabled: widget.compassEnabled,
        zoomControlsEnabled: widget.zoomControlsEnabled,
        mapToolbarEnabled: false,
        onMapCreated: (controller) {
          _controller = controller;
          widget.onMapCreated?.call(controller);
          if (widget.fitBoundsOnUpdate) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
          }
        },
      ),
    );
  }
}

extension on List<LatLng> {
  LatLng? get firstOrNull => isEmpty ? null : first;
}
