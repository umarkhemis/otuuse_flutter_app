"""
Run from WSL to add the rating dialog to driver_home_screen.dart.
Usage: python3 patch_driver_rating.py
"""

path = "/mnt/c/Users/HP PROBOOK/projects/otuuse_transport_app/lib/features/driver/screens/driver_home_screen.dart"
with open(path) as f:
    content = f.read()

warnings = []

# 1. Add rating dialog import
old_import = "import '../../auth/providers/auth_provider.dart';"
new_import = ("import '../../auth/providers/auth_provider.dart';\n"
              "import '../../rating/screens/rating_dialog.dart';")

if old_import in content:
    content = content.replace(old_import, new_import, 1)
else:
    warnings.append("auth import anchor not found")

# 2. Add ref.listen inside AdminHomeScreen.build - right before return Scaffold
# The driver home build method starts with:
# Widget build(BuildContext context, WidgetRef ref) {
# return DefaultTabController( ...
# For DriverHomeScreen it's a ConsumerWidget build that returns Scaffold directly

old_build_start = "    return Scaffold(\n      appBar: AppBar(\n        title: const Text('Otuuse Driver'),"
new_build_start = """    ref.listen(driverProvider, (previous, next) {
      if (next.completedRideId != null && previous?.completedRideId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await showRatingDialog(
            context: context,
            ref: ref,
            rideId: next.completedRideId!,
            ratingFor: 'passenger',
          );
          ref.read(driverProvider.notifier).clearCompletedRide();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Otuuse Driver'),"""

if old_build_start in content:
    content = content.replace(old_build_start, new_build_start, 1)
else:
    warnings.append("Scaffold anchor not found in driver_home_screen.dart")

with open(path, "w") as f:
    f.write(content)

if warnings:
    print("WARNINGS:")
    for w in warnings:
        print(f"  - {w}")
else:
    print("Done - rating dialog added to driver_home_screen.dart")
