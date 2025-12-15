import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../services/notification_preferences.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final NotificationPreferences _prefs = NotificationPreferences.instance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _prefs.addListener(_handlePreferencesChanged);
    _initialize();
  }

  @override
  void dispose() {
    _prefs.removeListener(_handlePreferencesChanged);
    super.dispose();
  }

  Future<void> _initialize() async {
    await _prefs.ensureInitialized();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _handlePreferencesChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Notifications',
          style: theme.textTheme.titleLarge?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  defaultPadding,
                  24,
                  defaultPadding,
                  32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _NotificationCard(
                      title: 'Channels',
                      children: [
                        _NotificationToggleTile(
                          label: 'Push notifications',
                          description:
                              'Order status, loyalty updates and special alerts.',
                          value: _prefs.pushEnabled,
                          onChanged: _prefs.setPushEnabled,
                        ),
                        _NotificationToggleTile(
                          label: 'SMS messages',
                          description:
                              'Receive text messages for delivery updates.',
                          value: _prefs.smsEnabled,
                          onChanged: _prefs.setSmsEnabled,
                        ),
                        _NotificationToggleTile(
                          label: 'Email',
                          description:
                              'Monthly statements, receipts and newsletters.',
                          value: _prefs.emailEnabled,
                          onChanged: _prefs.setEmailEnabled,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _NotificationCard(
                      title: 'Preferences',
                      children: [
                        _NotificationToggleTile(
                          label: 'Order updates',
                          description:
                              'Be notified about order progress and couriers.',
                          value: _prefs.orderUpdates,
                          onChanged: _prefs.setOrderUpdates,
                        ),
                        _NotificationToggleTile(
                          label: 'Promotions',
                          description:
                              'Get personalised offers, discounts and events.',
                          value: _prefs.promotions,
                          onChanged: _prefs.setPromotions,
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ..._separated(children, const SizedBox(height: 12)),
        ],
      ),
    );
  }

  List<Widget> _separated(List<Widget> items, Widget separator) {
    if (items.length <= 1) return items;
    return [
      for (var i = 0; i < items.length; i++) ...[
        items[i],
        if (i != items.length - 1) separator,
      ]
    ];
  }
}

class _NotificationToggleTile extends StatelessWidget {
  const _NotificationToggleTile({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: bodyTextColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return primaryColor;
              }
              return Colors.white;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return primaryColor.withValues(alpha: 0.3);
              }
              return Colors.black.withValues(alpha: 0.1);
            }),
          ),
        ],
      ),
    );
  }
}
