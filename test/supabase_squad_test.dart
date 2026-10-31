import 'package:flutter_test/flutter_test.dart';
import 'package:runway/app/squad.dart';
import 'package:runway/app/supabase_squad.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('every Squad failure becomes a message for the person', () {
    Future<String> failsWith(Object error) async {
      try {
        // Throws whatever a reply might: exceptions, errors, anything.
        // ignore: only_throw_errors
        await SupabaseSquad.guard<void>(() async => throw error);
      } on SquadException catch (e) {
        return e.message;
      }
      fail('$error got through');
    }

    test('server rules are worded for people', () async {
      expect(
        await failsWith(const PostgrestException(message: 'squad_full')),
        contains('full'),
      );
      expect(
        await failsWith(const PostgrestException(message: 'something_new')),
        'Something went wrong with Squad. Try again.',
      );
    });

    test('no connection', () async {
      expect(
        await failsWith(Exception('SocketException: offline')),
        contains('Check your connection'),
      );
    });

    test('a reply that isn\'t shaped as expected', () async {
      // A failed cast (`rows as List`) and `.single` on an empty reply.
      expect(await failsWith(TypeError()), isNotEmpty);
      expect(await failsWith(StateError('No element')), isNotEmpty);
    });

    test('its own messages pass through untouched', () async {
      expect(await failsWith(const SquadException('Nope')), 'Nope');
    });

    test('a result comes back as is', () async {
      expect(await SupabaseSquad.guard(() async => 42), 42);
    });
  });
}
