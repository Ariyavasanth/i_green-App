import 'dart:html' as html;

import 'sidebar_state_storage.dart';

SidebarStateStorage createSidebarStateStorageImpl() => _WebSidebarStateStorage();

class _WebSidebarStateStorage implements SidebarStateStorage {
  static const _key = 'sidebar_expanded';

  @override
  bool? readExpanded() {
    final value = html.window.localStorage[_key];
    if (value == null) return null;
    return value == 'true';
  }

  @override
  Future<void> writeExpanded(bool expanded) async {
    html.window.localStorage[_key] = expanded ? 'true' : 'false';
  }
}
