import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

/// Picks a gallery photo and crops it, returning the cropped file's local
/// path (or null if the user backed out of either step). Used by both the
/// signup wizard's photo step and Edit Profile's avatar picker.
///
/// Uses `cropImage`'s own `maxWidth`/`maxHeight`/`compressQuality` to bound
/// the result, rather than a separate resize/compress pass with the `image`
/// package -- same practical outcome without a second image-processing
/// dependency.
Future<String?> pickAndCropProfilePhoto() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return null;

  final cropped = await ImageCropper().cropImage(
    sourcePath: picked.path,
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
