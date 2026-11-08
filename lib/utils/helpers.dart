/// Pure Dart helper functions used across SafeCircle.
///
/// This file deliberately has **no Flutter or Firebase imports** so that
/// every function can be unit-tested quickly (see test/helpers_test.dart).
library;

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a date like `08 Nov 2026, 14:05`.
String formatDateTime(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final hour = d.hour.toString().padLeft(2, '0');
  final minute = d.minute.toString().padLeft(2, '0');
  return '$day ${_months[d.month - 1]} ${d.year}, $hour:$minute';
}

/// Human friendly relative time such as `5 min ago` or `2 days ago`.
String timeAgo(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);

  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  if (diff.inDays < 7) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  return formatDateTime(time);
}

/// Returns a greeting that matches the time of day.
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Basic e-mail format check (the server performs the real validation).
bool isValidEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}

/// Keeps digits and an optional leading `+`, removing spaces, dashes etc.
String cleanPhone(String input) {
  final trimmed = input.trim();
  final hasPlus = trimmed.startsWith('+');
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return hasPlus ? '+$digits' : digits;
}

/// A phone number is accepted when it has 7 to 15 digits (ITU-T E.164).
bool isValidPhone(String input) {
  final digits = cleanPhone(input).replaceAll('+', '');
  return digits.length >= 7 && digits.length <= 15;
}

/// First letters of up to two words, upper-cased. Falls back to `?`.
String initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// Google Maps link that opens at the given coordinates.
String mapsLink(double latitude, double longitude) {
  return 'https://www.google.com/maps/search/?api=1&query='
      '${latitude.toStringAsFixed(6)},${longitude.toStringAsFixed(6)}';
}

/// The text sent to trusted contacts when SOS is triggered.
String buildSosMessage({
  required String name,
  double? latitude,
  double? longitude,
}) {
  final text = StringBuffer(
    'EMERGENCY! $name needs help (sent via SafeCircle).',
  );
  if (latitude != null && longitude != null) {
    text.write(' My live location: ${mapsLink(latitude, longitude)}');
  } else {
    text.write(' My location is unavailable, please call me immediately.');
  }
  return text.toString();
}

/// The text sent when the user simply wants to share where they are.
String buildLocationMessage({
  required String name,
  required double latitude,
  required double longitude,
}) {
  return '$name shared a location with you via SafeCircle: '
      '${mapsLink(latitude, longitude)}';
}

/// `tel:` link for placing a phone call.
Uri telUri(String phone) => Uri.parse('tel:${cleanPhone(phone)}');

/// `sms:` link with a pre-filled message body.
Uri smsUri(String phone, String message) {
  return Uri.parse(
    'sms:${cleanPhone(phone)}?body=${Uri.encodeComponent(message)}',
  );
}

/// WhatsApp click-to-chat link. The number must include its country code.
Uri whatsappUri(String phone, String message) {
  final digits = cleanPhone(phone).replaceAll('+', '');
  return Uri.parse(
    'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
  );
}
