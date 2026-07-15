"""
Run from WSL to add camera permissions and admin photo upload.
"""
import os

# ── 1. AndroidManifest.xml - add camera + media permissions ──────────────────
manifest_path = "/mnt/c/Users/HP PROBOOK/projects/otuuse_transport_app/android/app/src/main/AndroidManifest.xml"
with open(manifest_path) as f:
    manifest = f.read()

old_perms = "    <!-- Network -->\n    <uses-permission android:name=\"android.permission.INTERNET\"/>"
new_perms = """    <!-- Network -->
    <uses-permission android:name="android.permission.INTERNET"/>

    <!-- Camera and media - for delivery photo attachments -->
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32"/>"""

if old_perms in manifest:
    manifest = manifest.replace(old_perms, new_perms, 1)
    with open(manifest_path, "w") as f:
        f.write(manifest)
    print("Done - AndroidManifest.xml: camera + media permissions added")
else:
    print("WARNING: permissions anchor not found in AndroidManifest.xml")

# ── 2. Admin reply sheet - add photo upload button ────────────────────────────
admin_path = "/mnt/c/Users/HP PROBOOK/projects/otuuse_transport_app/lib/features/admin/screens/admin_home_screen.dart"
with open(admin_path) as f:
    admin = f.read()

# Add image_picker import
old_import = "import 'package:flutter/material.dart';"
new_import = """import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';"""

if old_import in admin and 'image_picker' not in admin:
    admin = admin.replace(old_import, new_import, 1)

# Update _DeliveryReplySheetState to add photo capability
old_state_vars = """  final _ctrl = TextEditingController();
  String? _status;
  bool _sending = false;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }"""

new_state_vars = """  final _ctrl = TextEditingController();
  final _picker = ImagePicker();
  String? _status;
  bool _sending = false;
  String? _error;
  List<int>? _photoBytes;
  String? _photoFilename;
  String? _photoPreviewUrl;   // local preview before upload

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _pickPhoto() async {
    final XFile? img = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (img == null) return;
    final bytes = await img.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoFilename = img.name.isNotEmpty ? img.name : 'admin_photo.jpg';
      _photoPreviewUrl = null; // clear old
    });
  }"""

if old_state_vars in admin:
    admin = admin.replace(old_state_vars, new_state_vars, 1)
else:
    print("WARNING: state vars anchor not found in admin screen")

# Update _submit to upload photo if selected
old_submit = """  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) { setState(() => _error = 'Please type a message'); return; }
    setState(() { _sending = true; _error = null; });
    final ok = await widget.ref.read(adminProvider.notifier).replyToDelivery(
        widget.delivery.id, _ctrl.text.trim(), _status);"""

new_submit = """  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) { setState(() => _error = 'Please type a message'); return; }
    setState(() { _sending = true; _error = null; });

    // Upload photo first if one was selected
    if (_photoBytes != null) {
      try {
        final repo = widget.ref.read(adminProvider.notifier);
        // Upload via admin endpoint
        await widget.ref.read(adminProvider.notifier).uploadDeliveryPhoto(
          widget.delivery.id, _photoBytes!, _photoFilename ?? 'photo.jpg',
        );
      } catch (_) {
        // Photo upload failure is non-blocking - continue with text reply
      }
    }

    final ok = await widget.ref.read(adminProvider.notifier).replyToDelivery(
        widget.delivery.id, _ctrl.text.trim(), _status);"""

if old_submit in admin:
    admin = admin.replace(old_submit, new_submit, 1)
else:
    print("WARNING: _submit anchor not found")

# Add photo picker button to the reply sheet UI (after the status dropdown row)
old_ui_end = """            const SizedBox(height: 20),
            FilledButton(
              onPressed: _sending ? null : _submit,"""

new_ui_end = """            const SizedBox(height: 12),
            // Photo attachment
            OutlinedButton.icon(
              onPressed: _sending ? null : _pickPhoto,
              icon: const Icon(Icons.attach_file, size: 18),
              label: Text(_photoBytes != null ? 'Photo selected ✓' : 'Attach photo (optional)'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _sending ? null : _submit,"""

if old_ui_end in admin:
    admin = admin.replace(old_ui_end, new_ui_end, 1)
else:
    print("WARNING: UI end anchor not found")

with open(admin_path, "w") as f:
    f.write(admin)
print("Done - admin_home_screen.dart: photo picker added to reply sheet")
