import 'package:cloud_functions/cloud_functions.dart';

/// Service untuk cleanup orders completed lama
/// Cloud Function akan otomatis jalan setiap hari jam 2 pagi
/// Service ini hanya untuk manual trigger jika admin perlu cleanup sekarang
class OrderCleanupService {
  static final _functions = FirebaseFunctions.instance;
  
  /// Trigger manual cleanup (admin only)
  /// 
  /// Parameter:
  /// - [days]: Hapus orders completed > X hari yang lalu (default: 60)
  /// 
  /// Returns:
  /// ```dart
  /// {
  ///   'success': true,
  ///   'message': 'Successfully deleted X orders older than 60 days',
  ///   'deletedCount': X,
  ///   'cutoffDate': '2024-10-03T02:00:00.000Z'
  /// }
  /// ```
  /// 
  /// Throws:
  /// - FirebaseFunctionsException jika user bukan admin
  /// - Error jika gagal cleanup
  static Future<Map<String, dynamic>> triggerCleanupNow({int days = 60}) async {
    try {
      print('?? Triggering manual cleanup for orders > $days days...');
      
      final result = await _functions
          .httpsCallable('triggerCleanupNow')
          .call({'days': days});
      
      final data = result.data as Map<String, dynamic>;
      
      print('? Cleanup result: ${data['message']}');
      print('?? Deleted ${data['deletedCount']} orders');
      
      return data;
    } on FirebaseFunctionsException catch (e) {
      print('? Firebase Functions error: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        throw 'Hanya admin yang bisa melakukan cleanup manual';
      } else if (e.code == 'unauthenticated') {
        throw 'Anda harus login terlebih dahulu';
      }
      
      throw 'Gagal melakukan cleanup: ${e.message}';
    } catch (e) {
      print('? Error triggering cleanup: $e');
      rethrow;
    }
  }
  
  /// Get info tentang cleanup schedule
  static String getScheduleInfo() {
    return '''
?? Auto-Cleanup Schedule:
• Waktu: Setiap hari jam 2:00 AM WIB
• Kriteria: Orders dengan status 'completed' > 60 hari
• Region: Asia Southeast 2 (Jakarta)
• Status: Aktif (otomatis)

?? Orders akan otomatis terhapus tanpa perlu intervensi manual.
    ''';
  }
  
  /// Delete ALL orders (untuk reset database)
  /// 
  /// ?? WARNING: Ini akan menghapus SEMUA orders tanpa filter!
  /// Hanya untuk development/testing, jangan dipakai di production!
  /// 
  /// Requires:
  /// - User harus admin
  /// - Confirmation token: 'DELETE_ALL_ORDERS_CONFIRM'
  /// 
  /// Returns:
  /// ```dart
  /// {
  ///   'success': true,
  ///   'message': 'Successfully deleted ALL X orders',
  ///   'deletedCount': X
  /// }
  /// ```
  static Future<Map<String, dynamic>> deleteAllOrders() async {
    try {
      print('?? Triggering DELETE ALL ORDERS...');
      
      final result = await _functions
          .httpsCallable('deleteAllOrders')
          .call({
        'confirmToken': 'DELETE_ALL_ORDERS_CONFIRM',
      });
      
      final data = result.data as Map<String, dynamic>;
      
      print('? Delete result: ${data['message']}');
      print('?? Deleted ${data['deletedCount']} orders');
      
      return data;
    } on FirebaseFunctionsException catch (e) {
      print('? Firebase Functions error: ${e.code} - ${e.message}');
      
      if (e.code == 'permission-denied') {
        throw 'Hanya admin yang bisa menghapus semua orders';
      } else if (e.code == 'unauthenticated') {
        throw 'Anda harus login terlebih dahulu';
      } else if (e.code == 'invalid-argument') {
        throw 'Token konfirmasi tidak valid';
      }
      
      throw 'Gagal menghapus orders: ${e.message}';
    } catch (e) {
      print('? Error deleting all orders: $e');
      rethrow;
    }
  }
}
