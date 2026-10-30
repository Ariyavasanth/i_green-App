/// Isolated domain service for generating General Code and Project Code.
///
/// NOTE: If specific company/backend business rules for code generation
/// are specified later, update this class directly without altering UI or repositories.
class ProjectCodeGenerator {
  const ProjectCodeGenerator._();

  /// Generates a General Code based on Client, Details, Place, and sequential context.
  ///
  /// Example output: `AE POWER-asdfsdf-chennai-01`
  static String generateGeneralCode({
    required String clientName,
    String details = '',
    String place = '',
    int sequenceNumber = 1,
  }) {
    final clientPart = clientName.trim().isEmpty ? 'GEN' : clientName.trim();
    final detailsPart = details.trim().isEmpty ? 'DETAILS' : details.trim();
    final placePart = place.trim().isEmpty ? 'LOC' : place.trim();
    final seqPart = sequenceNumber.toString().padLeft(2, '0');

    return '$clientPart-$detailsPart-$placePart-$seqPart';
  }

  static const Map<String, String> _indianStateCodes = {
    'Andhra Pradesh': 'AP',
    'Arunachal Pradesh': 'AR',
    'Assam': 'AS',
    'Bihar': 'BR',
    'Chhattisgarh': 'CG',
    'Goa': 'GA',
    'Gujarat': 'GJ',
    'Haryana': 'HR',
    'Himachal Pradesh': 'HP',
    'Jharkhand': 'JH',
    'Karnataka': 'KA',
    'Kerala': 'KL',
    'Madhya Pradesh': 'MP',
    'Maharashtra': 'MH',
    'Manipur': 'MN',
    'Meghalaya': 'ML',
    'Mizoram': 'MZ',
    'Nagaland': 'NL',
    'Odisha': 'OD',
    'Punjab': 'PB',
    'Rajasthan': 'RJ',
    'Sikkim': 'SK',
    'Tamil Nadu': 'TN',
    'Telangana': 'TS',
    'Tripura': 'TR',
    'Uttar Pradesh': 'UP',
    'Uttarakhand': 'UK',
    'West Bengal': 'WB',
    'Delhi': 'DL',
    'Puducherry': 'PY',
    'Chandigarh': 'CH',
    'Jammu and Kashmir': 'JK',
    'Ladakh': 'LA',
    'Andaman and Nicobar Islands': 'AN',
    'Dadra and Nagar Haveli and Daman and Diu': 'DD',
    'Lakshadweep': 'LD',
  };

  /// Generates a Project Code based on Client, Sub/Own, Month/Year, Sequence, State Code, District, and Area.
  ///
  /// Example output: `TNEB-SUB-OCT/2026-124-AS-West Karbi Anglong-pallavaram`
  static String generateProjectCode({
    required String clientName,
    String subOrOwn = 'Own',
    String state = '',
    String district = '',
    String area = '',
    int sequenceNumber = 1,
  }) {
    final clientPart = clientName.trim().isEmpty ? 'CLI' : clientName.trim();
    final modePart = subOrOwn.trim().toUpperCase() == 'SUB' ? 'SUB' : 'OWN';

    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final now = DateTime.now();
    final monthYear = '${months[now.month - 1]}/${now.year}';

    final stateTrimmed = state.trim();
    final stateCode = _indianStateCodes[stateTrimmed] ??
        (stateTrimmed.length >= 2 ? stateTrimmed.substring(0, 2).toUpperCase() : 'IN');

    final districtPart = district.trim().isEmpty ? 'DIS' : district.trim();
    final areaPart = area.trim().isEmpty ? 'AREA' : area.trim();

    return '$clientPart-$modePart-$monthYear-$sequenceNumber-$stateCode-$districtPart-$areaPart';
  }

  static String _sanitizeCode(String text, {required String defaultCode, int maxLength = 3}) {
    final clean = text
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .toUpperCase();
    if (clean.isEmpty) return defaultCode;
    return clean.length > maxLength ? clean.substring(0, maxLength) : clean;
  }
}
