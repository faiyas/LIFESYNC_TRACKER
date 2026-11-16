import 'package:image_picker/image_picker.dart';

class PaymentScreenshotService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickFromGallery() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    return image?.path;
  }

  Future<List<String>> pickMultipleFromGallery() async {
    final images = await _picker.pickMultiImage();
    return images.map((img) => img.path).toList();
  }

  Future<String?> captureFromCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
    );
    return image?.path;
  }
}
