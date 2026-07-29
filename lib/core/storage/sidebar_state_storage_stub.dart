import 'sidebar_state_storage.dart';

SidebarStateStorage createSidebarStateStorageImpl() => _MemorySidebarStateStorage();

class _MemorySidebarStateStorage implements SidebarStateStorage {
  bool? _expanded;

  @override
  bool? readExpanded() => _expanded;

  @override
  Future<void> writeExpanded(bool expanded) async {
    _expanded = expanded;
  }
}
