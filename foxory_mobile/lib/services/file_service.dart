import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class FileService {
  final ImagePicker _picker = ImagePicker();

  Future<Directory> get _appDocDir async {
    return getApplicationDocumentsDirectory();
  }

  Future<Directory> get _tempDir async {
    return getTemporaryDirectory();
  }

  Future<String> _uniquePath(Directory dir, String prefix, String ext) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, '\${prefix}_$timestamp.$ext');
  }

  Future<String> pickImage({bool fromCamera = false}) async {
    final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1920.toDouble(),
      maxHeight: 1080.toDouble(),
      imageQuality: 85,
    );
    if (pickedFile == null) throw Exception('No image selected');
    final destPath = await _uniquePath(await _appDocDir, 'img', 'jpg');
    await File(pickedFile.path).copy(destPath);
    return destPath;
  }

  Future<String> pickImageForTrip({bool fromCamera = false, String? tripId}) async {
    final path = await pickImage(fromCamera: fromCamera);
    return path;
  }

  Future<List<File>> pickMultipleImages() async {
    final pickedFiles = await _picker.pickMultiImage(
      maxWidth: 1920.toDouble(),
      maxHeight: 1080.toDouble(),
      imageQuality: 85,
    );
    return pickedFiles.map((f) => File(f.path)).toList();
  }

  Future<File?> pickVideo() async {
    final pickedFile = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    return pickedFile != null ? File(pickedFile.path) : null;
  }

  Future<String> getTempPath(String prefix, String extension) async {
    return _uniquePath(await _tempDir, prefix, extension);
  }

  Future<bool> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  Future<void> saveFile(String sourcePath, String destDir, String fileName) async {
    final destPath = p.join(destDir, fileName);
    await File(sourcePath).copy(destPath);
  }
}
