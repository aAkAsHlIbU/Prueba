import 'dart:io';
import 'package:image/image.dart' as img;

class ContentModerationService {
  static const double _skinColorThreshold = 0.5;
  static const double _violenceColorThreshold = 0.15;
  static const double _darkRedThreshold = 0.1;

  // Reuse existing toxic words list from chat_page.dart
  static const List<String> toxicWords = [
    "kill", "murder", "die", "death", "suicide", "hurt",
    "stab", "shoot", "attack", "fight", "beat up",
    "hate", "stupid", "idiot", 
    "sex", "fuck", "bitch", "asshole",
    "terrorist", "nazi", "racist",
    "strike", "violence", "assault", "bomb", "weapon",
    "punch", "kick", "slap", "choke", "strangle",
    "knife", "gun", "bullet", "blood", "wound",
    "torture", "abuse", "victim", "threat", "terror",
    "brutal", "savage", "cruel", "vicious", "aggressive",
    "riot", "protest", "gang", "thug", "criminal",
  ];

  static Future<bool> isContentAppropriate(File imageFile, String description) async {
    bool isImageAppropriate = await _analyzeImage(imageFile);
    bool isTextAppropriate = _analyzeText(description);

    return isImageAppropriate && isTextAppropriate;
  }

  static Future<bool> _analyzeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return false;

      int skinTonePixels = 0;
      int violenceIndicatorPixels = 0;
      int darkRedPixels = 0;
      int totalPixels = image.width * image.height;

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();
          
          if (_isSkinTone(r, g, b)) {
            skinTonePixels++;
          }
          
          if (_isViolenceIndicator(r, g, b)) {
            violenceIndicatorPixels++;
          }
        }
      }

      double skinToneRatio = skinTonePixels / totalPixels;
      double violenceRatio = violenceIndicatorPixels / totalPixels;

      if (violenceRatio > _violenceColorThreshold) {
        print('Violence detected: $violenceRatio ratio of violent indicators');
        return false;
      }

      return skinToneRatio < _skinColorThreshold;

    } catch (e) {
      print('Error analyzing image: $e');
      return false;
    }
  }

  static bool _isSkinTone(int r, int g, int b) {
    // Simple skin tone detection
    return (r > 60 && r < 255 &&
            g > 40 && g < 230 &&
            b > 20 && b < 200 &&
            r > g && g > b &&
            (r - g) > 15 &&
            (r - b) > 15);
  }

  static bool _isViolenceIndicator(int r, int g, int b) {
    // Enhanced violence detection with multiple checks
    bool isHighRed = r > 150 && r > g * 1.5 && r > b * 1.5;
    bool isDarkRed = r > 100 && r < 180 && g < 100 && b < 100;
    bool isBloodRed = (r > 120 && r < 200) && (g < 100) && (b < 100);
    
    return isHighRed || isDarkRed || isBloodRed;
  }

  static bool _analyzeText(String text) {
    text = text.toLowerCase();
    return !toxicWords.any((word) => text.contains(word.toLowerCase()));
  }

  static String getContentModerationError(File imageFile, String description) {
    if (!_analyzeText(description)) {
      return 'Description contains inappropriate content.';
    }
    return 'Image contains inappropriate content.';
  }
}
