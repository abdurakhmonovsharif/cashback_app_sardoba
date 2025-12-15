import 'dart:async';

import '../models/account.dart';

/// Broadcast stream that shares account changes across the app.
final AccountStream accountStream = AccountStream._();

class AccountStream {
  AccountStream._();

  final StreamController<Account> _controller =
      StreamController<Account>.broadcast();
  Account? _latestAccount;

  Stream<Account> get stream => _controller.stream;

  Account? get latest => _latestAccount;

  void emit(Account account) {
    if (_controller.isClosed) return;
    _latestAccount = account;
    _controller.add(account);
  }

  void dispose() {
    _controller.close();
  }
}
