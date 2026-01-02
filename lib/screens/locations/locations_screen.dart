import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import '../../app_localizations.dart';
import '../../constants.dart';
import '../../models/branch.dart';
import '../../services/branch_state.dart';
import '../../utils/snackbar_utils.dart';

final BitmapDescriptor _branchPinIcon =
    BitmapDescriptor.fromAssetImage('assets/icons/branch_pin.png');

const Point _initialBukharaCenter =
    Point(latitude: 39.772500, longitude: 64.432500);
const double _initialBukharaZoom = 13.2;

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final BranchState _branchState = BranchState.instance;
  late Branch _activeBranch = _branchState.activeBranch;
  YandexMapController? _mapController;
  bool _hasPromptedForLocation = false;
  bool _isRequestingLocation = false;
  bool _disposed = false;
  bool _locationGranted = false;

  @override
  void initState() {
    super.initState();
    _branchState.addListener(_handleGlobalBranchChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(
          const Duration(milliseconds: 300), _maybePromptForLocation);
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _branchState.removeListener(_handleGlobalBranchChange);
    super.dispose();
  }

  void _handleGlobalBranchChange() {
    final branch = _branchState.activeBranch;
    if (_activeBranch.id == branch.id) return;
    setState(() => _activeBranch = branch);
    _moveToBranch(branch);
  }

  List<Branch> get _branches => _branchState.branches;

  late final List<MapObject> _cachedMapObjects = [];

  List<MapObject> get _mapObjects {
    if (_cachedMapObjects.isEmpty) {
      _cachedMapObjects.addAll(_branches.map((branch) {
        final isActive = branch == _activeBranch;
        return PlacemarkMapObject(
          mapId: MapObjectId(branch.id),
          point: branch.point,
          consumeTapEvents: true,
          opacity: isActive ? 1.0 : 0.72,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: _branchPinIcon,
              scale: isActive ? 1.15 : 0.95,
            ),
          ),
          onTap: (_, __) => _selectBranch(branch),
        );
      }));
    }
    return _cachedMapObjects;
  }

  Future<void> _maybePromptForLocation() async {
    if (!mounted || _branches.isEmpty) return;

    final permission = await Geolocator.checkPermission()
        .timeout(const Duration(milliseconds: 150));
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      _setLocationGranted(true);
      await _useCurrentLocation();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      _setLocationGranted(false);
      _hasPromptedForLocation = true;
      if (!mounted) return;
      _showLocationSnack(
        AppLocalizations.of(context).locationPermissionDeniedMessage,
      );
      return;
    }

    _setLocationGranted(false);

    if (_hasPromptedForLocation) return;
    _hasPromptedForLocation = true;

    await _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    if (!mounted) return;

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      _setLocationGranted(true);
      await _useCurrentLocation();
      return;
    }

    _setLocationGranted(false);
    _showLocationSnack(
      AppLocalizations.of(context).locationPermissionDeniedMessage,
    );
  }

  Future<void> _useCurrentLocation() async {
    if (!mounted || _isRequestingLocation || !_locationGranted) return;
    _isRequestingLocation = true;
    try {
      final strings = AppLocalizations.of(context);
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationSnack(strings.locationServicesDisabledMessage);
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        _setLocationGranted(false);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 4));

      final userPoint = Point(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final nearest = _nearestBranchTo(userPoint);
      if (nearest != null) {
        _branchState.selectBranch(nearest);
      }
    } catch (error) {
      debugPrint('Failed to determine location: $error');
    } finally {
      _isRequestingLocation = false;
    }
  }

  void _setLocationGranted(bool value) {
    if (_locationGranted == value) return;
    if (!mounted) return;
    setState(() {
      _locationGranted = value;
    });
  }

  Branch? _nearestBranchTo(Point userPoint) {
    if (_branches.isEmpty) return null;
    Branch? closest;
    double minDistance = double.infinity;
    for (final branch in _branches) {
      final distance = _distanceMeters(branch.point, userPoint);
      if (distance < minDistance) {
        minDistance = distance;
        closest = branch;
      }
    }
    return closest;
  }

  double _distanceMeters(Point a, Point b) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final aCalc = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(lat1) *
            math.cos(lat2);
    final c = 2 * math.atan2(math.sqrt(aCalc), math.sqrt(1 - aCalc));
    return earthRadius * c;
  }

  double _degToRad(double value) => value * math.pi / 180.0;

  void _showLocationSnack(String message) {
    if (!mounted || message.isEmpty) return;
    showNavAwareSnackBar(
      context,
      content: Text(message),
    );
  }

  Future<void> _onMapCreated(YandexMapController controller) async {
    if (_disposed) return;
    _mapController = controller;
    final isDefaultBranchActive =
        _branches.isNotEmpty && _activeBranch.id == _branches.first.id;
    if (isDefaultBranchActive) {
      await _showBukharaOverview();
    } else {
      await _moveToBranch(_activeBranch, animate: false);
    }
  }

  Future<void> _showBukharaOverview() async {
    if (_disposed || _mapController == null) return;
    await _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _initialBukharaCenter,
          zoom: _initialBukharaZoom,
        ),
      ),
    );
  }

  Future<void> _moveToBranch(Branch branch, {bool animate = true}) async {
    if (_disposed || _mapController == null) return;
    final update = CameraUpdate.newCameraPosition(
      CameraPosition(target: branch.point, zoom: 15.2),
    );
    if (animate) {
      await _mapController!.moveCamera(
        update,
        animation: const MapAnimation(
          type: MapAnimationType.smooth,
          duration: 1,
        ),
      );
    } else {
      await _mapController!.moveCamera(update);
    }
  }

  Future<void> _selectBranch(Branch branch) async {
    if (_activeBranch.id == branch.id) return;
    _branchState.selectBranch(branch);
  }

  Future<void> _zoomBy(double delta) async {
    if (_disposed || _mapController == null) return;
    final cameraPosition = await _mapController!.getCameraPosition();
    final nextZoom = (cameraPosition.zoom + delta).clamp(3.0, 19.0);
    await _mapController!.moveCamera(
      CameraUpdate.zoomTo(nextZoom),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 0.3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth >= 700;
    final double mapHeight = isTablet ? 260 : 180;
    final double listBottomPadding = navAwareBottomPadding(context, extra: 24);

    return Scaffold(
      backgroundColor: screenBackgroundColor,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(defaultPadding, 20, defaultPadding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.locationsTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.changeBranchSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: bodyTextColor,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: mapHeight,
                child: _locationGranted
                    ? _MapContainer(
                        mapObjects: _mapObjects,
                        onMapCreated: (c) =>
                            Future.microtask(() => _onMapCreated(c)),
                        onZoomIn: () => _zoomBy(1.0),
                        onZoomOut: () => _zoomBy(-1.0),
                      )
                    : _LocationPlaceholder(
                        onAllow: () async {
                          _hasPromptedForLocation = true;
                          await _requestLocationPermission();
                        },
                      ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.locationsListHeader,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.only(bottom: listBottomPadding),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _branches.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final branch = _branches[index];
                    final isActive = branch == _activeBranch;
                    return _BranchCard(
                      branch: branch,
                      l10n: l10n,
                      isActive: isActive,
                      onTap: () => _selectBranch(branch),
                      onDirections: () => _openDirections(branch),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(Branch branch) async {
    final l10n = AppLocalizations.of(context);
    final url = Uri.parse(
      'https://yandex.com/maps/?pt=${branch.point.longitude},${branch.point.latitude}&z=16&l=map',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      showNavAwareSnackBar(
        context,
        content: Text(l10n.locationsDirectionsError),
      );
    }
  }
}

class _MapContainer extends StatelessWidget {
  const _MapContainer({
    required this.mapObjects,
    required this.onMapCreated,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final List<MapObject> mapObjects;
  final MapCreatedCallback onMapCreated;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
        child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            YandexMap(
              onMapCreated: onMapCreated,
              mapObjects: mapObjects,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              zoomGesturesEnabled: true,
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                children: [
                  _ZoomButton(
                    icon: Icons.add,
                    onPressed: onZoomIn,
                  ),
                  const SizedBox(height: 12),
                  _ZoomButton(
                    icon: Icons.remove,
                    onPressed: onZoomOut,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _LocationPlaceholder extends StatelessWidget {
  const _LocationPlaceholder({required this.onAllow});

  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.locationPermissionTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.locationPermissionDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: bodyTextColor,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: onAllow,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(l10n.locationPermissionAllow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          height: 44,
          width: 44,
          child: Icon(icon, color: titleColor),
        ),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.isActive,
    required this.onTap,
    required this.l10n,
    required this.onDirections,
  });

  final Branch branch;
  final bool isActive;
  final VoidCallback onTap;
  final AppStrings l10n;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: kDefaultDuration,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? primaryColor.withValues(alpha: 0.28)
                  : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FIRST ROW: Name + direction + arrow
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      branch.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Direction icon (yo'nalish)
                  InkWell(
                    onTap: onDirections,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.6),
                          width: 1.4,
                        ),
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.navigation_outlined,
                        size: 20,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  // Arrow
                ],
              ),

              const SizedBox(height: 6),

              // ADDRESS
              Text(
                branch.address,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: bodyTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // STATUS + WORK HOURS
              Row(
                children: [
                  _StatusBadgeSmall(label: l10n.openNow),
                  const SizedBox(width: 10),
                  Text(
                    l10n.dailySchedule,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: bodyTextColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadgeSmall extends StatelessWidget {
  const _StatusBadgeSmall({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: primaryColor, size: 8),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
