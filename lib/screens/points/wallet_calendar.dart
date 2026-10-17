// Transaction dates follow the same UTC+05:00 calendar as the cashback API.
// The returned wall time is for display only; it is not a new instant.
const _tashkentOffset = Duration(hours: 5);

DateTime walletTashkentWallTime(DateTime instant) =>
    instant.toUtc().add(_tashkentOffset);

DateTime walletTashkentDate(DateTime instant) {
  final wallTime = walletTashkentWallTime(instant);
  return DateTime(wallTime.year, wallTime.month, wallTime.day);
}
