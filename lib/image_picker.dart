import 'package:image_picker/image_picker.dart' as picker;
import 'package:firebase_storage/firebase_storage.dart';

Future<String?> uploadImage() async {
  final imagePicker = picker.ImagePicker();
  final pickedFile = await imagePicker.pickImage(source: picker.ImageSource.gallery);

  if (pickedFile != null) {
    final file = pickedFile.readAsBytes();
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('products/${DateTime.now().millisecondsSinceEpoch}.png');
    
    await storageRef.putData(await file);
    final downloadUrl = await storageRef.getDownloadURL();
    return downloadUrl; // 這個 URL 可以存到 Firestore
  }
  return null;
}
