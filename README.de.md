# aud_midi_web

[English](README.md) | Deutsch

Web-MIDI-Backend für aud_midi, gebaut auf package:web. Das Browser-Backend
von aud_midi: `WebMidiBackend` macht aus der Web-MIDI-API Eingänge,
Ausgänge und Hotplug der aud_midi-Familie. Es läuft nur im Browser und
braucht einen sicheren Kontext (https oder localhost); Safari und alle
Browser unter iOS haben kein Web MIDI.

Teil der aud_midi-Familie, siehe [aud_midi](https://github.com/audmidi/aud_midi).

## Motivation

Dart- und Flutter-Apps sollen die MIDI-Geräte ihrer Nutzer auf jeder
Plattform über eine API erreichen, das Web eingeschlossen, ohne
Platform-Channels oder nativen Code. Dieses Paket holt den Browser in diese
Familie: die Web-MIDI-API hinter demselben `MidiBackend` wie die anderen
Plattformen, mit der Logik in reinem Dart, damit sie auf der Dart-VM
testbar ist.

- Web-MIDI-Ein- und Ausgänge und Hotplug
- Sysex und zeitgesteuertes Senden
- Übersetzung nach MIDI 2.0 auf Byte-Ports

## Installation

```bash
dart pub add aud_midi_web
```

- In einem iframe muss die einbettende Seite MIDI erlauben:
  `<iframe allow="midi">`; Server können `Permissions-Policy: midi=(self)`
  setzen
- `start` lässt den Browser um Erlaubnis fragen; aktuelle Chrome-Versionen
  fragen bei jedem Zugriff. `WebMidiBackend(sysEx: true)` fragt nach System
  Exclusive, einer stärkeren Berechtigung, MIDI-Geräte zu „steuern und neu
  zu programmieren“

## Verwendung

Das Backend starten, seine Ports ausgeben und es wieder stoppen. Das
Beispiel läuft in einem Browser mit Web MIDI; sonst wirft `start`
`MidiUnsupported`.

```dart
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
```

## Einschränkungen

- Web MIDI braucht einen sicheren Kontext: https oder localhost. Sonst fehlt
  `navigator.requestMIDIAccess` und `start` wirft `MidiUnsupported`
- Keine virtuellen Ports, kein Bluetooth-Scan, keine Netzwerk-Sessions: Web
  MIDI hat nichts davon
- Bluetooth-Geräte erscheinen nur, wenn das Betriebssystem sie gekoppelt
  hat (macOS, Windows), als gewöhnliche Ports
- Web MIDI gibt es nur im Haupt-Thread des Browsers, im Web läuft das
  Backend daher in der Seite, nicht in einem MIDI-Isolate
- `cancelPending` nutzt `MIDIOutput.clear()`, wo der Browser es hat;
  Chrome 153 hat es nicht, dort ist `capabilities.cancelPending` false
- Headless-Chrome verweigert Berechtigungsabfragen; `dart_test.yaml`
  übergibt `--disable-features=BlockMidiByDefault`, das MIDI ohne SysEx
  erlaubt. SysEx bleibt dort verweigert

| Browser | Web MIDI |
| --- | --- |
| Chrome 43+, Edge 79+, Opera 30+ | ja |
| Firefox 108+ | ja, nach Abfrage eines Site-Permission-Add-ons |
| Chrome Android, Samsung Internet | ja, ohne Bluetooth-MIDI |
| Safari, alle Browser unter iOS | nein |
| Firefox Android | nein |

## Dokumentation

- [Guides](doc/guides/)

## Funktionsweise

`WebMidiBackend` (Backend-Name `webmidi`) implementiert `MidiBackend` aus
aud_midi_core:

- `start` ruft `navigator.requestMIDIAccess({sysex, software})` auf. Kein
  Web MIDI oder kein sicherer Kontext → `MidiUnsupported`; verweigerte
  Berechtigung → `MidiPermissionDenied` (`sysEx`, wenn angefragt, sonst
  `midi`); jeder andere Fehler → `MidiNativeError` plus eine
  `nativeError`-Diagnose
- Jeder Web-MIDI-Port wird ein MIDI-1.0-Byte-Port auf einem synthetischen
  Gerät mit einem Port, Id `webmidi:input:<MIDIPort.id>` oder
  `webmidi:output:<MIDIPort.id>`, Transport `unknown`; MIDI 2.0 kommt aus der
  Übersetzung der Engine
- Eingänge liefern `MidiBytesPacket`s mit der Empfangszeit des Browsers auf
  der Paket-Uhr (`MidiClockMapper` auf `performance.now()`, alle 10 s und
  bei Hotplug neu gemessen)
- Ausgänge planen im Browser: `send(data, timestamp)` mit der
  Fälligkeitszeit. Bytes, die der Browser ablehnen würde (Running Status,
  geteiltes oder nicht erlaubtes SysEx, undefinierte Statusbytes,
  unvollständige Nachrichten), und Ausnahmen des Browsers werden zu
  Diagnosen
- Hotplug über `onstatechange` → `MidiPortAdded`, `MidiPortChanged`,
  `MidiPortRemoved`; ein offener Port, der verschwindet, wird geschlossen

Die Browser-API liegt hinter reinen Dart-Schnittstellen:

- `WebMidiApi`, `WebMidiAccess`, `WebMidiInputHandle` und
  `WebMidiOutputHandle` beschreiben die Browser-API in reinem Dart
- `lib/src/browser/web_midi_browser_api.dart` implementiert sie mit
  package:web; ein bedingter Import (`dart.library.js_interop`) wählt ihn
  im Browser, überall sonst `WebMidiUnavailableApi`
- `WebMidiBackend` enthält die ganze Logik gegen diese Schnittstellen, die
  Dart-VM testet sie daher mit einer Attrappe; `WebMidiMessageValidator`
  prüft Bytes so wie `MIDIOutput.send()`

## Status

Vor 1.0 — die API kann sich zwischen Minor-Versionen ändern.

Geprüft:

- Die Logik auf der Dart-VM gegen eine Attrappe der Browser-Schnittstelle,
  100 % Abdeckung pro Datei: `dart test`
- Im Headless-Chrome 153 mit dart2js und dart2wasm: `dart test -P browser`
  lädt den Adapter, fragt Zugriff mit und ohne SysEx an und startet und
  stoppt das Backend auf der echten API
- Über einen CoreMIDI-Loopback (`tool/macos_midi_loopback.swift`):
  Rundweg mit Empfangsstempeln innerhalb 1 ms nach dem Senden, 100 ms im
  Voraus geplante Nachrichten kommen zur Fälligkeit an (±0,1 ms), ein Paket
  kommt als ein Ereignis pro Nachricht an, abgelehnte Bytes werden zu
  Diagnosen. Hotplug von Hand mit Verzögerung und Lebensdauer des Tools

## Mitwirken

Siehe [doc/guides/develop-guide.md](doc/guides/develop-guide.md).

### Tests ausführen

```bash
dart test                        # logic, Dart VM
dart test -P browser             # adapter in Chrome, dart2js
dart test -P browser -c dart2wasm
swift tool/macos_midi_loopback.swift &   # enables the loopback tests
```

## Lizenz

MIT — siehe [LICENSE](LICENSE).
