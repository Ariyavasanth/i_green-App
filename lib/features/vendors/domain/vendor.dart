class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.companyName,
    required this.gstTreatment,
    this.email = '',
    this.workPhone = '',
    this.payables = 0,
  });

  final int id;
  final String name;
  final String companyName;
  final String email;
  final String workPhone;
  final String gstTreatment;
  final double payables;
}
