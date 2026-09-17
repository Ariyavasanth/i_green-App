# Implementation Plan - Replace Desktop Side Navigation with Back Arrow Navigation

Comment out the desktop side navigation bar and replace the hamburger menu button (`_AnimatedMenuButton`) in the top navigation bar with a Back Arrow (`<-` / `Icons.arrow_back_rounded`) button across all pages (including Attendance Management and all other modules).

The side navigation code will be commented out cleanly (not deleted) so it can be quickly restored whenever needed.

## Proposed Changes

### App Shell & Layout

#### [MODIFY] [app_shell.dart](file:///e:/f_projects/I_green_technology/lib/features/app_shell/presentation/app_shell.dart)

- **Side Navigation Drawer (Desktop View):**
  - Comment out `if (!compact) sidebar,` inside the layout row of `AppShell.build()` with clear comment markers (`// Sidebar navigation disabled for desktop view. Uncomment below line to restore side navigation`).
  
- **Top Header Bar (`_TopBar`):**
  - Replace the hamburger menu button (`_AnimatedMenuButton`) with `IconButton(icon: Icon(Icons.arrow_back_rounded), ...)` in `_TopBar.build()`.
  - Ensure the back button triggers `context.canPop() ? context.pop() : context.go(_getBackRoute(currentLocation))` so navigating back from any sub-module (e.g. `Attendance Management` -> `/attendance-management`) lands back on its parent module dashboard (e.g. `HRMS` -> `/module/hrms`).
  - Keep the original `_AnimatedMenuButton` code commented out cleanly with explicit instructions on how to restore it.

## Verification Plan

### Automated Verification
- Run `flutter analyze` via command line to verify there are no compilation errors or missing variable references in `app_shell.dart`.

### Manual Verification
- Launch the Flutter web/desktop application.
- Verify that in desktop view:
  1. The left sidebar drawer is hidden/not rendered.
  2. The top bar displays a back arrow (`<-`) icon instead of the hamburger menu (`☰`).
  3. Clicking the back arrow on **Attendance Management** (or any other sub-module page) smoothly navigates back to the parent module screen (e.g. **HRMS**).
