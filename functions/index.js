const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// Import healthcare-specific functions
const healthcareFunctions = require("./healthcare");

// Export healthcare functions
exports.getDoctorsByDiseaseFocus = healthcareFunctions.getDoctorsByDiseaseFocus;
exports.assignDoctorToPatient = healthcareFunctions.assignDoctorToPatient;
exports.getPatientWithDoctor = healthcareFunctions.getPatientWithDoctor;
exports.updateUserDiseaseFocus = healthcareFunctions.updateUserDiseaseFocus;
exports.searchUsers = healthcareFunctions.searchUsers;

// =====================================================
// USER MANAGEMENT FUNCTIONS
// =====================================================

/**
 * Cloud Function để lấy danh sách bác sĩ theo chuyên khoa
 */
exports.getDoctorsBySpecialty = onCall(async (request) => {
  try {
    const {specialty} = request.data;
    
    if (!specialty) {
      throw new HttpsError("invalid-argument", "Specialty is required");
    }

    logger.info(`Getting doctors with specialty: ${specialty}`);

    // Query doctors from Firestore
    const doctorsQuery = await db.collection("users")
        .where("role", "==", "doctor")
        .where("specialty", "==", specialty)
        .get();

    const doctors = [];
    doctorsQuery.forEach((doc) => {
      const data = doc.data();
      doctors.push({
        id: doc.id,
        name: data.name,
        email: data.email,
        specialty: data.specialty,
        avatarUrl: data.avatarUrl,
        createdAt: data.createdAt,
      });
    });

    logger.info(`Found ${doctors.length} doctors with specialty ${specialty}`);
    return {success: true, doctors};
  } catch (error) {
    logger.error("Error getting doctors by specialty:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Cloud Function để lấy tất cả bác sĩ
 */
exports.getAllDoctors = onCall(async (request) => {
  try {
    logger.info("Getting all doctors");

    const doctorsQuery = await db.collection("users")
        .where("role", "==", "doctor")
        .get();

    const doctors = [];
    doctorsQuery.forEach((doc) => {
      const data = doc.data();
      doctors.push({
        id: doc.id,
        name: data.name,
        email: data.email,
        specialty: data.specialty,
        avatarUrl: data.avatarUrl,
        createdAt: data.createdAt,
        diseaseFocus: data.diseaseFocus,
      });
    });

    logger.info(`Found ${doctors.length} total doctors`);
    return {success: true, doctors};
  } catch (error) {
    logger.error("Error getting all doctors:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Cloud Function để cập nhật thông tin user
 */
exports.updateUserProfile = onCall(async (request) => {
  try {
    const {userId, updateData} = request.data;
    
    if (!userId || !updateData) {
      throw new HttpsError("invalid-argument", "UserId and updateData are required");
    }

    logger.info(`Updating user profile for userId: ${userId}`);

    // Update user document
    await db.collection("users").doc(userId).update({
      ...updateData,
      updatedAt: new Date().toISOString(),
    });

    logger.info(`Successfully updated user profile for userId: ${userId}`);
    return {success: true, message: "Profile updated successfully"};
  } catch (error) {
    logger.error("Error updating user profile:", error);
    throw new HttpsError("internal", error.message);
  }
});

// =====================================================
// APPOINTMENT MANAGEMENT FUNCTIONS
// =====================================================

/**
 * Cloud Function để tạo cuộc hẹn mới
 */
exports.createAppointment = onCall(async (request) => {
  try {
    const {patientId, doctorId, appointmentDate, notes} = request.data;
    
    if (!patientId || !doctorId || !appointmentDate) {
      throw new HttpsError("invalid-argument", "PatientId, doctorId, and appointmentDate are required");
    }

    logger.info(`Creating appointment for patient ${patientId} with doctor ${doctorId}`);

    // Create appointment document
    const appointmentRef = await db.collection("appointments").add({
      patientId,
      doctorId,
      appointmentDate,
      notes: notes || "",
      status: "scheduled",
      createdAt: new Date().toISOString(),
    });

    logger.info(`Successfully created appointment with ID: ${appointmentRef.id}`);
    return {success: true, appointmentId: appointmentRef.id};
  } catch (error) {
    logger.error("Error creating appointment:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Cloud Function để lấy danh sách cuộc hẹn theo user
 */
exports.getUserAppointments = onCall(async (request) => {
  try {
    const {userId, role} = request.data;
    
    if (!userId || !role) {
      throw new HttpsError("invalid-argument", "UserId and role are required");
    }

    logger.info(`Getting appointments for ${role}: ${userId}`);

    let query;
    if (role === "patient") {
      query = db.collection("appointments").where("patientId", "==", userId);
    } else if (role === "doctor") {
      query = db.collection("appointments").where("doctorId", "==", userId);
    } else {
      throw new HttpsError("invalid-argument", "Invalid role");
    }

    const appointmentsQuery = await query.get();
    const appointments = [];
    
    for (const doc of appointmentsQuery.docs) {
      const data = doc.data();
      
      // Get patient and doctor info
      const patientDoc = await db.collection("users").doc(data.patientId).get();
      const doctorDoc = await db.collection("users").doc(data.doctorId).get();
      
      appointments.push({
        id: doc.id,
        ...data,
        patient: patientDoc.exists ? patientDoc.data() : null,
        doctor: doctorDoc.exists ? doctorDoc.data() : null,
      });
    }

    logger.info(`Found ${appointments.length} appointments for ${role}: ${userId}`);
    return {success: true, appointments};
  } catch (error) {
    logger.error("Error getting user appointments:", error);
    throw new HttpsError("internal", error.message);
  }
});

// =====================================================
// NOTIFICATION/TRIGGER FUNCTIONS
// =====================================================

/**
 * Trigger function khi có user mới đăng ký
 */
exports.onUserCreated = onDocumentCreated("users/{userId}", async (event) => {
  const userData = event.data.data();
  const userId = event.params.userId;
  
  logger.info(`New user created: ${userId}`, userData);
  
  try {
    // Có thể thêm logic như gửi email chào mừng, tạo profile mặc định, v.v.
    if (userData.role === "doctor") {
      logger.info(`New doctor registered: ${userData.name}`);
      // Logic đặc biệt cho bác sĩ mới
    } else if (userData.role === "patient") {
      logger.info(`New patient registered: ${userData.name}`);
      // Logic đặc biệt cho bệnh nhân mới
    }
  } catch (error) {
    logger.error("Error in onUserCreated trigger:", error);
  }
});

/**
 * Trigger function khi có appointment mới
 */
exports.onAppointmentCreated = onDocumentCreated("appointments/{appointmentId}", async (event) => {
  const appointmentData = event.data.data();
  const appointmentId = event.params.appointmentId;
  
  logger.info(`New appointment created: ${appointmentId}`, appointmentData);
  
  try {
    // Logic gửi thông báo cho bác sĩ và bệnh nhân
    logger.info(`Appointment scheduled between patient ${appointmentData.patientId} and doctor ${appointmentData.doctorId}`);
  } catch (error) {
    logger.error("Error in onAppointmentCreated trigger:", error);
  }
});

// =====================================================
// UTILITY FUNCTIONS
// =====================================================

/**
 * HTTP Function để test API
 */
exports.testAPI = onRequest(async (req, res) => {
  logger.info("Test API called");
  
  res.json({
    success: true,
    message: "Healthcare Cloud Functions are working!",
    timestamp: new Date().toISOString(),
  });
});

/**
 * Cloud Function để làm sạch dữ liệu (chạy định kỳ)
 */
exports.cleanupData = onCall(async (request) => {
  try {
    logger.info("Starting data cleanup...");
    
    // Ví dụ: xóa các appointment cũ hơn 30 ngày
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    
    const oldAppointments = await db.collection("appointments")
        .where("createdAt", "<", thirtyDaysAgo.toISOString())
        .where("status", "==", "completed")
        .get();
    
    const batch = db.batch();
    oldAppointments.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    
    logger.info(`Cleaned up ${oldAppointments.size} old appointments`);
    return {success: true, cleanedCount: oldAppointments.size};
  } catch (error) {
    logger.error("Error in data cleanup:", error);
    throw new HttpsError("internal", error.message);
  }
});