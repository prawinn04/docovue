import 'package:flutter_test/flutter_test.dart';
import 'package:docovue/src/utils/parsing_utils.dart';
import 'package:docovue/src/models/text_block.dart';

void main() {
  group('Aadhaar Extraction', () {
    test('should extract valid Aadhaar candidates', () {
      final blocks = [
        DocovueTextBlock(
          text: 'Government of India',
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 100, height: 20),
          confidence: 0.9,
        ),
        DocovueTextBlock(
          text: '2341 2341 2346',
          boundingBox: DocovueBoundingBox(x: 0, y: 30, width: 120, height: 20),
          confidence: 0.95,
        ),
        DocovueTextBlock(
          text: 'John Doe',
          boundingBox: DocovueBoundingBox(x: 0, y: 60, width: 80, height: 20),
          confidence: 0.9,
        ),
      ];

      final candidates = extractAadhaarCandidates(blocks);
      
      expect(candidates.length, equals(1));
      expect(candidates.first.number, equals('234123412346'));
      expect(candidates.first.confidence, equals(0.95));
    });

    test('should not extract invalid Aadhaar numbers', () {
      final blocks = [
        DocovueTextBlock(
          text: '1234 5678 9012', // Invalid Aadhaar
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 100, height: 20),
          confidence: 0.9,
        ),
      ];

      final candidates = extractAadhaarCandidates(blocks);
      expect(candidates.length, equals(1)); // Extracted but would fail validation
      expect(candidates.first.number, equals('123456789012'));
    });
  });

  group('PAN Extraction', () {
    test('should extract valid PAN candidates', () {
      final blocks = [
        DocovueTextBlock(
          text: 'Income Tax Department',
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 150, height: 20),
          confidence: 0.9,
        ),
        DocovueTextBlock(
          text: 'ABCDE1234F',
          boundingBox: DocovueBoundingBox(x: 0, y: 30, width: 100, height: 20),
          confidence: 0.95,
        ),
      ];

      final candidates = extractPanCandidates(blocks);
      
      expect(candidates.length, equals(1));
      expect(candidates.first.number, equals('ABCDE1234F'));
      expect(candidates.first.confidence, equals(0.95));
    });

    test('should handle lowercase PAN numbers', () {
      final blocks = [
        DocovueTextBlock(
          text: 'abcde1234f',
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 100, height: 20),
          confidence: 0.9,
        ),
      ];

      final candidates = extractPanCandidates(blocks);
      
      expect(candidates.length, equals(1));
      expect(candidates.first.number, equals('ABCDE1234F'));
    });
  });

  group('Card Number Extraction', () {
    test('should extract valid card candidates', () {
      final blocks = [
        DocovueTextBlock(
          text: '4111 1111 1111 1111',
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 150, height: 20),
          confidence: 0.95,
        ),
        DocovueTextBlock(
          text: 'JOHN DOE',
          boundingBox: DocovueBoundingBox(x: 0, y: 30, width: 80, height: 20),
          confidence: 0.9,
        ),
      ];

      final candidates = extractCardCandidates(blocks);
      
      expect(candidates.length, equals(1));
      expect(candidates.first.number, equals('4111111111111111'));
      expect(candidates.first.confidence, equals(0.95));
    });

    test('should extract cards with different formatting', () {
      final blocks = [
        DocovueTextBlock(
          text: '4111-1111-1111-1111',
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 150, height: 20),
          confidence: 0.9,
        ),
      ];

      final candidates = extractCardCandidates(blocks);
      
      expect(candidates.length, equals(1));
      expect(candidates.first.number, equals('4111111111111111'));
    });
  });

  group('Expiry Date Extraction', () {
    test('should extract valid expiry dates', () {
      final blocks = [
        DocovueTextBlock(
          text: '12/25',
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 50, height: 20),
          confidence: 0.9,
        ),
        DocovueTextBlock(
          text: '01/2026',
          boundingBox: DocovueBoundingBox(x: 60, y: 0, width: 60, height: 20),
          confidence: 0.85,
        ),
      ];

      final candidates = extractExpiryCandidates(blocks);
      
      expect(candidates.length, equals(2));
      expect(candidates[0].month, equals('12'));
      expect(candidates[0].year, equals('25'));
      expect(candidates[1].month, equals('01'));
      expect(candidates[1].year, equals('2026'));
    });

    test('should handle different expiry formats', () {
      final blocks = [
        DocovueTextBlock(
          text: 'VALID THRU 12/25',
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 120, height: 20),
          confidence: 0.9,
        ),
      ];

      final candidates = extractExpiryCandidates(blocks);
      
      expect(candidates.length, equals(1));
      expect(candidates.first.month, equals('12'));
      expect(candidates.first.year, equals('25'));
    });
  });

  group('Name Extraction', () {
    test('should extract potential names', () {
      final blocks = [
        DocovueTextBlock(
          text: 'John Doe',
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 80, height: 20),
          confidence: 0.9,
        ),
        DocovueTextBlock(
          text: 'Jane Smith Wilson',
          boundingBox: DocovueBoundingBox(x: 0, y: 30, width: 120, height: 20),
          confidence: 0.85,
        ),
        DocovueTextBlock(
          text: '1234567890', // Should be ignored
          boundingBox: DocovueBoundingBox(x: 0, y: 60, width: 100, height: 20),
          confidence: 0.95,
        ),
      ];

      final candidates = extractNameCandidates(blocks);
      
      expect(candidates.length, equals(2));
      expect(candidates[0].name, equals('John Doe'));
      expect(candidates[1].name, equals('Jane Smith Wilson'));
    });

    test('should filter out non-name patterns', () {
      final blocks = [
        DocovueTextBlock(
          text: 'Government of India', // Should be filtered out
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 150, height: 20),
          confidence: 0.9,
        ),
        DocovueTextBlock(
          text: 'Income Tax Department', // Should be filtered out
          boundingBox: DocovueBoundingBox(x: 0, y: 30, width: 180, height: 20),
          confidence: 0.9,
        ),
      ];

      final candidates = extractNameCandidates(blocks);
      
      expect(candidates.length, equals(0));
    });
  });

  group('Date Extraction', () {
    test('should extract various date formats', () {
      final blocks = [
        DocovueTextBlock(
          text: '15/08/1990',
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 80, height: 20),
          confidence: 0.9,
        ),
        DocovueTextBlock(
          text: '1990-08-15',
          boundingBox: DocovueBoundingBox(x: 0, y: 30, width: 80, height: 20),
          confidence: 0.85,
        ),
        DocovueTextBlock(
          text: '08/15/1990',
          boundingBox: DocovueBoundingBox(x: 0, y: 60, width: 80, height: 20),
          confidence: 0.8,
        ),
      ];

      final candidates = extractDateCandidates(blocks);
      
      expect(candidates.length, equals(3));
      expect(candidates[0].date, equals('15/08/1990'));
      expect(candidates[1].date, equals('1990-08-15'));
      expect(candidates[2].date, equals('08/15/1990'));
    });
  });

  group('Address Extraction', () {
    test('should group nearby address blocks', () {
      final blocks = [
        DocovueTextBlock(
          text: '123 Main Street',
          boundingBox: DocovueBoundingBox(x: 0, y: 100, width: 120, height: 20),
          confidence: 0.9,
        ),
        DocovueTextBlock(
          text: 'Apartment 4B',
          boundingBox: DocovueBoundingBox(x: 0, y: 125, width: 100, height: 20),
          confidence: 0.85,
        ),
        DocovueTextBlock(
          text: 'New York, NY 10001',
          boundingBox: DocovueBoundingBox(x: 0, y: 150, width: 140, height: 20),
          confidence: 0.8,
        ),
      ];

      final candidates = extractAddressCandidates(blocks);
      
      expect(candidates.length, equals(1));
      expect(candidates.first.lines.length, equals(3));
      expect(candidates.first.lines[0], equals('123 Main Street'));
      expect(candidates.first.lines[1], equals('Apartment 4B'));
      expect(candidates.first.lines[2], equals('New York, NY 10001'));
    });

    test('should detect address indicators', () {
      final blocks = [
        DocovueTextBlock(
          text: 'Sector 15, Gurgaon',
          boundingBox: DocovueBoundingBox(x: 0, y: 0, width: 120, height: 20),
          confidence: 0.9,
        ),
        DocovueTextBlock(
          text: 'PIN: 122001',
          boundingBox: DocovueBoundingBox(x: 0, y: 25, width: 80, height: 20),
          confidence: 0.85,
        ),
      ];

      final candidates = extractAddressCandidates(blocks);
      
      expect(candidates.length, equals(1));
      expect(candidates.first.lines.length, equals(2));
    });
  });
}