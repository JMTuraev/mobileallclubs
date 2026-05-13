String? normalizeDialablePhone(String? phone) {
  final trimmed = phone?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return null;
  }

  return trimmed.startsWith('+') ? '+$digits' : digits;
}

bool isValidPhoneNumber(String? phone, {int minimumDigits = 7}) {
  final normalized = normalizeDialablePhone(phone);
  if (normalized == null) {
    return false;
  }

  final digitsCount = normalized.replaceAll(RegExp(r'\D'), '').length;
  return digitsCount >= minimumDigits;
}
