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

/// Measurements for the visible map area, excluding the top branch control
/// and the shared floating navigation.
@immutable
class LocationMapGeometry {
  const LocationMapGeometry({
    required this.viewportHeight,
    required this.navClearance,
    required this.headerTop,
    required this.headerHeight,
  });

  factory LocationMapGeometry.fromViewport({
    required double viewportHeight,
    required double navClearance,
    required double safeTop,
    required double headerHeight,
  }) {
    return LocationMapGeometry(
      viewportHeight: viewportHeight,
      navClearance: navClearance,
      headerTop: safeTop + 12,
      headerHeight: headerHeight,
    );
  }

  final double viewportHeight;
  final double navClearance;
  final double headerTop;
  final double headerHeight;

  double get visibleTop => headerTop + headerHeight + 16;

  double get visibleBottom => viewportHeight - navClearance - 16;
}

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final BranchState _branchState = BranchState.instance;
  late Branch _activeBranch = _branchState.activeBranch;
  YandexMapController? _mapController;
  bool _isRequestingLocation = false;
  bool _disposed = false;
  bool _mapReady = false;
  bool _isBranchPickerOpen = false;
  LocationMapGeometry? _currentGeometry;

  @override
  void initState() {
    super.initState();
    _branchState.addListener(_handleGlobalBranchChange);
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

  List<Branch> get _validBranches => _branches.where((branch) {
        final latitude = branch.point.latitude;
        final longitude = branch.point.longitude;
        return latitude.isFinite &&
            longitude.isFinite &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180;
      }).toList(growable: false);

  List<MapObject> get _mapObjects {
    return _validBranches.map((branch) {
      final isActive = branch.id == _activeBranch.id;
      return PlacemarkMapObject(
        mapId: MapObjectId(branch.id),
        point: branch.point,
        consumeTapEvents: true,
        opacity: isActive ? 1 : 0.68,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: _branchPinIcon,
            scale: isActive ? 1.2 : 0.9,
          ),
        ),
        onTap: (_, __) => _selectBranch(branch),
      );
    }).toList(growable: false);
  }

  Future<void> _requestLocationPermission() async {
    if (!mounted || _isRequestingLocation) return;
    _isRequestingLocation = true;
    setState(() {});
    try {
      final strings = AppLocalizations.of(context);
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationSnack(strings.locationServicesDisabledMessage);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (!mounted) return;
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        _showLocationSnack(strings.locationPermissionDeniedMessage);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      ).timeout(const Duration(seconds: 5));
      if (!mounted) return;

      final point = Point(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final nearest = _nearestBranchTo(point);
      if (nearest != null) {
        _branchState.selectBranch(nearest);
      }
    } catch (error) {
      debugPrint('Failed to determine location: $error');
      if (mounted) {
        _showLocationSnack(
          AppLocalizations.of(context).locationPermissionDeniedMessage,
        );
      }
    } finally {
      _isRequestingLocation = false;
      if (mounted) setState(() {});
    }
  }

  Branch? _nearestBranchTo(Point userPoint) {
    if (_validBranches.isEmpty) return null;
    Branch? closest;
    double minDistance = double.infinity;
    for (final branch in _validBranches) {
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
    if (mounted) setState(() => _mapReady = true);
    final branches = _validBranches;
    if (branches.isEmpty) return;
    // The native map callback can arrive before its first render. Wait for the
    // map surface so the initial camera update is not ignored on iOS.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_disposed || _mapController != controller) return;
    if (branches.length == 1) {
      await _moveToBranch(branches.first, animate: false);
      return;
    }
    final latitudes = branches.map((branch) => branch.point.latitude);
    final longitudes = branches.map((branch) => branch.point.longitude);
    final overviewPosition = CameraPosition(
      target: Point(
        latitude: (latitudes.reduce(math.max) + latitudes.reduce(math.min)) / 2,
        longitude:
            (longitudes.reduce(math.max) + longitudes.reduce(math.min)) / 2,
      ),
      zoom: 9.4,
    );
    // Keep every current Bukhara branch in a stable, padded overview. Native
    // bounds fitting is inconsistent on iOS when fixed map controls overlap it.
    await controller.moveCamera(
      CameraUpdate.newCameraPosition(overviewPosition),
    );
  }

  Future<void> _moveToBranch(Branch branch, {bool animate = true}) async {
    if (_disposed || _mapController == null) return;
    const zoom = 15.2;
    var target = branch.point;
    final geometry = _currentGeometry;
    if (geometry != null) {
      final visibleCenter = (geometry.visibleTop + geometry.visibleBottom) / 2;
      final verticalOffsetPixels =
          (geometry.viewportHeight / 2) - visibleCenter;
      final metersPerPixel = 156543.03392 *
          math.cos(_degToRad(branch.point.latitude)) /
          math.pow(2, zoom);
      target = Point(
        latitude: branch.point.latitude -
            verticalOffsetPixels * metersPerPixel / 111320,
        longitude: branch.point.longitude,
      );
    }
    final update = CameraUpdate.newCameraPosition(
      CameraPosition(target: target, zoom: zoom),
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

  Future<void> _focusBranch(Branch branch) async {
    if (mounted) {
      setState(() => _isBranchPickerOpen = false);
    }
    if (_activeBranch.id != branch.id) {
      _branchState.selectBranch(branch);
    }
    await _moveToBranch(branch);
  }

  Future<void> _selectBranch(Branch branch) => _focusBranch(branch);

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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: screenBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final headerHeight = math
              .max(
                84.0,
                media.textScaler.scale(14) * 3.9 + 28,
              )
              .toDouble();
          final navClearance = navAwareBottomPadding(context);
          final geometry = LocationMapGeometry.fromViewport(
            viewportHeight: constraints.maxHeight,
            navClearance: navClearance,
            safeTop: media.padding.top,
            headerHeight: headerHeight,
          );
          _currentGeometry = geometry;

          return Stack(
            fit: StackFit.expand,
            children: [
              _MapContainer(
                mapObjects: _mapObjects,
                mapReady: _mapReady,
                onMapCreated: _onMapCreated,
              ),
              Positioned(
                top: geometry.headerTop,
                left: defaultPadding,
                right: defaultPadding,
                child: _BranchMapHeader(
                  label: l10n.catalogBranchLabel,
                  activeBranch: _activeBranch,
                  branches: _validBranches,
                  isExpanded: _isBranchPickerOpen,
                  onToggle: () => setState(
                      () => _isBranchPickerOpen = !_isBranchPickerOpen),
                  onSelect: _focusBranch,
                ),
              ),
              if (!_isBranchPickerOpen)
                Positioned(
                  top: geometry.visibleTop,
                  right: defaultPadding,
                  child: _MapZoomControls(
                    onZoomIn: () => _zoomBy(1),
                    onZoomOut: () => _zoomBy(-1),
                    l10n: l10n,
                  ),
                ),
              Positioned(
                right: defaultPadding,
                bottom: navClearance + 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ZoomButton(
                      icon: Icons.my_location_rounded,
                      tooltip: l10n.locationUseCurrent,
                      onPressed: _requestLocationPermission,
                      isLoading: _isRequestingLocation,
                    ),
                    const SizedBox(height: 8),
                    _MapDirectionsButton(
                      tooltip: l10n.locationDirectionsFor(_activeBranch.name),
                      onPressed: () => _openDirections(_activeBranch),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openDirections(Branch branch) async {
    final url = Uri.parse(
      'https://yandex.com/maps/?pt=${branch.point.longitude},${branch.point.latitude}&z=16&l=map',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        mounted) {
      _showLocationSnack(AppLocalizations.of(context).locationsDirectionsError);
    }
  }
}

class _MapContainer extends StatelessWidget {
  const _MapContainer({
    required this.mapObjects,
    required this.mapReady,
    required this.onMapCreated,
  });

  final List<MapObject> mapObjects;
  final bool mapReady;
  final MapCreatedCallback onMapCreated;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          YandexMap(
            onMapCreated: onMapCreated,
            mapObjects: mapObjects,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            zoomGesturesEnabled: true,
          ),
          if (!mapReady)
            const Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
        ],
      ),
    );
  }
}

class _MapDirectionsButton extends StatelessWidget {
  const _MapDirectionsButton({
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: primaryColor,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Tooltip(
          message: tooltip,
          excludeFromSemantics: true,
          child: Semantics(
            button: true,
            label: tooltip,
            onTap: onPressed,
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: 48,
              child: IconButton(
                onPressed: onPressed,
                icon: const Icon(Icons.directions_rounded),
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
}

class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.l10n,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final AppStrings l10n;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            icon: Icons.add_rounded,
            tooltip: l10n.locationsZoomIn,
            onPressed: onZoomIn,
          ),
          const SizedBox(height: 8),
          _ZoomButton(
            icon: Icons.remove_rounded,
            tooltip: l10n.locationsZoomOut,
            onPressed: onZoomOut,
          ),
        ],
      );
}

class _BranchMapHeader extends StatelessWidget {
  const _BranchMapHeader({
    required this.label,
    required this.activeBranch,
    required this.branches,
    required this.isExpanded,
    required this.onToggle,
    required this.onSelect,
  });

  final String label;
  final Branch activeBranch;
  final List<Branch> branches;
  final bool isExpanded;
  final VoidCallback onToggle;
  final ValueChanged<Branch> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semanticsLabel = '$label: ${activeBranch.name}. '
        '${activeBranch.address}.';

    return Semantics(
      container: true,
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              expanded: isExpanded,
              label: semanticsLabel,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: const Border.fromBorderSide(
                      BorderSide(color: appBorderColor),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppRadius.control),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: bodyTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeBranch.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: titleColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              activeBranch.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: bodyTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: primaryColor,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: isExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        child: Column(
                          children: [
                            for (final branch in branches)
                              _BranchPickerOption(
                                branch: branch,
                                isSelected: branch.id == activeBranch.id,
                                onTap: () => onSelect(branch),
                              ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchPickerOption extends StatelessWidget {
  const _BranchPickerOption({
    required this.branch,
    required this.isSelected,
    required this.onTap,
  });

  final Branch branch;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${branch.name}. ${branch.address}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.storefront_outlined,
                color: isSelected ? primaryColor : bodyTextColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      branch.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: bodyTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Kept private until the next major locations redesign removes the legacy
// branch-list implementation entirely.
// ignore: unused_element
class _BranchSheet extends StatelessWidget {
  const _BranchSheet({
    required this.scrollController,
    required this.collapsedHeight,
    required this.branches,
    required this.activeBranch,
    required this.l10n,
    required this.distanceLabel,
    required this.nearbyFirst,
    required this.openNowOnly,
    required this.locationAvailable,
    required this.onNearbyChanged,
    required this.onOpenNowChanged,
    required this.onSelect,
    required this.onDirections,
  });

  final ScrollController scrollController;
  final double collapsedHeight;
  final List<Branch> branches;
  final Branch activeBranch;
  final AppStrings l10n;
  final String? Function(Branch) distanceLabel;
  final bool nearbyFirst;
  final bool openNowOnly;
  final bool locationAvailable;
  final ValueChanged<bool> onNearbyChanged;
  final ValueChanged<bool> onOpenNowChanged;
  final ValueChanged<Branch> onSelect;
  final ValueChanged<Branch> onDirections;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsed = constraints.maxHeight <= collapsedHeight + 1;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: screenBackgroundColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.panel),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.panel),
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                defaultPadding,
                collapsed ? 4 : 8,
                defaultPadding,
                collapsed ? 4 : 16,
              ),
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: bodyTextColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                SizedBox(height: collapsed ? 8 : 14),
                if (collapsed)
                  _BranchSummaryCard(
                    branch: activeBranch,
                    l10n: l10n,
                    distanceLabel: distanceLabel(activeBranch),
                    onDirections: () => onDirections(activeBranch),
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.locationsTitle,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      Text(
                        '${branches.length}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: bodyTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.locationsListHeader,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: bodyTextColor,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _LocationFilterChip(
                        label: l10n.locationNearby,
                        selected: nearbyFirst,
                        icon: Icons.near_me_outlined,
                        onSelected: onNearbyChanged,
                      ),
                      _LocationFilterChip(
                        label: l10n.locationOpenNow,
                        selected: openNowOnly,
                        icon: Icons.schedule_rounded,
                        onSelected: onOpenNowChanged,
                      ),
                      if (nearbyFirst && locationAvailable)
                        Chip(
                          avatar:
                              const Icon(Icons.my_location_rounded, size: 17),
                          label: Text(l10n.locationSortedNearby),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (branches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          l10n.locationsEmpty,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: bodyTextColor,
                                  ),
                        ),
                      ),
                    )
                  else
                    ...branches.map((branch) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BranchCard(
                            branch: branch,
                            l10n: l10n,
                            isActive: branch.id == activeBranch.id,
                            distanceLabel: distanceLabel(branch),
                            onTap: () => onSelect(branch),
                            onDirections: () => onDirections(branch),
                          ),
                        )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocationFilterChip extends StatelessWidget {
  const _LocationFilterChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
        label: Text(label),
        avatar: Icon(icon, size: 17),
        selected: selected,
        showCheckmark: false,
        onSelected: onSelected,
        selectedColor: primaryColor.withValues(alpha: 0.1),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: selected ? primaryColor : appBorderColor,
        ),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? primaryColor : titleColor,
              fontWeight: FontWeight.w600,
            ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
      );
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: tooltip,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: tooltip,
          onTap: onPressed,
          excludeSemantics: true,
          child: IconButton(
            onPressed: onPressed,
            style: IconButton.styleFrom(shape: const CircleBorder()),
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: titleColor),
          ),
        ),
      ),
    );
  }
}

class _BranchSummaryCard extends StatelessWidget {
  const _BranchSummaryCard({
    required this.branch,
    required this.l10n,
    required this.distanceLabel,
    required this.onDirections,
  });

  final Branch branch;
  final AppStrings l10n;
  final String? distanceLabel;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: const Border.fromBorderSide(BorderSide(color: appBorderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  distanceLabel == null
                      ? branch.address
                      : '${branch.address} · $distanceLabel',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: bodyTextColor,
                        fontSize: 14,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.locationDirectionsFor(branch.name),
            onPressed: onDirections,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            icon: const Icon(Icons.directions_outlined, color: primaryColor),
          ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.branch,
    required this.isActive,
    required this.distanceLabel,
    required this.onTap,
    required this.l10n,
    required this.onDirections,
  });

  final Branch branch;
  final bool isActive;
  final String? distanceLabel;
  final VoidCallback onTap;
  final AppStrings l10n;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      selected: isActive,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: AnimatedContainer(
            duration: kDefaultDuration,
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: isActive
                    ? primaryColor.withValues(alpha: 0.32)
                    : appBorderColor,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        branch.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Tooltip(
                      message: l10n.locationDirectionsFor(branch.name),
                      excludeFromSemantics: true,
                      child: Semantics(
                        button: true,
                        label: l10n.locationDirectionsFor(branch.name),
                        onTap: onDirections,
                        excludeSemantics: true,
                        child: IconButton(
                          onPressed: onDirections,
                          constraints: const BoxConstraints.tightFor(
                            width: 48,
                            height: 48,
                          ),
                          style: IconButton.styleFrom(
                            foregroundColor: primaryColor,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                              color: primaryColor.withValues(alpha: 0.35),
                            ),
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(Icons.directions_outlined, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // ADDRESS
                Text(
                  branch.address,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: bodyTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 16,
                      color: bodyTextColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.dailySchedule,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: bodyTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (distanceLabel != null) ...[
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.near_me_outlined,
                        size: 15,
                        color: bodyTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distanceLabel!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: bodyTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
