import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/utils/app_snackbar.dart';
import '../../../../core/utils/pick_and_crop_image.dart';
import '../../data/model/profile_model.dart';
import '../../data/repository/profile_repository.dart';

class EditProfileController extends GetxController {
  EditProfileController(this._repository);

  final ProfileRepository _repository;

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final dateOfBirth = Rxn<DateTime>();
  final photoPath = Rxn<String>();

  final loadState = TheStates.loading.obs;
  final saveState = TheStates.initial.obs;

  @override
  void onInit() {
    super.onInit();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    loadState.value = TheStates.loading;
    final result = await _repository.getProfile();
    result.fold(
      (error) => loadState.value = TheStates.error,
      (profile) {
        nameController.text = profile.name;
        emailController.text = profile.email;
        phoneController.text = profile.phone ?? '';
        dateOfBirth.value = profile.dateOfBirth;
        photoPath.value = profile.photoPath;
        loadState.value = TheStates.success;
      },
    );
  }

  Future<void> pickDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth.value ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) dateOfBirth.value = picked;
  }

  Future<void> pickPhoto() async {
    final path = await pickAndCropProfilePhoto();
    if (path != null) photoPath.value = path;
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    saveState.value = TheStates.loading;
    final result = await _repository.updateProfile(
      ProfileModel(
        name: nameController.text.trim(),
        email: emailController.text.trim(),
        phone: phoneController.text.trim(),
        dateOfBirth: dateOfBirth.value,
        photoPath: photoPath.value,
      ),
    );
    result.fold(
      (error) {
        saveState.value = TheStates.error;
        Get.snackbar('Update failed', error.message);
      },
      (_) {
        saveState.value = TheStates.success;
        AppSnackbar.success('Saved', 'Your profile has been updated.');
        Get.back<void>();
      },
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.onClose();
  }
}
