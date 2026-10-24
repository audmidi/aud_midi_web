// @license
// Copyright (c) Audanika
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// ignore_for_file: avoid_print

import 'package:aud_midi_core/aud_midi_core.dart';
import 'package:aud_midi_standard/aud_midi_standard.dart';
import 'package:aud_midi_web/aud_midi_web.dart';

// Runs in a browser with Web MIDI; elsewhere start throws MidiUnsupported.
Future<void> main() async {
  final backend = WebMidiBackend();
  try {
    await backend.start(PrintingHost());
  } on MidiException catch (error) {
    print(error); // e.g. the user denied the permission
    return;
  }
  for (final port in backend.ports) {
    print('${port.direction.name}: ${port.name} (${port.id})');
  }
  await backend.stop();
}

/// Prints what the backend reports; apps get this from aud_midi's engine.
final class PrintingHost implements MidiBackendHost {
  @override
  final MidiClock clock = const MidiSystemClock();

  @override
  void portsChanged(List<MidiPortEvent> events) => print(events);

  @override
  void received(MidiPortId port, MidiPacket packet) => print(packet);

  @override
  void diagnostic(MidiDiagnostic diagnostic) => print(diagnostic);
}
