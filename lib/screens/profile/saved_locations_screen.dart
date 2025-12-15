import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/saved_location.dart';
import '../../services/saved_locations_service.dart';
import '../../utils/snackbar_utils.dart';

class SavedLocationsScreen extends StatefulWidget {
  const SavedLocationsScreen({super.key});

  @override
  State<SavedLocationsScreen> createState() => _SavedLocationsScreenState();
}

class _SavedLocationsScreenState extends State<SavedLocationsScreen> {
  final SavedLocationsService _service = SavedLocationsService.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service.addListener(_handleServiceUpdate);
    _bootstrap();
  }

  @override
  void dispose() {
    _service.removeListener(_handleServiceUpdate);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _service.ensureInitialized();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _handleServiceUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _addLocation() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SavedLocationFormScreen(),
      ),
    );
  }

  Future<void> _editLocation(SavedLocation location) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavedLocationFormScreen(location: location),
      ),
    );
  }

  Future<void> _deleteLocation(SavedLocation location) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete location'),
            content: Text(
              'Remove "${location.label}" from your saved locations?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFED5A5A)),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _service.removeLocation(location.id);
    if (!mounted) return;
    showNavAwareSnackBar(
      context,
      content: const Text('Location removed'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locations = _service.locations;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Saved locations',
          style: theme.textTheme.titleLarge?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLocation,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add new'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  defaultPadding,
                  24,
                  defaultPadding,
                  32,
                ),
                child: locations.isEmpty
                    ? _EmptyState(theme: theme)
                    : ListView.separated(
                        itemBuilder: (context, index) {
                          final location = locations[index];
                          return _LocationCard(
                            location: location,
                            onEdit: () => _editLocation(location),
                            onDelete: () => _deleteLocation(location),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemCount: locations.length,
                      ),
              ),
            ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.onEdit,
    required this.onDelete,
  });

  final SavedLocation location;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeChip = _locationTypeChip(location.type);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    location.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.addressLine,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (location.details != null &&
                    location.details!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    location.details!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: bodyTextColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          typeChip,
        ],
      ),
    );
  }

  Widget _locationTypeChip(SavedLocationType type) {
    late final String label;
    late final Color color;
    switch (type) {
      case SavedLocationType.home:
        label = 'Home';
        color = const Color(0xFF0DD277);
        break;
      case SavedLocationType.work:
        label = 'Work';
        color = const Color(0xFF8C6CFF);
        break;
      case SavedLocationType.other:
        label = 'Other';
        color = primaryColor;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.push_pin_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SavedLocationFormScreen extends StatefulWidget {
  const SavedLocationFormScreen({super.key, this.location});

  final SavedLocation? location;

  @override
  State<SavedLocationFormScreen> createState() =>
      _SavedLocationFormScreenState();
}

class _SavedLocationFormScreenState extends State<SavedLocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelController;
  late final TextEditingController _addressController;
  late final TextEditingController _detailsController;
  SavedLocationType _type = SavedLocationType.other;
  bool _isSaving = false;

  final SavedLocationsService _service = SavedLocationsService.instance;

  @override
  void initState() {
    super.initState();
    final location = widget.location;
    _labelController = TextEditingController(text: location?.label ?? '');
    _addressController =
        TextEditingController(text: location?.addressLine ?? '');
    _detailsController = TextEditingController(text: location?.details ?? '');
    _type = location?.type ?? SavedLocationType.other;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final location = widget.location;
    final updated = (location ??
            SavedLocation(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              label: '',
              addressLine: '',
            ))
        .copyWith(
      label: _labelController.text.trim(),
      addressLine: _addressController.text.trim(),
      details: _detailsController.text.trim().isEmpty
          ? null
          : _detailsController.text.trim(),
      type: _type,
    );
    if (location == null) {
      await _service.addLocation(updated);
    } else {
      await _service.updateLocation(updated);
    }
    if (!mounted) return;
    showNavAwareSnackBar(
      context,
      content: Text(
        location == null ? 'Location added' : 'Location updated',
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.location != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          isEditing ? 'Edit location' : 'Add location',
          style: theme.textTheme.titleLarge?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            defaultPadding,
            24,
            defaultPadding,
            32,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLabel(theme, 'Label'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _labelController,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration('e.g. Home'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Please enter a label';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildLabel(theme, 'Address'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: _fieldDecoration('Street and house number'),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Please enter address details';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildLabel(theme, 'Additional details'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _detailsController,
                    maxLines: 2,
                    decoration: _fieldDecoration('Entrance, floor or notes'),
                  ),
                  const SizedBox(height: 18),
                  _buildLabel(theme, 'Location type'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<SavedLocationType>(
                    initialValue: _type,
                    decoration: _fieldDecoration('Select type'),
                    items: const [
                      DropdownMenuItem(
                        value: SavedLocationType.home,
                        child: Text('Home'),
                      ),
                      DropdownMenuItem(
                        value: SavedLocationType.work,
                        child: Text('Work'),
                      ),
                      DropdownMenuItem(
                        value: SavedLocationType.other,
                        child: Text('Other'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _type = value);
                    },
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Save changes' : 'Add location'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: titleColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF6F8FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 48,
              color: primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No saved locations yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your home, work or other locations to speed up checkout.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: bodyTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
