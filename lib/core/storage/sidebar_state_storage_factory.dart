import 'sidebar_state_storage.dart';
import 'sidebar_state_storage_stub.dart'
    if (dart.library.html) 'sidebar_state_storage_web.dart';

SidebarStateStorage createSidebarStateStorage() => createSidebarStateStorageImpl();
