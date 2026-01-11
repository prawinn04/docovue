/// Validation utilities for document numbers and sensitive data masking.
library validators;

/// Validates an Aadhaar number using the Verhoeff checksum algorithm.
/// 
/// Returns true if the Aadhaar number is valid (12 digits + valid checksum).
bool isValidAadhaar(String aadhaar) {
  if (aadhaar.isEmpty) return false;
  
  // Remove spaces and hyphens
  final cleaned = aadhaar.replaceAll(RegExp(r'[\s-]'), '');
  
  // Must be exactly 12 digits
  if (cleaned.length != 12 || !RegExp(r'^\d{12}$').hasMatch(cleaned)) {
    return false;
  }
  
  // Cannot start with 0 or 1
  if (cleaned.startsWith('0') || cleaned.startsWith('1')) {
    return false;
  }
  
  return verhoeffCheck(cleaned);
}

/// Validates a PAN number using the standard PAN format.
/// 
/// Returns true if the PAN follows the format: AAAAA9999A
/// where A = alphabetic character, 9 = numeric character.
bool isValidPan(String pan) {
  if (pan.isEmpty) return false;
  
  final cleaned = pan.replaceAll(RegExp(r'\s'), '').toUpperCase();
  
  // Must be exactly 10 characters
  if (cleaned.length != 10) return false;
  
  // Format: AAAAA9999A
  final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  return panRegex.hasMatch(cleaned);
}

/// Validates a credit/debit card number using the Luhn algorithm.
/// 
/// Returns true if the card number passes Luhn validation and has valid length.
bool isValidCardNumber(String cardNumber) {
  if (cardNumber.isEmpty) return false;
  
  // Remove spaces and hyphens
  final cleaned = cardNumber.replaceAll(RegExp(r'[\s-]'), '');
  
  // Must be 13-19 digits
  if (cleaned.length < 13 || cleaned.length > 19 || !RegExp(r'^\d+$').hasMatch(cleaned)) {
    return false;
  }
  
  return luhnCheck(cleaned);
}

/// Implements the Luhn algorithm for credit card validation.
/// 
/// Returns true if the number passes the Luhn checksum test.
bool luhnCheck(String digits) {
  if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) {
    return false;
  }
  
  int sum = 0;
  bool alternate = false;
  
  // Process digits from right to left
  for (int i = digits.length - 1; i >= 0; i--) {
    int digit = int.parse(digits[i]);
    
    if (alternate) {
      digit *= 2;
      if (digit > 9) {
        digit = (digit % 10) + 1;
      }
    }
    
    sum += digit;
    alternate = !alternate;
  }
  
  return sum % 10 == 0;
}

/// Implements the Verhoeff algorithm for Aadhaar validation.
/// 
/// Returns true if the number passes the Verhoeff checksum test.
bool verhoeffCheck(String digits) {
  if (digits.isEmpty || !RegExp(r'^\d+$').hasMatch(digits)) {
    return false;
  }
  
  // Verhoeff multiplication table
  const multiplicationTable = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
  ];
  
  // Verhoeff permutation table
  const permutationTable = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
  ];
  
  int checksum = 0;
  
  for (int i = 0; i < digits.length; i++) {
    int digit = int.parse(digits[digits.length - 1 - i]);
    int permutedDigit = permutationTable[i % 8][digit];
    checksum = multiplicationTable[checksum][permutedDigit];
  }
  
  return checksum == 0;
}

/// Masks a credit card number for secure logging.
/// 
/// Returns the card number with middle digits replaced by asterisks.
/// Example: "4111111111111111" -> "**** **** **** 1111"
String maskCardNumber(String cardNumber) {
  if (cardNumber.isEmpty) return '';
  
  final cleaned = cardNumber.replaceAll(RegExp(r'[\s-]'), '');
  
  if (cleaned.length < 8) {
    // Too short to mask meaningfully
    return '*' * cleaned.length;
  }
  
  final first4 = cleaned.substring(0, 4);
  final last4 = cleaned.substring(cleaned.length - 4);
  final middle = '*' * (cleaned.length - 8);
  
  return '$first4 $middle $last4'.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Masks an Aadhaar number for secure logging.
/// 
/// Returns the Aadhaar number with middle digits replaced by X's.
/// Example: "123456789012" -> "XXXX-XXXX-9012"
String maskAadhaarNumber(String aadhaar) {
  if (aadhaar.isEmpty) return '';
  
  final cleaned = aadhaar.replaceAll(RegExp(r'[\s-]'), '');
  
  if (cleaned.length != 12) {
    return 'X' * cleaned.length;
  }
  
  final last4 = cleaned.substring(8);
  return 'XXXX-XXXX-$last4';
}

/// Masks a PAN number for secure logging.
/// 
/// Returns the PAN with middle characters replaced by X's.
/// Example: "ABCDE1234F" -> "XXXXX1234X"
String maskPanNumber(String pan) {
  if (pan.isEmpty) return '';
  
  final cleaned = pan.replaceAll(RegExp(r'\s'), '').toUpperCase();
  
  if (cleaned.length != 10) {
    return 'X' * cleaned.length;
  }
  
  final middle4 = cleaned.substring(5, 9);
  return 'XXXXX${middle4}X';
}

/// Validates a passport number using basic format rules.
/// 
/// Returns true if the passport number appears to be in a valid format.
bool isValidPassportNumber(String passport) {
  if (passport.isEmpty) return false;
  
  final cleaned = passport.replaceAll(RegExp(r'\s'), '').toUpperCase();
  
  // Most passports are 6-9 alphanumeric characters
  if (cleaned.length < 6 || cleaned.length > 9) {
    return false;
  }
  
  // Should contain only letters and numbers
  return RegExp(r'^[A-Z0-9]+$').hasMatch(cleaned);
}

/// Validates an expiry date in MM/YY or MM/YYYY format.
/// 
/// Returns true if the date is in valid format and not expired.
bool isValidExpiryDate(String expiry) {
  if (expiry.isEmpty) return false;
  
  final cleaned = expiry.replaceAll(RegExp(r'[\s/]'), '');
  
  // Try MM/YY format (4 digits)
  if (cleaned.length == 4) {
    final month = int.tryParse(cleaned.substring(0, 2));
    final year = int.tryParse(cleaned.substring(2, 4));
    
    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    
    // Convert 2-digit year to 4-digit (assuming 20xx)
    final fullYear = 2000 + year;
    final now = DateTime.now();
    final expiryDate = DateTime(fullYear, month + 1, 0); // Last day of expiry month
    
    return expiryDate.isAfter(now);
  }
  
  // Try MM/YYYY format (6 digits)
  if (cleaned.length == 6) {
    final month = int.tryParse(cleaned.substring(0, 2));
    final year = int.tryParse(cleaned.substring(2, 6));
    
    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    if (year < 2000 || year > 2099) return false;
    
    final now = DateTime.now();
    final expiryDate = DateTime(year, month + 1, 0); // Last day of expiry month
    
    return expiryDate.isAfter(now);
  }
  
  return false;
}

/// Determines the card brand from the card number.
/// 
/// Returns the card brand name or 'Unknown' if not recognized.
String getCardBrand(String cardNumber) {
  if (cardNumber.isEmpty) return 'Unknown';
  
  final cleaned = cardNumber.replaceAll(RegExp(r'[\s-]'), '');
  
  if (cleaned.length < 4) return 'Unknown';
  
  final firstDigit = cleaned[0];
  final firstTwoDigits = cleaned.substring(0, 2);
  final firstFourDigits = cleaned.length >= 4 ? cleaned.substring(0, 4) : '';
  
  // Visa: starts with 4
  if (firstDigit == '4') {
    return 'Visa';
  }
  
  // Mastercard: 51-55, 2221-2720
  if (RegExp(r'^5[1-5]').hasMatch(firstTwoDigits)) {
    return 'Mastercard';
  }
  if (firstFourDigits.isNotEmpty) {
    final first4Num = int.tryParse(firstFourDigits);
    if (first4Num != null && first4Num >= 2221 && first4Num <= 2720) {
      return 'Mastercard';
    }
  }
  
  // American Express: 34, 37
  if (firstTwoDigits == '34' || firstTwoDigits == '37') {
    return 'American Express';
  }
  
  // RuPay (India): 60, 6521, 6522 - check before Discover
  if (firstTwoDigits == '60' || 
      firstFourDigits == '6521' || 
      firstFourDigits == '6522') {
    return 'RuPay';
  }
  
  // Discover: 6011, 622126-622925, 644-649, 65
  if (firstFourDigits == '6011' || firstTwoDigits == '65') {
    return 'Discover';
  }
  if (firstFourDigits.isNotEmpty) {
    final first4Num = int.tryParse(firstFourDigits);
    if (first4Num != null && first4Num >= 6221 && first4Num <= 6229) {
      return 'Discover';
    }
  }
  if (RegExp(r'^64[4-9]').hasMatch(cleaned.substring(0, 3))) {
    return 'Discover';
  }
  
  // JCB: 35
  if (firstTwoDigits == '35') {
    return 'JCB';
  }
  
  // Diners Club: 30, 36, 38
  if (firstTwoDigits == '30' || firstTwoDigits == '36' || firstTwoDigits == '38') {
    return 'Diners Club';
  }
  
  return 'Unknown';
}