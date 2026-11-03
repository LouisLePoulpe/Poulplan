import 'dart:io';
import 'dart:ui' as ui;

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _itemInterface = 'org.kde.StatusNotifierItem';
const _menuInterface = 'com.canonical.dbusmenu';
const _itemPath = '/StatusNotifierItem';
const _menuPath = '/MenuBar';

/// Icon in the system tray of KDE Plasma (StatusNotifierItem over D-Bus,
/// pure Dart: no native library to ship). Left click shows the window;
/// the menu offers « Ouvrir Poulplan » and « Quitter ».
class LinuxTray {
  LinuxTray({required this.onOpen, required this.onQuit});

  final VoidCallback onOpen;
  final VoidCallback onQuit;
  DBusClient? _client;
  _TrayItem? _item;

  static bool get supported => !kIsWeb && Platform.isLinux;

  Future<void> start() async {
    if (!supported) return;
    try {
      final client = DBusClient.session();
      final pixmaps = [
        for (final size in [22, 32, 64]) await _pixmap(size),
      ];
      final item = _TrayItem(pixmaps, onOpen);
      await client.registerObject(item);
      await client.registerObject(_TrayMenu(onOpen: onOpen, onQuit: onQuit));
      final name = 'org.kde.StatusNotifierItem-$pid-1';
      await client.requestName(name);
      await client.callMethod(
        destination: 'org.kde.StatusNotifierWatcher',
        path: DBusObjectPath('/StatusNotifierWatcher'),
        interface: 'org.kde.StatusNotifierWatcher',
        name: 'RegisterStatusNotifierItem',
        values: [DBusString(name)],
        replySignature: DBusSignature(''),
      );
      _client = client;
      _item = item;
    } catch (error) {
      // No tray host (other desktops): the app works without it.
      debugPrint('Tray unavailable: $error');
    }
  }

  /// Tooltip line, e.g. the next event.
  Future<void> setDescription(String text) async => _item?.setDescription(text);

  Future<void> dispose() async => _client?.close();

  /// ARGB32, network byte order, as the protocol expects.
  static Future<(int, int, Uint8List)> _pixmap(int size) async {
    final data = await rootBundle.load('assets/branding/poulplan-logo.png');
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: size,
      targetHeight: size,
    );
    final image = (await codec.getNextFrame()).image;
    final rgba = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!.buffer.asUint8List();
    final argb = Uint8List(rgba.length);
    for (var i = 0; i < rgba.length; i += 4) {
      argb[i] = rgba[i + 3];
      argb[i + 1] = rgba[i];
      argb[i + 2] = rgba[i + 1];
      argb[i + 3] = rgba[i + 2];
    }
    return (size, size, argb);
  }
}

class _TrayItem extends DBusObject {
  _TrayItem(this._pixmaps, this._onOpen) : super(DBusObjectPath(_itemPath));

  final List<(int, int, Uint8List)> _pixmaps;
  final VoidCallback _onOpen;
  String _description = '';

  DBusValue get _pixmapValue => DBusArray(DBusSignature('(iiay)'), [
    for (final (w, h, bytes) in _pixmaps)
      DBusStruct([DBusInt32(w), DBusInt32(h), DBusArray.byte(bytes)]),
  ]);

  Map<String, DBusValue> get _properties => {
    'Category': const DBusString('ApplicationStatus'),
    'Id': const DBusString('poulplan'),
    'Title': const DBusString('Poulplan'),
    'Status': const DBusString('Active'),
    'IconName': const DBusString(''),
    'IconPixmap': _pixmapValue,
    'ItemIsMenu': const DBusBoolean(false),
    'Menu': DBusObjectPath(_menuPath),
    'ToolTip': DBusStruct([
      const DBusString(''),
      DBusArray(DBusSignature('(iiay)'), const []),
      const DBusString('Poulplan'),
      DBusString(_description),
    ]),
  };

  Future<void> setDescription(String text) async {
    _description = text;
    await emitSignal(_itemInterface, 'NewToolTip');
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface != _itemInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (call.name) {
      case 'Activate':
      case 'SecondaryActivate':
        _onOpen();
        return DBusMethodSuccessResponse();
      case 'ContextMenu':
      case 'Scroll':
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = _properties[name];
    if (interface != _itemInterface || value == null) {
      return DBusMethodErrorResponse.unknownProperty();
    }
    return DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(
        interface == _itemInterface ? _properties : {},
      );
}

/// Minimal com.canonical.dbusmenu: two entries and a separator.
class _TrayMenu extends DBusObject {
  _TrayMenu({required this.onOpen, required this.onQuit})
    : super(DBusObjectPath(_menuPath));

  final VoidCallback onOpen;
  final VoidCallback onQuit;

  static const _open = 1;
  static const _separator = 2;
  static const _quit = 3;

  Map<int, Map<String, DBusValue>> get _items => {
    _open: {'label': const DBusString('Ouvrir Poulplan')},
    _separator: {'type': const DBusString('separator')},
    _quit: {'label': const DBusString('Quitter')},
  };

  DBusStruct _node(int id, Map<String, DBusValue> props, List<int> children) =>
      DBusStruct([
        DBusInt32(id),
        DBusDict.stringVariant(props),
        DBusArray(DBusSignature('v'), [
          for (final child in children)
            DBusVariant(_node(child, _items[child]!, const [])),
        ]),
      ]);

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface != _menuInterface) {
      return DBusMethodErrorResponse.unknownInterface();
    }
    switch (call.name) {
      case 'GetLayout':
        return DBusMethodSuccessResponse([
          const DBusUint32(1),
          _node(
            0,
            {'children-display': const DBusString('submenu')},
            [_open, _separator, _quit],
          ),
        ]);
      case 'GetGroupProperties':
        final ids = (call.values[0] as DBusArray).children
            .map((v) => (v as DBusInt32).value)
            .where(_items.containsKey);
        return DBusMethodSuccessResponse([
          DBusArray(DBusSignature('(ia{sv})'), [
            for (final id in ids)
              DBusStruct([DBusInt32(id), DBusDict.stringVariant(_items[id]!)]),
          ]),
        ]);
      case 'GetProperty':
        final id = (call.values[0] as DBusInt32).value;
        final name = (call.values[1] as DBusString).value;
        final value = _items[id]?[name];
        if (value == null) return DBusMethodErrorResponse.unknownProperty();
        return DBusMethodSuccessResponse([DBusVariant(value)]);
      case 'Event':
        final id = (call.values[0] as DBusInt32).value;
        final event = (call.values[1] as DBusString).value;
        if (event == 'clicked') _clicked(id);
        return DBusMethodSuccessResponse();
      case 'EventGroup':
        for (final e in (call.values[0] as DBusArray).children) {
          final s = e as DBusStruct;
          if ((s.children[1] as DBusString).value == 'clicked') {
            _clicked((s.children[0] as DBusInt32).value);
          }
        }
        return DBusMethodSuccessResponse([DBusArray.int32(const [])]);
      case 'AboutToShow':
        return DBusMethodSuccessResponse([const DBusBoolean(false)]);
      case 'AboutToShowGroup':
        return DBusMethodSuccessResponse([
          DBusArray.int32(const []),
          DBusArray.int32(const []),
        ]);
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  void _clicked(int id) {
    if (id == _open) onOpen();
    if (id == _quit) onQuit();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = switch (name) {
      'Version' => const DBusUint32(3),
      'TextDirection' => const DBusString('ltr'),
      'Status' => const DBusString('normal'),
      'IconThemePath' => DBusArray.string(const []),
      _ => null,
    };
    if (interface != _menuInterface || value == null) {
      return DBusMethodErrorResponse.unknownProperty();
    }
    return DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(
        interface == _menuInterface
            ? {
                'Version': const DBusUint32(3),
                'TextDirection': const DBusString('ltr'),
                'Status': const DBusString('normal'),
                'IconThemePath': DBusArray.string(const []),
              }
            : {},
      );
}
