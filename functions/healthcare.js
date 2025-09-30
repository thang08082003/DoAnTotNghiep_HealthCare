const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");
const {
  formatDoctorData,
  formatPatientData,
  mapSpecialtyToDiseaseFocus,
  mapDiseaseFocusToSpecialty,
} = require("./helpers");

const db = getFirestore();

/**
 * Enhanced function để lấy bác sĩ theo disease focus (tương thích với Flutter app)
 */
exports.getDoctorsByDiseaseFocus = onCall(async (request) => {
  try {
    const {diseaseFocus} = request.data;
    
    if (!diseaseFocus) {
      throw new HttpsError("invalid-argument", "Disease focus is required");
    }

    logger.info(`Getting doctors with disease focus: ${diseaseFocus}`);

    // First, get all doctors
    const doctorsQuery = await db.collection("users")
        .where("role", "==", "doctor")
        .get();

    const matchingDoctors = [];
    
    doctorsQuery.forEach((doc) => {
      const data = doc.data();
      logger.info(`Processing doctor: ${data.name}, specialty: ${data.specialty}, diseaseFocus: ${data.diseaseFocus}`);
      
      // Check if doctor matches the disease focus
      const doctorSpecialty = data.specialty;
      const doctorDiseaseFocus = data.diseaseFocus;
      
      // Convert specialty to disease focus for comparison
      const mappedDiseaseFocus = mapSpecialtyToDiseaseFocus(doctorSpecialty);
      
      // Match by diseaseFocus field or by converted specialty
      if (doctorDiseaseFocus === diseaseFocus || mappedDiseaseFocus === diseaseFocus) {
        matchingDoctors.push(formatDoctorData(doc.id, data));
        logger.info(`Doctor ${data.name} matches disease focus ${diseaseFocus}`);
      } else {
        logger.info(`Doctor ${data.name} does not match disease focus ${diseaseFocus} (has: ${doctorDiseaseFocus}/${mappedDiseaseFocus})`);
      }
    });

    logger.info(`Found ${matchingDoctors.length} doctors with disease focus ${diseaseFocus}`);
    return {success: true, doctors: matchingDoctors, count: matchingDoctors.length};
  } catch (error) {
    logger.error("Error getting doctors by disease focus:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Function để assign bác sĩ cho bệnh nhân
 */
exports.assignDoctorToPatient = onCall(async (request) => {
  try {
    const {patientId, doctorId} = request.data;
    
    if (!patientId || !doctorId) {
      throw new HttpsError("invalid-argument", "PatientId and doctorId are required");
    }

    logger.info(`Assigning doctor ${doctorId} to patient ${patientId}`);

    // Verify doctor exists and is a doctor
    const doctorDoc = await db.collection("users").doc(doctorId).get();
    if (!doctorDoc.exists || doctorDoc.data().role !== "doctor") {
      throw new HttpsError("not-found", "Doctor not found");
    }

    // Verify patient exists and is a patient
    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists || patientDoc.data().role !== "patient") {
      throw new HttpsError("not-found", "Patient not found");
    }

    // Update patient with assigned doctor
    await db.collection("users").doc(patientId).update({
      assignedDoctorId: doctorId,
      updatedAt: new Date().toISOString(),
    });

    logger.info(`Successfully assigned doctor ${doctorId} to patient ${patientId}`);
    return {success: true, message: "Doctor assigned successfully"};
  } catch (error) {
    logger.error("Error assigning doctor to patient:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Function để lấy thông tin bệnh nhân với bác sĩ được assign
 */
exports.getPatientWithDoctor = onCall(async (request) => {
  try {
    const {patientId} = request.data;
    
    if (!patientId) {
      throw new HttpsError("invalid-argument", "PatientId is required");
    }

    logger.info(`Getting patient info with assigned doctor: ${patientId}`);

    const patientDoc = await db.collection("users").doc(patientId).get();
    if (!patientDoc.exists) {
      throw new HttpsError("not-found", "Patient not found");
    }

    const patientData = patientDoc.data();
    const formattedPatient = formatPatientData(patientDoc.id, patientData);

    // Get assigned doctor if exists
    let assignedDoctor = null;
    if (patientData.assignedDoctorId) {
      const doctorDoc = await db.collection("users").doc(patientData.assignedDoctorId).get();
      if (doctorDoc.exists) {
        assignedDoctor = formatDoctorData(doctorDoc.id, doctorDoc.data());
      }
    }

    return {
      success: true,
      patient: formattedPatient,
      assignedDoctor,
    };
  } catch (error) {
    logger.error("Error getting patient with doctor:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Function để cập nhật disease focus của user
 */
exports.updateUserDiseaseFocus = onCall(async (request) => {
  try {
    const {userId, diseaseFocus} = request.data;
    
    if (!userId || !diseaseFocus) {
      throw new HttpsError("invalid-argument", "UserId and diseaseFocus are required");
    }

    logger.info(`Updating disease focus for user ${userId} to ${diseaseFocus}`);

    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User not found");
    }

    const userData = userDoc.data();
    const updateData = {
      diseaseFocus,
      updatedAt: new Date().toISOString(),
    };

    // If user is a doctor, also update specialty
    if (userData.role === "doctor") {
      updateData.specialty = mapDiseaseFocusToSpecialty(diseaseFocus);
    }

    await db.collection("users").doc(userId).update(updateData);

    logger.info(`Successfully updated disease focus for user ${userId}`);
    return {success: true, message: "Disease focus updated successfully"};
  } catch (error) {
    logger.error("Error updating user disease focus:", error);
    throw new HttpsError("internal", error.message);
  }
});

/**
 * Function để search users theo criteria
 */
exports.searchUsers = onCall(async (request) => {
  try {
    const {role, specialty, diseaseFocus, limit = 50} = request.data;
    
    logger.info(`Searching users with criteria: role=${role}, specialty=${specialty}, diseaseFocus=${diseaseFocus}`);

    let query = db.collection("users");
    
    if (role) {
      query = query.where("role", "==", role);
    }
    
    if (specialty && role === "doctor") {
      query = query.where("specialty", "==", specialty);
    }
    
    if (diseaseFocus) {
      query = query.where("diseaseFocus", "==", diseaseFocus);
    }
    
    query = query.limit(limit);
    
    const results = await query.get();
    const users = [];
    
    results.forEach((doc) => {
      const data = doc.data();
      if (data.role === "doctor") {
        users.push(formatDoctorData(doc.id, data));
      } else {
        users.push(formatPatientData(doc.id, data));
      }
    });

    logger.info(`Found ${users.length} users matching criteria`);
    return {success: true, users, count: users.length};
  } catch (error) {
    logger.error("Error searching users:", error);
    throw new HttpsError("internal", error.message);
  }
});