/// Isolated domain service for generating General Code and Project Code.
///
/// NOTE: If specific company/backend business rules for code generation
/// are specified later, update this class directly without altering UI or repositories.
class ProjectCodeGenerator {
  const ProjectCodeGenerator._();

  /// Generates a General Code based on Client, Place, and sequential/time context.
  ///
  /// Example output: `GC-CLI-CHE-2601` or `GC-LNT-DEL-101`
  static String generateGeneralCode({
    required String clientName,
    String place = '',
    int sequenceNumber = 1,
  }) {
    final clientPart = _sanitizeCode(clientName, defaultCode: 'GEN', maxLength: 4);
    final placePart = _sanitizeCode(place, defaultCode: 'LOC', maxLength: 3);
    final now = DateTime.now();
    final yearMonth = '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}';
    final seqPart = sequenceNumber.toString().padLeft(2, '0');

    return 'GC-$clientPart-$placePart-$yearMonth$seqPart';
  }

  /// Generates a Project Code based on Client, Sub/Own classification, State, District, and Area.
  ///
  /// Example output: `PRJ-OWN-CLI-TN-CHE-001` or `PRJ-SUB-LNT-KA-BLR-002`
  static String generateProjectCode({
    required String clientName,
    String subOrOwn = 'Own',
    String state = '',
    String district = '',
    String area = '',
    int sequenceNumber = 1,
  }) {
    final modePart = subOrOwn.trim().toUpperCase() == 'SUB' ? 'SUB' : 'OWN';
    final clientPart = _sanitizeCode(clientName, defaultCode: 'CLI', maxLength: 3);
    final statePart = _sanitizeCode(state, defaultCode: 'IN', maxLength: 2);
    final districtPart = _sanitizeCode(district, defaultCode: 'DIS', maxLength: 3);
    final seqPart = sequenceNumber.toString().padLeft(3, '0');

    return 'PRJ-$modePart-$clientPart-$statePart-$districtPart-$seqPart';
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
