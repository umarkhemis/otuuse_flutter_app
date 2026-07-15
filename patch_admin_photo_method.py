"""
Adds uploadDeliveryPhoto to AdminNotifier and AdminRepository.
"""

# ── admin_repository.dart - add uploadDeliveryPhoto ──────────────────────────
repo_path = "/mnt/c/Users/HP PROBOOK/projects/otuuse_transport_app/lib/features/admin/data/admin_repository.dart"
with open(repo_path) as f:
    repo = f.read()

new_method = '''
  Future<void> uploadDeliveryPhoto(
    String deliveryId,
    List<int> bytes,
    String filename,
  ) async {
    try {
      final formData = dio_pkg.FormData.fromMap({
        'file': dio_pkg.MultipartFile.fromBytes(bytes, filename: filename),
      });
      await _apiClient.dio.post(
        '/admin/deliveries/$deliveryId/photo',
        data: formData,
        options: dio_pkg.Options(contentType: 'multipart/form-data'),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
'''

# Add dio import alias if needed
if 'import package:dio/dio.dart' not in repo and "dio_pkg" not in repo:
    old_import = "import 'package:dio/dio.dart';"
    new_import = "import 'package:dio/dio.dart' as dio_pkg;\nimport 'package:dio/dio.dart';"
    if old_import in repo:
        repo = repo.replace(old_import, new_import, 1)

if 'uploadDeliveryPhoto' not in repo:
    # Insert before closing brace
    repo = repo.rstrip().rstrip('}') + new_method + '\n}\n'
    with open(repo_path, 'w') as f:
        f.write(repo)
    print("Done - admin_repository.dart: uploadDeliveryPhoto added")
else:
    print("uploadDeliveryPhoto already in admin_repository.dart")

# ── admin_provider.dart - add uploadDeliveryPhoto method ─────────────────────
provider_path = "/mnt/c/Users/HP PROBOOK/projects/otuuse_transport_app/lib/features/admin/providers/admin_provider.dart"
with open(provider_path) as f:
    provider = f.read()

new_provider_method = '''
  Future<void> uploadDeliveryPhoto(
    String deliveryId,
    List<int> bytes,
    String filename,
  ) async {
    try {
      await _repo.uploadDeliveryPhoto(deliveryId, bytes, filename);
    } catch (e) {
      // Non-fatal - log and continue
    }
  }
'''

if 'uploadDeliveryPhoto' not in provider:
    # Insert before the last closing brace
    provider = provider.rstrip().rstrip('}') + new_provider_method + '\n}\n'
    with open(provider_path, 'w') as f:
        f.write(provider)
    print("Done - admin_provider.dart: uploadDeliveryPhoto method added")
else:
    print("uploadDeliveryPhoto already in admin_provider.dart")
