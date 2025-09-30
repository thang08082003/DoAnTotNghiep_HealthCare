const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

const db = getFirestore();

/**
 * Helper function để validate user role
 */
const validateUserRole = async (userId, expectedRole) => {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new Error("User not found");
    }
    
    const userData = userDoc.data();
    if (userData.role !== expectedRole) {
      throw new Error(`User role mismatch. Expected: ${expectedRole}, Got: ${userData.role}`);
    }
    
    return userData;
  } catch (error) {
    logger.error("Error validating user role:", error);
    throw error;
  }
};

/**
 * Helper function để format doctor data
 */
const formatDoctorData = (docId, doctorData) => {
  return {
    id: docId,
    uid: doctorData.uid || docId,
    name: doctorData.name,
    email: doctorData.email,
    specialty: doctorData.specialty,
    diseaseFocus: doctorData.diseaseFocus,
    avatarUrl: doctorData.avatarUrl,
    createdAt: doctorData.createdAt,
    role: "doctor",
  };
};

/**
 * Helper function để format patient data
 */
const formatPatientData = (docId, patientData) => {
  return {
    id: docId,
    uid: patientData.uid || docId,
    name: patientData.name,
    email: patientData.email,
    diseaseFocus: patientData.diseaseFocus,
    assignedDoctorId: patientData.assignedDoctorId,
    avatarUrl: patientData.avatarUrl,
    createdAt: patientData.createdAt,
    role: "patient",
  };
};

/**
 * Helper function để convert specialty enum
 */
const mapSpecialtyToDiseaseFocus = (specialty) => {
  const specialtyMap = {
    "Stress": "stress",
    "Cardiology": "cardiology", 
    "Tim mạch": "cardiology",
    "Diagnosis": "diagnosis",
    "Chuẩn đoán bệnh": "diagnosis",
  };
  
  return specialtyMap[specialty] || specialty.toLowerCase();
};

/**
 * Helper function để convert disease focus to specialty
 */
const mapDiseaseFocusToSpecialty = (diseaseFocus) => {
  const focusMap = {
    "stress": "Stress",
    "cardiology": "Cardiology",
    "diagnosis": "Diagnosis",
  };
  
  return focusMap[diseaseFocus] || diseaseFocus;
};

module.exports = {
  validateUserRole,
  formatDoctorData,
  formatPatientData,
  mapSpecialtyToDiseaseFocus,
  mapDiseaseFocusToSpecialty,
};