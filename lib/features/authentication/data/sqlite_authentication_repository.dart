import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/authentication_repository.dart';

/// Local authentication sqlite implementation.
class SqliteAuthenticationRepository implements AuthenticationRepository {
  @override
  Future<void> requestOtp(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<bool> verifyOtp({required String email, required String otp}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    
    final cleanEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    // Hardcoded Super Admin Credentials Validation
    if ((cleanEmail == 'admin@igreen.com' ||
            cleanEmail == 'admin' ||
            cleanEmail == 'superadmin' ||
            cleanEmail == 'emp-001' ||
            cleanEmail == 'admin@admin.com') &&
        (cleanOtp == 'admin123' ||
            cleanOtp == 'Admin@123' ||
            cleanOtp == 'superadmin123' ||
            cleanOtp == 'admin' ||
            cleanOtp == '123456')) {
      return true;
    }
    
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'app_database.db');
      final db = await openDatabase(path);
      
      final results = await db.query(
        'employees',
        where: 'LOWER(employee_id) = ? OR LOWER(email_address) = ?',
        whereArgs: [cleanEmail, cleanEmail],
      );
      
      if (results.isNotEmpty) {
        final empMap = results.first;
        final savedPassword = empMap['temporary_password'] as String? ?? '';
        
        if (savedPassword.isNotEmpty) {
          if (savedPassword == cleanOtp) {
            return true;
          }
        } else {
          if (cleanOtp.length == 6 || cleanOtp == 'Admin@123' || cleanOtp == 'admin123') {
            return true;
          }
        }
      }
    } catch (_) {}
    
    // Default fallback
    return cleanOtp.length == 6 || cleanOtp == 'Admin@123' || cleanOtp == 'admin123';
  }

  @override
  Future<bool> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return true;
  }

  @override
  Future<void> signOut() async {}
}
