import 'package:flutter_test/flutter_test.dart';
import 'package:safecircle/utils/helpers.dart';

void main() {
  group('cleanPhone / isValidPhone', () {
    test('removes spaces, dashes and brackets', () {
      expect(cleanPhone('98765 43210'), equals('9876543210'));
      expect(cleanPhone('(040) 2345-6789'), equals('04023456789'));
    });

    test('keeps a leading plus sign', () {
      expect(cleanPhone(' +91 98765-43210 '), equals('+919876543210'));
    });

    test('accepts 7 to 15 digits only', () {
      expect(isValidPhone('+919876543210'), isTrue);
      expect(isValidPhone('1234567'), isTrue);
      expect(isValidPhone('12345'), isFalse);
      expect(isValidPhone('1234567890123456'), isFalse);
      expect(isValidPhone('abcdefg'), isFalse);
    });
  });

  group('isValidEmail', () {
    test('accepts normal addresses', () {
      expect(isValidEmail('student@example.com'), isTrue);
      expect(isValidEmail('  a.b@c.co.in '), isTrue);
    });

    test('rejects malformed addresses', () {
      expect(isValidEmail('student'), isFalse);
      expect(isValidEmail('student@'), isFalse);
      expect(isValidEmail('student@example'), isFalse);
      expect(isValidEmail('stu dent@example.com'), isFalse);
    });
  });

  group('initials', () {
    test('uses first and last word', () {
      expect(initials('Asha Rani Verma'), equals('AV'));
      expect(initials('priya'), equals('P'));
      expect(initials('   '), equals('?'));
    });
  });

  group('links and messages', () {
    test('mapsLink uses six decimal places', () {
      expect(
        mapsLink(17.385044, 78.486671),
        equals(
          'https://www.google.com/maps/search/?api=1&query=17.385044,78.486671',
        ),
      );
    });

    test('SOS message contains name and maps link when location known', () {
      final message = buildSosMessage(
        name: 'Asha',
        latitude: 17.385,
        longitude: 78.4867,
      );
      expect(message.contains('Asha'), isTrue);
      expect(message.contains('google.com/maps'), isTrue);
      expect(message.contains('17.385000,78.486700'), isTrue);
    });

    test('SOS message asks for a call when location is missing', () {
      final message = buildSosMessage(name: 'Asha');
      expect(message.contains('google.com/maps'), isFalse);
      expect(message.contains('call me'), isTrue);
    });

    test('location message mentions the sender', () {
      final message = buildLocationMessage(
        name: 'Ravi',
        latitude: 1.5,
        longitude: 2.5,
      );
      expect(message.startsWith('Ravi shared'), isTrue);
    });

    test('tel, sms and WhatsApp URIs are built correctly', () {
      expect(telUri('+91 98765 43210').toString(), equals('tel:+919876543210'));

      final sms = smsUri('9876543210', 'Help me');
      expect(sms.scheme, equals('sms'));
      expect(sms.toString(), equals('sms:9876543210?body=Help%20me'));

      final wa = whatsappUri('+91 98765 43210', 'Hi there');
      expect(
        wa.toString(),
        equals('https://wa.me/919876543210?text=Hi%20there'),
      );
    });
  });

  group('date and time', () {
    test('formatDateTime pads day, hour and minute', () {
      expect(
        formatDateTime(DateTime(2026, 11, 8, 4, 5)),
        equals('08 Nov 2026, 04:05'),
      );
    });

    test('timeAgo returns friendly relative text', () {
      final now = DateTime(2026, 11, 8, 12, 0);
      expect(
        timeAgo(now.subtract(const Duration(seconds: 20)), now: now),
        equals('just now'),
      );
      expect(
        timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
        equals('5 min ago'),
      );
      expect(
        timeAgo(now.subtract(const Duration(hours: 3)), now: now),
        equals('3 hr ago'),
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 1)), now: now),
        equals('1 day ago'),
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 3)), now: now),
        equals('3 days ago'),
      );
      expect(
        timeAgo(DateTime(2026, 10, 1, 9, 30), now: now),
        equals('01 Oct 2026, 09:30'),
      );
    });

    test('greetingFor follows the time of day', () {
      expect(greetingFor(DateTime(2026, 1, 1, 8)), equals('Good morning'));
      expect(greetingFor(DateTime(2026, 1, 1, 13)), equals('Good afternoon'));
      expect(greetingFor(DateTime(2026, 1, 1, 20)), equals('Good evening'));
    });
  });
}
