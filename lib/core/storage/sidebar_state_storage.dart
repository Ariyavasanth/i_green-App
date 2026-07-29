abstract class SidebarStateStorage {
  bool? readExpanded();
  Future<void> writeExpanded(bool expanded);
}
