const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

/**
 * Cloud Function untuk mengirim email invitation ke calon kurir
 * Callable function yang dipanggil dari Flutter app
 */
exports.sendInvitationEmail = functions.https.onCall(async (data, context) => {
  // Validasi: hanya admin yang bisa call function ini
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to send invitation emails.'
    );
  }

  // Cek apakah user adalah admin
  const userDoc = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();
  
  if (!userDoc.exists || userDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can send invitation emails.'
    );
  }

  // Validasi input
  const { email, name, invitationToken } = data;
  
  if (!email || !name || !invitationToken) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: email, name, or invitationToken.'
    );
  }

  try {
    // Setup Nodemailer transporter dengan Gmail SMTP
    // PENTING: Gunakan App Password, bukan password Gmail biasa
    // Cara buat App Password: https://support.google.com/accounts/answer/185833
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: functions.config().gmail.email, // Set via: firebase functions:config:set gmail.email="your-email@gmail.com"
        pass: functions.config().gmail.password // Set via: firebase functions:config:set gmail.password="your-app-password"
      }
    });

    // Buat invitation link
    const invitationLink = `https://katsuchip.com/register-kurir?token=${invitationToken}`;
    
    // TODO: Ganti dengan domain production Anda
    // Untuk testing, bisa pakai: https://katsuchip-65298.web.app atau custom domain

    // HTML Email template
    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
          }
          .header {
            background-color: #FF7A00;
            color: white;
            padding: 20px;
            text-align: center;
            border-radius: 10px 10px 0 0;
          }
          .content {
            background-color: #FFF7ED;
            padding: 30px;
            border-radius: 0 0 10px 10px;
          }
          .button {
            display: inline-block;
            background-color: #FF7A00;
            color: white;
            padding: 15px 30px;
            text-decoration: none;
            border-radius: 8px;
            margin: 20px 0;
            font-weight: bold;
          }
          .button:hover {
            background-color: #E66A00;
          }
          .info-box {
            background-color: white;
            padding: 15px;
            border-left: 4px solid #FF7A00;
            margin: 20px 0;
          }
          .footer {
            text-align: center;
            color: #666;
            font-size: 12px;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
          }
        </style>
      </head>
      <body>
        <div class="header">
          <h1>🍱 Selamat Datang di KatsuChip!</h1>
        </div>
        <div class="content">
          <h2>Halo ${name},</h2>
          <p>Anda telah diundang untuk bergabung sebagai <strong>Kurir KatsuChip</strong>!</p>
          
          <p>Silakan klik tombol di bawah ini untuk menyelesaikan registrasi akun Anda:</p>
          
          <div style="text-align: center;">
            <a href="${invitationLink}" class="button">Daftar Sekarang</a>
          </div>
          
          <div class="info-box">
            <p><strong>📧 Email Anda:</strong> ${email}</p>
            <p><strong>⏰ Link berlaku:</strong> 7 hari dari sekarang</p>
            <p><strong>🔐 Keamanan:</strong> Link hanya bisa digunakan 1 kali</p>
          </div>
          
          <p>Atau copy link berikut ke browser Anda:</p>
          <p style="word-break: break-all; background-color: #f5f5f5; padding: 10px; border-radius: 5px; font-family: monospace; font-size: 12px;">
            ${invitationLink}
          </p>
          
          <p style="margin-top: 30px;">Jika Anda tidak merasa mendaftar sebagai kurir, abaikan email ini.</p>
        </div>
        <div class="footer">
          <p>© 2025 KatsuChip. All rights reserved.</p>
          <p>Email ini dikirim otomatis, mohon tidak membalas.</p>
        </div>
      </body>
      </html>
    `;

    // Plain text fallback
    const textContent = `
Halo ${name},

Anda telah diundang untuk bergabung sebagai Kurir KatsuChip!

Silakan klik link berikut untuk menyelesaikan registrasi:
${invitationLink}

Email: ${email}
Link berlaku: 7 hari dari sekarang
Keamanan: Link hanya bisa digunakan 1 kali

Jika Anda tidak merasa mendaftar sebagai kurir, abaikan email ini.

---
© 2025 KatsuChip. All rights reserved.
    `;

    // Kirim email
    const mailOptions = {
      from: `"KatsuChip Team" <${functions.config().gmail.email}>`,
      to: email,
      subject: '🎉 Undangan Bergabung sebagai Kurir KatsuChip',
      text: textContent,
      html: htmlContent
    };

    await transporter.sendMail(mailOptions);

    // Log sukses
    console.log(`Invitation email sent successfully to ${email}`);

    return {
      success: true,
      message: 'Email invitation berhasil dikirim',
      recipient: email
    };

  } catch (error) {
    console.error('Error sending invitation email:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to send invitation email: ' + error.message
    );
  }
});

/**
 * Scheduled Cloud Function untuk auto-cleanup orders completed > 60 hari
 * Jalan otomatis setiap hari jam 2 pagi (Asia/Jakarta)
 * 
 * Cron syntax: 'minute hour day month weekday'
 * '0 2 * * *' = Setiap hari jam 2:00 AM
 * Timezone: Asia/Jakarta (WIB)
 */
exports.cleanupOldOrders = functions
  .region('asia-southeast2') // Server di Jakarta untuk latency rendah
  .pubsub
  .schedule('0 2 * * *') // Jalan setiap hari jam 2 pagi
  .timeZone('Asia/Jakarta')
  .onRun(async (context) => {
    console.log('🧹 Starting cleanup of old completed orders...');
    
    try {
      const db = admin.firestore();
      
      // Hitung 60 hari yang lalu
      const sixtyDaysAgo = new Date();
      sixtyDaysAgo.setDate(sixtyDaysAgo.getDate() - 60);
      
      console.log(`🔍 Looking for orders completed before: ${sixtyDaysAgo.toISOString()}`);
      
      // Query orders dengan status 'completed' dan completedAt < 60 hari lalu
      const ordersToDelete = await db.collection('orders')
        .where('deliveryStatus', '==', 'completed')
        .where('completedAt', '<', admin.firestore.Timestamp.fromDate(sixtyDaysAgo))
        .get();
      
      if (ordersToDelete.empty) {
        console.log('✅ No old orders to clean up.');
        return null;
      }
      
      console.log(`🗑️ Found ${ordersToDelete.size} orders to delete`);
      
      // Batch delete (max 500 per batch)
      const batchSize = 500;
      const batches = [];
      let currentBatch = db.batch();
      let operationCount = 0;
      
      ordersToDelete.docs.forEach((doc) => {
        currentBatch.delete(doc.ref);
        operationCount++;
        
        // Jika sudah 500 operasi, commit batch dan buat batch baru
        if (operationCount === batchSize) {
          batches.push(currentBatch.commit());
          currentBatch = db.batch();
          operationCount = 0;
        }
      });
      
      // Commit sisa operasi
      if (operationCount > 0) {
        batches.push(currentBatch.commit());
      }
      
      // Execute all batches
      await Promise.all(batches);
      
      console.log(`✅ Successfully deleted ${ordersToDelete.size} old completed orders`);
      
      return {
        success: true,
        deletedCount: ordersToDelete.size,
        cutoffDate: sixtyDaysAgo.toISOString()
      };
      
    } catch (error) {
      console.error('❌ Error during cleanup:', error);
      throw error;
    }
  });

/**
 * Manual trigger function untuk cleanup (opsional)
 * Bisa dipanggil manual dari admin panel jika perlu cleanup sekarang
 */
exports.triggerCleanupNow = functions.https.onCall(async (data, context) => {
  // Validasi: hanya admin yang bisa trigger manual cleanup
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated.'
    );
  }

  const userDoc = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();
  
  if (!userDoc.exists || userDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can trigger manual cleanup.'
    );
  }

  console.log('🧹 Manual cleanup triggered by admin:', context.auth.uid);
  
  try {
    const db = admin.firestore();
    
    // Hitung 60 hari yang lalu (atau custom days dari parameter)
    const daysAgo = data.days || 60;
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysAgo);
    
    const ordersToDelete = await db.collection('orders')
      .where('deliveryStatus', '==', 'completed')
      .where('completedAt', '<', admin.firestore.Timestamp.fromDate(cutoffDate))
      .get();
    
    if (ordersToDelete.empty) {
      return {
        success: true,
        message: 'No orders to clean up',
        deletedCount: 0
      };
    }
    
    // Batch delete
    const batchSize = 500;
    const batches = [];
    let currentBatch = db.batch();
    let operationCount = 0;
    
    ordersToDelete.docs.forEach((doc) => {
      currentBatch.delete(doc.ref);
      operationCount++;
      
      if (operationCount === batchSize) {
        batches.push(currentBatch.commit());
        currentBatch = db.batch();
        operationCount = 0;
      }
    });
    
    if (operationCount > 0) {
      batches.push(currentBatch.commit());
    }
    
    await Promise.all(batches);
    
    console.log(`✅ Manual cleanup completed: ${ordersToDelete.size} orders deleted`);
    
    return {
      success: true,
      message: `Successfully deleted ${ordersToDelete.size} orders older than ${daysAgo} days`,
      deletedCount: ordersToDelete.size,
      cutoffDate: cutoffDate.toISOString()
    };
    
  } catch (error) {
    console.error('❌ Error during manual cleanup:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to cleanup orders: ' + error.message
    );
  }
});

/**
 * Admin function untuk delete ALL orders (untuk reset database)
 * HATI-HATI: Ini akan menghapus SEMUA orders tanpa filter!
 */
exports.deleteAllOrders = functions.https.onCall(async (data, context) => {
  // Validasi: hanya admin yang bisa trigger
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated.'
    );
  }

  const userDoc = await admin.firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();
  
  if (!userDoc.exists || userDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can delete all orders.'
    );
  }

  // Extra confirmation: require confirmation token
  const confirmToken = data.confirmToken;
  if (confirmToken !== 'DELETE_ALL_ORDERS_CONFIRM') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid confirmation token. Please confirm with correct token.'
    );
  }

  console.log('🗑️ DELETE ALL ORDERS triggered by admin:', context.auth.uid);
  
  try {
    const db = admin.firestore();
    
    // Get ALL orders (no filter)
    const ordersSnapshot = await db.collection('orders').get();
    
    if (ordersSnapshot.empty) {
      return {
        success: true,
        message: 'No orders to delete',
        deletedCount: 0
      };
    }
    
    console.log(`⚠️ Deleting ${ordersSnapshot.size} orders...`);
    
    // Batch delete
    const batchSize = 500;
    const batches = [];
    let currentBatch = db.batch();
    let operationCount = 0;
    
    ordersSnapshot.docs.forEach((doc) => {
      currentBatch.delete(doc.ref);
      operationCount++;
      
      if (operationCount === batchSize) {
        batches.push(currentBatch.commit());
        currentBatch = db.batch();
        operationCount = 0;
      }
    });
    
    if (operationCount > 0) {
      batches.push(currentBatch.commit());
    }
    
    await Promise.all(batches);
    
    console.log(`✅ Successfully deleted ${ordersSnapshot.size} orders`);
    
    return {
      success: true,
      message: `Successfully deleted ALL ${ordersSnapshot.size} orders`,
      deletedCount: ordersSnapshot.size
    };
    
  } catch (error) {
    console.error('❌ Error deleting all orders:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to delete orders: ' + error.message
    );
  }
});
