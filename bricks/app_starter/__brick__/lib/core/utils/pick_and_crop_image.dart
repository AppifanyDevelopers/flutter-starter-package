import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery, files }

/// Asks where the photo comes from (camera, gallery or files), picks it, then
/// crops it. Returns the cropped file's local path, or null if the user
/// backed out of any step. Used by the signup wizard and Edit Profile.
///
/// Uses `cropImage`'s own `maxWidth`/`maxHeight`/`compressQuality` to bound
/// the result, rather than a separate resize/compress pass with the `image`
/// package -- same practical outcome without a second image-processing
/// dependency.
Future<String?> pickAndCropProfilePhoto() async {
  final source = await _askSource();
  if (source == null) return null;

  final sourcePath = await _pick(source);
  if (sourcePath == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    maxWidth: 800,
    maxHeight: 800,
    compressQuality: 70,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: 'Crop photo',
        aspectRatioPresets: const [CropAspectRatioPreset.original, CropAspectRatioPreset.square],
      ),
      IOSUiSettings(
        title: 'Crop photo',
        aspectRatioPresets: const [CropAspectRatioPreset.original, CropAspectRatioPreset.square],
      ),
    ],
  );
  return cropped?.path;
}

Future<PhotoSource?> _askSource() {
  return Get.bottomSheet<PhotoSource>(
    SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Camera'),
            onTap: () => Get.back(result: PhotoSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery'),
            onTap: () => Get.back(result: PhotoSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Files'),
            onTap: () => Get.back(result: PhotoSource.files),
          ),
        ],
      ),
    ),
    backgroundColor: Get.theme.colorScheme.surface,
  );
}

Future<String?> _pick(PhotoSource source) async {
  switch (source) {
    case PhotoSource.camera:
      return (await ImagePicker().pickImage(source: ImageSource.camera))?.path;
    case PhotoSource.gallery:
      return (await ImagePicker().pickImage(source: ImageSource.gallery))?.path;
    case PhotoSource.files:
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      return result?.files.single.path;
  }
}
