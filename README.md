# Plant Leaf Disease Detection – Flutter & TensorFlow Lite

This project is a mobile application developed with Flutter for detecting plant leaf diseases using a TensorFlow Lite model. The application allows users to select an image from the camera or gallery, processes the image on-device, and provides disease predictions with confidence scores. It operates fully offline and supports multiple plant types.

## Features

* Image selection from camera or gallery
* Offline inference using a TensorFlow Lite model
* Displays top-1 and top-5 predictions
* Outputs confidence scores
* Automatic parsing of plant and disease names
* Supports tomato, potato, and bell pepper leaf disease classes
* Clean and simple user interface
* Low-confidence detection warning

## Technologies Used

* Flutter
* TensorFlow Lite (tflite_flutter)
* Image Picker
* Image Processing (image package)
* EfficientNetB0 Model exported as TensorFlow Lite

## Project Structure

```
lib/
│── main.dart
│── plant_disease_classifier.dart

assets/
└── models/
     ├── plant_disease_model.tflite
     └── labels.txt
```

## Installation

### 1. Install dependencies

```
flutter pub get
```

### 2. Add model files

Place the model and label files under `assets/models/`:

```
plant_disease_model.tflite
labels.txt
```

### 3. Add assets to pubspec.yaml

```yaml
assets:
  - assets/models/plant_disease_model.tflite
  - assets/models/labels.txt
```

### 4. Run the application

```
flutter run
```

## Model Workflow

The `PlantDiseaseClassifier` class performs the following operations:

* Loads the TensorFlow Lite model
* Loads and parses the label file
* Resizes the input image to 256x256
* Converts the image into a tensor format
* Runs inference using TensorFlow Lite
* Applies softmax to obtain probabilities
* Extracts the top-1 prediction
* Extracts the top-5 predictions
* Maps class indices to plant and disease names

**Model input shape:** `1 x 256 x 256 x 3`

**Model output:** Floating-point logits representing class probabilities.

## Supported Plant Types

The model supports the following plant species (based on label file):

* Tomato
* Potato
* Bell Pepper

## Packages Used

```yaml
tflite_flutter: ^0.10.4
image_picker: ^1.1.0
image: ^4.1.3
```

## Model Versions

### Final Model (Used in Application)

* **File:** `plant_disease_model.tflite`
* **Labels:** `labels.txt`
* This is the active and working TensorFlow Lite model used by the Flutter application.

### Previous/Experimental Models

Old or non-functional model attempts can be found under:

```
model_training/old_models/
```

These include earlier attempts that resulted in TFLite conversion errors, version mismatches, or unsupported operators. They are retained only for documentation and research history and are **not** used in the application.

## Dataset

This project uses the public dataset available on Kaggle:

PlantVillage Dataset: [https://www.kaggle.com/datasets/emmarex/plantdisease](https://www.kaggle.com/datasets/emmarex/plantdisease)

The dataset contains labeled leaf images for various plant species and their corresponding diseases.

## Screenshots

Below is a placeholder section for application screenshots. Replace the image paths with your own.

| Home Screen                                  | Result Screen                                  |
| -------------------------------------------- | ---------------------------------------------- |
| <img src="screenshots/home.png" width="300"> | <img src="screenshots/result.png" width="300"> |

## Notes

* The application works completely offline.
* Label list length must match model output size.
* The implementation includes a fallback to avoid mismatches.
* The model expects RGB images with pixel values from 0 to 255.

## Contribution

Contributions and suggestions are welcome. Please submit a pull request or open an issue for improvements.

## License

This project is released under the MIT License.
