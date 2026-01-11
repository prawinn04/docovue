import 'package:meta/meta.dart';

/// Represents a block of text recognized by OCR with its position and confidence.
@immutable
class DocovueTextBlock {
  const DocovueTextBlock({
    required this.text,
    required this.boundingBox,
    required this.confidence,
    this.lineIndex,
    this.paragraphIndex,
    this.language,
  });

  /// The recognized text content
  final String text;

  /// Bounding box coordinates (x, y, width, height) in image coordinates
  final DocovueBoundingBox boundingBox;

  /// Confidence score for this text block (0.0 to 1.0)
  final double confidence;

  /// Optional line index within the document
  final int? lineIndex;

  /// Optional paragraph index within the document
  final int? paragraphIndex;

  /// Detected language code (e.g., 'en', 'hi')
  final String? language;

  /// Returns true if this text block has high confidence
  bool get hasHighConfidence => confidence >= 0.8;

  /// Returns true if this text block contains only digits
  bool get isNumeric => RegExp(r'^\d+$').hasMatch(text.trim());

  /// Returns true if this text block contains alphanumeric characters
  bool get isAlphanumeric => RegExp(r'^[a-zA-Z0-9\s]+$').hasMatch(text.trim());

  /// Returns the text with whitespace normalized
  String get normalizedText => text.trim().replaceAll(RegExp(r'\s+'), ' ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocovueTextBlock &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          boundingBox == other.boundingBox &&
          confidence == other.confidence &&
          lineIndex == other.lineIndex &&
          paragraphIndex == other.paragraphIndex &&
          language == other.language;

  @override
  int get hashCode => Object.hash(
        text,
        boundingBox,
        confidence,
        lineIndex,
        paragraphIndex,
        language,
      );

  @override
  String toString() => 'DocovueTextBlock('
      'text: "$text", '
      'boundingBox: $boundingBox, '
      'confidence: $confidence'
      '${lineIndex != null ? ', lineIndex: $lineIndex' : ''}'
      '${paragraphIndex != null ? ', paragraphIndex: $paragraphIndex' : ''}'
      '${language != null ? ', language: $language' : ''}'
      ')';

  /// Creates a copy of this text block with updated properties
  DocovueTextBlock copyWith({
    String? text,
    DocovueBoundingBox? boundingBox,
    double? confidence,
    int? lineIndex,
    int? paragraphIndex,
    String? language,
  }) {
    return DocovueTextBlock(
      text: text ?? this.text,
      boundingBox: boundingBox ?? this.boundingBox,
      confidence: confidence ?? this.confidence,
      lineIndex: lineIndex ?? this.lineIndex,
      paragraphIndex: paragraphIndex ?? this.paragraphIndex,
      language: language ?? this.language,
    );
  }
}

/// Represents a bounding box with position and dimensions.
@immutable
class DocovueBoundingBox {
  const DocovueBoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  /// X coordinate of the top-left corner
  final double x;

  /// Y coordinate of the top-left corner
  final double y;

  /// Width of the bounding box
  final double width;

  /// Height of the bounding box
  final double height;

  /// Returns the center point of the bounding box
  DocovuePoint get center => DocovuePoint(
        x: x + width / 2,
        y: y + height / 2,
      );

  /// Returns the area of the bounding box
  double get area => width * height;

  /// Returns true if this bounding box contains the given point
  bool contains(DocovuePoint point) {
    return point.x >= x &&
        point.x <= x + width &&
        point.y >= y &&
        point.y <= y + height;
  }

  /// Returns true if this bounding box intersects with another
  bool intersects(DocovueBoundingBox other) {
    return x < other.x + other.width &&
        x + width > other.x &&
        y < other.y + other.height &&
        y + height > other.y;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocovueBoundingBox &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'DocovueBoundingBox(x: $x, y: $y, width: $width, height: $height)';
}

/// Represents a 2D point.
@immutable
class DocovuePoint {
  const DocovuePoint({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocovuePoint &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'DocovuePoint(x: $x, y: $y)';
}