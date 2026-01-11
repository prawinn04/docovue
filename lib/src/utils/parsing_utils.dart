/// Parsing utilities for extracting structured data from OCR text.
library parsing_utils;

import '../models/text_block.dart';

/// Extracts potential Aadhaar numbers from OCR text blocks.
List<AadhaarCandidate> extractAadhaarCandidates(List<DocovueTextBlock> blocks) {
  final candidates = <AadhaarCandidate>[];
  
  for (final block in blocks) {
    final text = block.normalizedText;
    
    // Look for 12-digit sequences (with or without spaces/hyphens)
    final aadhaarRegex = RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}\b');
    final matches = aadhaarRegex.allMatches(text);
    
    for (final match in matches) {
      final rawNumber = match.group(0)!;
      final cleanNumber = rawNumber.replaceAll(RegExp(r'[\s-]'), '');
      
      if (cleanNumber.length == 12) {
        candidates.add(AadhaarCandidate(
          number: cleanNumber,
          confidence: block.confidence,
          boundingBox: block.boundingBox,
          rawText: rawNumber,
        ));
      }
    }
  }
  
  return candidates;
}

/// Extracts potential PAN numbers from OCR text blocks.
List<PanCandidate> extractPanCandidates(List<DocovueTextBlock> blocks) {
  final candidates = <PanCandidate>[];
  
  for (final block in blocks) {
    final text = block.normalizedText.toUpperCase();
    
    // Look for PAN pattern: AAAAA9999A
    final panRegex = RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b');
    final matches = panRegex.allMatches(text);
    
    for (final match in matches) {
      final panNumber = match.group(0)!;
      
      candidates.add(PanCandidate(
        number: panNumber,
        confidence: block.confidence,
        boundingBox: block.boundingBox,
        rawText: panNumber,
      ));
    }
  }
  
  return candidates;
}

/// Extracts potential card numbers from OCR text blocks.
List<CardCandidate> extractCardCandidates(List<DocovueTextBlock> blocks) {
  final candidates = <CardCandidate>[];
  
  for (final block in blocks) {
    final text = block.normalizedText;
    
    // Look for 13-19 digit sequences (with or without spaces/hyphens)
    final cardRegex = RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{1,7}\b');
    final matches = cardRegex.allMatches(text);
    
    for (final match in matches) {
      final rawNumber = match.group(0)!;
      final cleanNumber = rawNumber.replaceAll(RegExp(r'[\s-]'), '');
      
      if (cleanNumber.length >= 13 && cleanNumber.length <= 19) {
        candidates.add(CardCandidate(
          number: cleanNumber,
          confidence: block.confidence,
          boundingBox: block.boundingBox,
          rawText: rawNumber,
        ));
      }
    }
  }
  
  return candidates;
}

/// Extracts potential expiry dates from OCR text blocks.
List<ExpiryCandidate> extractExpiryCandidates(List<DocovueTextBlock> blocks) {
  final candidates = <ExpiryCandidate>[];
  
  for (final block in blocks) {
    final text = block.normalizedText;
    
    // Look for MM/YY or MM/YYYY patterns
    final expiryRegex = RegExp(r'\b(0[1-9]|1[0-2])[/\s-]?(\d{2}|\d{4})\b');
    final matches = expiryRegex.allMatches(text);
    
    for (final match in matches) {
      final month = match.group(1)!;
      final year = match.group(2)!;
      final fullMatch = match.group(0)!;
      
      candidates.add(ExpiryCandidate(
        month: month,
        year: year,
        confidence: block.confidence,
        boundingBox: block.boundingBox,
        rawText: fullMatch,
      ));
    }
  }
  
  return candidates;
}

/// Extracts potential names from OCR text blocks using heuristics.
List<NameCandidate> extractNameCandidates(List<DocovueTextBlock> blocks) {
  final candidates = <NameCandidate>[];
  
  for (final block in blocks) {
    final text = block.normalizedText;
    
    // Skip blocks that are likely numbers or codes
    if (RegExp(r'^\d+$').hasMatch(text) || text.length < 2) {
      continue;
    }
    
    // Look for text that could be names (2-4 words, mostly alphabetic)
    final nameRegex = RegExp(r'\b[A-Za-z]{2,}\s+[A-Za-z]{2,}(?:\s+[A-Za-z]{2,})?(?:\s+[A-Za-z]{2,})?\b');
    final matches = nameRegex.allMatches(text);
    
    for (final match in matches) {
      final name = match.group(0)!;
      
      // Skip common non-name patterns
      if (_isLikelyNotName(name)) {
        continue;
      }
      
      candidates.add(NameCandidate(
        name: name,
        confidence: block.confidence,
        boundingBox: block.boundingBox,
        rawText: name,
      ));
    }
  }
  
  return candidates;
}

/// Extracts potential dates from OCR text blocks.
List<DateCandidate> extractDateCandidates(List<DocovueTextBlock> blocks) {
  final candidates = <DateCandidate>[];
  
  for (final block in blocks) {
    final text = block.normalizedText;
    
    // Look for various date formats
    final datePatterns = [
      RegExp(r'\b(0[1-9]|[12][0-9]|3[01])[/\-\.](0[1-9]|1[0-2])[/\-\.](\d{4})\b'), // DD/MM/YYYY
      RegExp(r'\b(\d{4})[/\-\.](0[1-9]|1[0-2])[/\-\.](0[1-9]|[12][0-9]|3[01])\b'), // YYYY/MM/DD
      RegExp(r'\b(0[1-9]|1[0-2])[/\-\.](0[1-9]|[12][0-9]|3[01])[/\-\.](\d{4})\b'), // MM/DD/YYYY
    ];
    
    for (final pattern in datePatterns) {
      final matches = pattern.allMatches(text);
      
      for (final match in matches) {
        final fullMatch = match.group(0)!;
        
        candidates.add(DateCandidate(
          date: fullMatch,
          confidence: block.confidence,
          boundingBox: block.boundingBox,
          rawText: fullMatch,
        ));
      }
    }
  }
  
  return candidates;
}

/// Extracts potential addresses from OCR text blocks.
List<AddressCandidate> extractAddressCandidates(List<DocovueTextBlock> blocks) {
  final candidates = <AddressCandidate>[];
  
  // Group blocks by proximity to form potential address lines
  final addressBlocks = <List<DocovueTextBlock>>[];
  
  for (final block in blocks) {
    final text = block.normalizedText;
    
    // Skip very short text or pure numbers
    if (text.length < 5 || RegExp(r'^\d+$').hasMatch(text)) {
      continue;
    }
    
    // Look for address-like patterns
    if (_isLikelyAddressText(text)) {
      // Try to group with nearby blocks
      bool addedToGroup = false;
      
      for (final group in addressBlocks) {
        if (group.isNotEmpty && _areBlocksNearby(group.last, block)) {
          group.add(block);
          addedToGroup = true;
          break;
        }
      }
      
      if (!addedToGroup) {
        addressBlocks.add([block]);
      }
    }
  }
  
  // Convert grouped blocks to address candidates
  for (final group in addressBlocks) {
    if (group.length >= 2) { // At least 2 lines for an address
      final addressLines = group.map((b) => b.text).toList();
      final avgConfidence = group.map((b) => b.confidence).reduce((a, b) => a + b) / group.length;
      
      // Create bounding box that encompasses all blocks
      final minX = group.map((b) => b.boundingBox.x).reduce((a, b) => a < b ? a : b);
      final minY = group.map((b) => b.boundingBox.y).reduce((a, b) => a < b ? a : b);
      final maxX = group.map((b) => b.boundingBox.x + b.boundingBox.width).reduce((a, b) => a > b ? a : b);
      final maxY = group.map((b) => b.boundingBox.y + b.boundingBox.height).reduce((a, b) => a > b ? a : b);
      
      candidates.add(AddressCandidate(
        lines: addressLines,
        confidence: avgConfidence,
        boundingBox: DocovueBoundingBox(
          x: minX,
          y: minY,
          width: maxX - minX,
          height: maxY - minY,
        ),
        rawText: addressLines.join('\n'),
      ));
    }
  }
  
  return candidates;
}

/// Checks if text is likely not a person's name.
bool _isLikelyNotName(String text) {
  final upperText = text.toUpperCase();
  
  // Common non-name patterns
  final nonNamePatterns = [
    'GOVERNMENT OF',
    'INCOME TAX',
    'PERMANENT ACCOUNT',
    'UNIQUE IDENTIFICATION',
    'VALID THRU',
    'EXPIRES',
    'SIGNATURE',
    'ADDRESS',
    'DATE OF BIRTH',
    'FATHER',
    'MOTHER',
    'SPOUSE',
  ];
  
  for (final pattern in nonNamePatterns) {
    if (upperText.contains(pattern)) {
      return true;
    }
  }
  
  return false;
}

/// Checks if text is likely part of an address.
bool _isLikelyAddressText(String text) {
  final upperText = text.toUpperCase();
  
  // Address indicators
  final addressIndicators = [
    'STREET',
    'ROAD',
    'AVENUE',
    'LANE',
    'COLONY',
    'NAGAR',
    'CITY',
    'DISTRICT',
    'STATE',
    'PIN',
    'PINCODE',
    'POSTAL',
    'APARTMENT',
    'FLAT',
    'HOUSE',
    'BUILDING',
    'BLOCK',
    'SECTOR',
    'PHASE',
  ];
  
  for (final indicator in addressIndicators) {
    if (upperText.contains(indicator)) {
      return true;
    }
  }
  
  // Check for PIN code pattern
  if (RegExp(r'\b\d{6}\b').hasMatch(text)) {
    return true;
  }
  
  // Check if it's a multi-word text (likely address line)
  return text.split(' ').length >= 3;
}

/// Checks if two text blocks are nearby (for address grouping).
bool _areBlocksNearby(DocovueTextBlock block1, DocovueTextBlock block2) {
  const maxDistance = 50.0; // pixels
  
  final center1 = block1.boundingBox.center;
  final center2 = block2.boundingBox.center;
  
  final distance = ((center1.x - center2.x) * (center1.x - center2.x) +
                   (center1.y - center2.y) * (center1.y - center2.y));
  
  return distance <= maxDistance * maxDistance;
}

/// Base class for extraction candidates.
abstract class ExtractionCandidate {
  const ExtractionCandidate({
    required this.confidence,
    required this.boundingBox,
    required this.rawText,
  });

  final double confidence;
  final DocovueBoundingBox boundingBox;
  final String rawText;
}

/// Candidate Aadhaar number found in OCR text.
class AadhaarCandidate extends ExtractionCandidate {
  const AadhaarCandidate({
    required this.number,
    required super.confidence,
    required super.boundingBox,
    required super.rawText,
  });

  final String number;
}

/// Candidate PAN number found in OCR text.
class PanCandidate extends ExtractionCandidate {
  const PanCandidate({
    required this.number,
    required super.confidence,
    required super.boundingBox,
    required super.rawText,
  });

  final String number;
}

/// Candidate card number found in OCR text.
class CardCandidate extends ExtractionCandidate {
  const CardCandidate({
    required this.number,
    required super.confidence,
    required super.boundingBox,
    required super.rawText,
  });

  final String number;
}

/// Candidate expiry date found in OCR text.
class ExpiryCandidate extends ExtractionCandidate {
  const ExpiryCandidate({
    required this.month,
    required this.year,
    required super.confidence,
    required super.boundingBox,
    required super.rawText,
  });

  final String month;
  final String year;
}

/// Candidate name found in OCR text.
class NameCandidate extends ExtractionCandidate {
  const NameCandidate({
    required this.name,
    required super.confidence,
    required super.boundingBox,
    required super.rawText,
  });

  final String name;
}

/// Candidate date found in OCR text.
class DateCandidate extends ExtractionCandidate {
  const DateCandidate({
    required this.date,
    required super.confidence,
    required super.boundingBox,
    required super.rawText,
  });

  final String date;
}

/// Candidate address found in OCR text.
class AddressCandidate extends ExtractionCandidate {
  const AddressCandidate({
    required this.lines,
    required super.confidence,
    required super.boundingBox,
    required super.rawText,
  });

  final List<String> lines;
}