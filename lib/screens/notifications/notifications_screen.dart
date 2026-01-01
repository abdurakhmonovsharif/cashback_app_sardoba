import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_localizations.dart';
import '../../constants.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../../services/notification_socket_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  List<AppNotification> _items = const [];
  bool _isLoading = true;
  String? _error;
  int _unreadCount = 0;
  bool _isMarking = false;
  StreamSubscription<AppNotification>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscription = NotificationSocketManager.instance.notificationStream.listen(
      (notification) {
        if (!mounted) return;
        setState(() {
          if (!_items.any((item) => item.id == notification.id)) {
            _items.insert(0, notification);
          }
        });
      },
    );
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _service.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _items = response.items;
        _unreadCount = response.unreadCount;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadNotifications();
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (_isMarking || notification.isRead) return;
    _isMarking = true;
    final updatedItems = _items.map((n) {
      if (n.id == notification.id) {
        return AppNotification(
          id: n.id,
          title: n.title,
          description: n.description,
          createdAt: n.createdAt,
          type: n.type,
          payload: n.payload,
          language: n.language,
          isRead: true,
          isSent: n.isSent,
          sentAt: n.sentAt,
        );
      }
      return n;
    }).toList();
    setState(() {
      _items = updatedItems;
      _unreadCount = (_unreadCount - 1).clamp(0, 9999);
    });
    try {
      await _service.markAsRead(notificationId: notification.id);
    } catch (_) {
      // Silently ignore failures; state already updated.
    } finally {
      _isMarking = false;
    }
  }

  @override
  void dispose() {
    _service.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = _buildBody(l10n);
    return Scaffold(
      backgroundColor: screenBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.notificationsTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: body,
      ),
    );
  }

  Widget _buildBody(AppStrings l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              l10n.notificationsScreenError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: bodyTextColor),
            ),
            if (_error!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: bodyTextColor,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
        padding: const EdgeInsets.all(defaultPadding * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: bodyTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.notificationsScreenEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: bodyTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      );
    }
    return RefreshIndicator(
      color: primaryColor,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  defaultPadding,
                  24,
                  defaultPadding,
                  32,
                ),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _NotificationTile(
                    item: item,
                    onTap: () => _markAsRead(item),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasUnread = !item.isRead;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.title,
                      style: textTheme.titleSmall?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (hasUnread) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(item.sentAt ?? item.createdAt),
                    style: textTheme.bodySmall?.copyWith(
                      color: bodyTextColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.description,
                style: textTheme.bodyMedium?.copyWith(
                  color: bodyTextColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month · $hour:$minute';
  }
}
