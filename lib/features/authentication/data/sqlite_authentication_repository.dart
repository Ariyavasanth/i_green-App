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
    await Future<void>.delayed(const Duration(milliseconds: 500));
    
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'app_database.db');
      final db = await openDatabase(path);
      
      final results = await db.query(
        'employees',
        where: 'LOWER(employee_id) = ? OR LOWER(email_address) = ?',
        whereArgs: [email.trim().toLowerCase(), email.trim().toLowerCase()],
      );
      
      if (results.isNotEmpty) {
        final empMap = results.first;
        final savedPassword = empMap['temporary_password'] as String? ?? '';
        
        if (savedPassword.isNotEmpty) {
          if (savedPassword == otp.trim()) {
            return true;
          }
        } else {
          // If no password is set on the employee, fallback to 6-digit code or default Admin@123
          if (otp.length == 6 || otp.trim() == 'Admin@123') {
            return true;
          }
        }
      }
    } catch (_) {}
    
    // Default fallback
    return otp.length == 6 || otp.trim() == 'Admin@123';
  }

  @override
  Future<bool> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return true;
  }

  @override
  Future<void> signOut() async {}
}
