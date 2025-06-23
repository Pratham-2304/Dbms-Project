-- Create database for NOVA Pharmacy Chain
CREATE DATABASE IF NOT EXISTS nova_pharmacy;
USE nova_pharmacy;

-- Patient table
CREATE TABLE Patient (
    aadharID VARCHAR(12) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    age INT CHECK (age > 0),
    primaryPhysician VARCHAR(12) NOT NULL
);

-- Doctor table
CREATE TABLE Doctor (
    aadharID VARCHAR(12) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    specialty VARCHAR(100) NOT NULL,
    yearsOfExperience INT CHECK (yearsOfExperience >= 0)
);

-- Adding foreign key to Patient after Doctor table is created
ALTER TABLE Patient 
ADD CONSTRAINT fk_patient_doctor 
FOREIGN KEY (primaryPhysician) REFERENCES Doctor(aadharID);

-- Pharmaceutical Company table
CREATE TABLE PharmaceuticalCompany (
    name VARCHAR(100) PRIMARY KEY,
    phoneNumber VARCHAR(15) NOT NULL
);

-- Pharmacy table
CREATE TABLE Pharmacy (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    phone VARCHAR(15) NOT NULL
);

-- Drug table with pharmaceutical company foreign key
CREATE TABLE Drug (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tradeName VARCHAR(100) NOT NULL,
    formula VARCHAR(255) NOT NULL,
    companyName VARCHAR(100) NOT NULL,
    CONSTRAINT fk_drug_company FOREIGN KEY (companyName) REFERENCES PharmaceuticalCompany(name) ON DELETE CASCADE,
    UNIQUE KEY unique_tradename_company (tradeName, companyName)
);

-- Contract table for pharmaceutical companies and pharmacies
CREATE TABLE Contract (
    id INT AUTO_INCREMENT PRIMARY KEY,
    pharmacyID INT NOT NULL,
    companyName VARCHAR(100) NOT NULL,
    startDate DATE NOT NULL,
    endDate DATE NOT NULL,
    contractContent TEXT NOT NULL,
    supervisorName VARCHAR(100) NOT NULL,
    CONSTRAINT fk_contract_pharmacy FOREIGN KEY (pharmacyID) REFERENCES Pharmacy(id),
    CONSTRAINT fk_contract_company FOREIGN KEY (companyName) REFERENCES PharmaceuticalCompany(name),
    CHECK (endDate > startDate)
);

-- Pharmacy Drug table (junction table between Pharmacy and Drug)
CREATE TABLE PharmacyDrug (
    pharmacyID INT NOT NULL,
    drugID INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    PRIMARY KEY (pharmacyID, drugID),
    CONSTRAINT fk_pharmacy_drug_pharmacy FOREIGN KEY (pharmacyID) REFERENCES Pharmacy(id),
    CONSTRAINT fk_pharmacy_drug_drug FOREIGN KEY (drugID) REFERENCES Drug(id)
);

-- Prescription table
CREATE TABLE Prescription (
    id INT AUTO_INCREMENT PRIMARY KEY,
    patientID VARCHAR(12) NOT NULL,
    doctorID VARCHAR(12) NOT NULL,
    prescriptionDate DATE NOT NULL,
    CONSTRAINT fk_prescription_patient FOREIGN KEY (patientID) REFERENCES Patient(aadharID),
    CONSTRAINT fk_prescription_doctor FOREIGN KEY (doctorID) REFERENCES Doctor(aadharID),
    UNIQUE KEY unique_patient_doctor_date (patientID, doctorID, prescriptionDate)
);

-- Prescription Detail table
CREATE TABLE PrescriptionDetail (
    prescriptionID INT NOT NULL,
    drugID INT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (prescriptionID, drugID),
    CONSTRAINT fk_prescription_detail_prescription FOREIGN KEY (prescriptionID) REFERENCES Prescription(id),
    CONSTRAINT fk_prescription_detail_drug FOREIGN KEY (drugID) REFERENCES Drug(id)
);

-- Trigger to ensure doctor has at least one patient
DELIMITER //
CREATE TRIGGER check_doctor_has_patients BEFORE DELETE ON Patient
FOR EACH ROW
BEGIN
    DECLARE doctor_patient_count INT;
    
    SELECT COUNT(*) INTO doctor_patient_count 
    FROM Patient 
    WHERE primaryPhysician = OLD.primaryPhysician AND aadharID != OLD.aadharID;
    
    IF doctor_patient_count = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Cannot delete patient: Doctor must have at least one patient';
    END IF;
END //
DELIMITER ;

DELIMITER //

-- Procedure to display all Patients
CREATE PROCEDURE ShowAllPatients()
BEGIN
    SELECT * FROM Patient ORDER BY name;
END //

-- Procedure to display all Doctors
CREATE PROCEDURE ShowAllDoctors()
BEGIN
    SELECT * FROM Doctor ORDER BY name;
END //

-- Procedure to display all Pharmaceutical Companies
CREATE PROCEDURE ShowAllPharmaceuticalCompanies()
BEGIN
    SELECT * FROM PharmaceuticalCompany ORDER BY name;
END //

-- Procedure to display all Pharmacies
CREATE PROCEDURE ShowAllPharmacies()
BEGIN
    SELECT * FROM Pharmacy ORDER BY id;
END //

-- Procedure to display all Drugs
CREATE PROCEDURE ShowAllDrugs()
BEGIN
    SELECT * FROM Drug ORDER BY id;
END //

-- Procedure to display all Contracts
CREATE PROCEDURE ShowAllContracts()
BEGIN
    SELECT c.*, p.name as pharmacy_name, pc.name as company_name
    FROM Contract c
    JOIN Pharmacy p ON c.pharmacyID = p.id
    JOIN PharmaceuticalCompany pc ON c.companyName = pc.name
    ORDER BY c.id;
END //

-- Procedure to display all Pharmacy-Drug relationships (inventory)
CREATE PROCEDURE ShowAllPharmacyDrugs()
BEGIN
    SELECT pd.*, p.name as pharmacy_name, d.tradeName as drug_name
    FROM PharmacyDrug pd
    JOIN Pharmacy p ON pd.pharmacyID = p.id
    JOIN Drug d ON pd.drugID = d.id
    ORDER BY pd.pharmacyID, d.id;
END //

-- Procedure to display all Prescriptions
CREATE PROCEDURE ShowAllPrescriptions()
BEGIN
    SELECT p.*, pt.name as patient_name, d.name as doctor_name
    FROM Prescription p
    JOIN Patient pt ON p.patientID = pt.aadharID
    JOIN Doctor d ON p.doctorID = d.aadharID
    ORDER BY p.id;
END //

-- Procedure to display all Prescription Details
CREATE PROCEDURE ShowAllPrescriptionDetails()
BEGIN
    SELECT pd.*, p.prescriptionDate, d.tradeName as drug_name
    FROM PrescriptionDetail pd
    JOIN Prescription p ON pd.prescriptionID = p.id
    JOIN Drug d ON pd.drugID = d.id
    ORDER BY pd.prescriptionID;
END //

DELIMITER ;

-- Stored Procedure 1: Add a new pharmacy
DELIMITER //
CREATE PROCEDURE AddPharmacy(
    IN p_name VARCHAR(100),
    IN p_address VARCHAR(255),
    IN p_phone VARCHAR(15)
)
BEGIN
    INSERT INTO Pharmacy (name, address, phone) 
    VALUES (p_name, p_address, p_phone);
END //
DELIMITER ;

-- Stored Procedure 2: Add a new pharmaceutical company
DELIMITER //
CREATE PROCEDURE AddPharmaceuticalCompany(
    IN p_name VARCHAR(100),
    IN p_phone VARCHAR(15)
)
BEGIN
    INSERT INTO PharmaceuticalCompany (name, phoneNumber) 
    VALUES (p_name, p_phone);
END //
DELIMITER ;

-- Stored Procedure 3: Add a new patient
DELIMITER //
CREATE PROCEDURE AddPatient(
    IN p_aadharID VARCHAR(12),
    IN p_name VARCHAR(100),
    IN p_address VARCHAR(255),
    IN p_age INT,
    IN p_primaryPhysician VARCHAR(12)
)
BEGIN
    -- Check if doctor exists
    DECLARE doctor_exists INT;
    SELECT COUNT(*) INTO doctor_exists FROM Doctor WHERE aadharID = p_primaryPhysician;
    
    IF doctor_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Primary physician does not exist';
    ELSE
        INSERT INTO Patient (aadharID, name, address, age, primaryPhysician)
        VALUES (p_aadharID, p_name, p_address, p_age, p_primaryPhysician);
    END IF;
END //
DELIMITER ;

-- Stored Procedure 4: Add a new doctor
DELIMITER //
CREATE PROCEDURE AddDoctor(
    IN p_aadharID VARCHAR(12),
    IN p_name VARCHAR(100),
    IN p_specialty VARCHAR(100),
    IN p_yearsOfExperience INT
)
BEGIN
    INSERT INTO Doctor (aadharID, name, specialty, yearsOfExperience)
    VALUES (p_aadharID, p_name, p_specialty, p_yearsOfExperience);
END //
DELIMITER ;

-- Stored Procedure 5: Add a new drug
DELIMITER //
CREATE PROCEDURE AddDrug(
    IN p_tradeName VARCHAR(100),
    IN p_formula VARCHAR(255),
    IN p_companyName VARCHAR(100)
)
BEGIN
    -- Check if pharmaceutical company exists
    DECLARE company_exists INT;
    SELECT COUNT(*) INTO company_exists FROM PharmaceuticalCompany WHERE name = p_companyName;
    
    IF company_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmaceutical company does not exist';
    ELSE
        INSERT INTO Drug (tradeName, formula, companyName)
        VALUES (p_tradeName, p_formula, p_companyName);
        SELECT LAST_INSERT_ID() AS drug_id;
    END IF;
END //
DELIMITER ;

-- Stored Procedure 6: Add drug to pharmacy with price
DELIMITER //
CREATE PROCEDURE AddDrugToPharmacy(
    IN p_pharmacyID INT,
    IN p_drugID INT,
    IN p_price DECIMAL(10, 2),
    IN p_initialStock INT
)
BEGIN
    -- Check if pharmacy and drug exist
    DECLARE pharmacy_exists INT;
    DECLARE drug_exists INT;
    
    SELECT COUNT(*) INTO pharmacy_exists FROM Pharmacy WHERE id = p_pharmacyID;
    SELECT COUNT(*) INTO drug_exists FROM Drug WHERE id = p_drugID;
    
    IF pharmacy_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmacy does not exist';
    ELSEIF drug_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug does not exist';
    ELSE
        INSERT INTO PharmacyDrug (pharmacyID, drugID, price, stock)
        VALUES (p_pharmacyID, p_drugID, p_price, p_initialStock)
        ON DUPLICATE KEY UPDATE price = p_price, stock = p_initialStock;
    END IF;
END //
DELIMITER ;

-- Stored Procedure 7: Add a new contract
DELIMITER //
CREATE PROCEDURE AddContract(
    IN p_pharmacyID INT,
    IN p_companyName VARCHAR(100),
    IN p_startDate DATE,
    IN p_endDate DATE,
    IN p_contractContent TEXT,
    IN p_supervisorName VARCHAR(100)
)
BEGIN
    -- Check if pharmacy and company exist
    DECLARE pharmacy_exists INT;
    DECLARE company_exists INT;
    
    SELECT COUNT(*) INTO pharmacy_exists FROM Pharmacy WHERE id = p_pharmacyID;
    SELECT COUNT(*) INTO company_exists FROM PharmaceuticalCompany WHERE name = p_companyName;
    
    IF pharmacy_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmacy does not exist';
    ELSEIF company_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmaceutical company does not exist';
    ELSE
        INSERT INTO Contract (pharmacyID, companyName, startDate, endDate, contractContent, supervisorName)
        VALUES (p_pharmacyID, p_companyName, p_startDate, p_endDate, p_contractContent, p_supervisorName);
        SELECT LAST_INSERT_ID() AS contract_id;
    END IF;
END //
DELIMITER ;

-- Stored Procedure 8: Update contract supervisor
DELIMITER //
CREATE PROCEDURE UpdateContractSupervisor(
    IN p_contractID INT,
    IN p_newSupervisorName VARCHAR(100)
)
BEGIN
    UPDATE Contract
    SET supervisorName = p_newSupervisorName
    WHERE id = p_contractID;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Contract not found';
    END IF;
END //
DELIMITER ;

-- Stored Procedure 9: Add a new prescription
DELIMITER //
CREATE PROCEDURE AddPrescription(
    IN p_patientID VARCHAR(12),
    IN p_doctorID VARCHAR(12),
    IN p_prescriptionDate DATE
)
BEGIN
    -- Check if patient and doctor exist
    DECLARE patient_exists INT;
    DECLARE doctor_exists INT;
    DECLARE existing_prescription INT;
    
    SELECT COUNT(*) INTO patient_exists FROM Patient WHERE aadharID = p_patientID;
    SELECT COUNT(*) INTO doctor_exists FROM Doctor WHERE aadharID = p_doctorID;
    
    IF patient_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient does not exist';
    ELSEIF doctor_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor does not exist';
    ELSE
        -- Check if a prescription already exists for this patient and doctor
        SELECT id INTO existing_prescription FROM Prescription 
        WHERE patientID = p_patientID AND doctorID = p_doctorID
        LIMIT 1;
        
        IF existing_prescription IS NOT NULL THEN
            -- Update existing prescription date if it's older
            UPDATE Prescription 
            SET prescriptionDate = p_prescriptionDate 
            WHERE id = existing_prescription AND prescriptionDate < p_prescriptionDate;
            
            -- Delete old prescription details to replace with new ones
            IF ROW_COUNT() > 0 THEN
                DELETE FROM PrescriptionDetail WHERE prescriptionID = existing_prescription;
            END IF;
            
            SELECT existing_prescription AS prescription_id;
        ELSE
            -- Create new prescription
            INSERT INTO Prescription (patientID, doctorID, prescriptionDate)
            VALUES (p_patientID, p_doctorID, p_prescriptionDate);
            SELECT LAST_INSERT_ID() AS prescription_id;
        END IF;
    END IF;
END //
DELIMITER ;

-- Stored Procedure 10: Add drug to prescription
DELIMITER //
CREATE PROCEDURE AddDrugToPrescription(
    IN p_prescriptionID INT,
    IN p_drugID INT,
    IN p_quantity INT
)
BEGIN
    -- Check if prescription and drug exist
    DECLARE prescription_exists INT;
    DECLARE drug_exists INT;
    
    SELECT COUNT(*) INTO prescription_exists FROM Prescription WHERE id = p_prescriptionID;
    SELECT COUNT(*) INTO drug_exists FROM Drug WHERE id = p_drugID;
    
    IF prescription_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prescription does not exist';
    ELSEIF drug_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug does not exist';
    ELSE
        INSERT INTO PrescriptionDetail (prescriptionID, drugID, quantity)
        VALUES (p_prescriptionID, p_drugID, p_quantity)
        ON DUPLICATE KEY UPDATE quantity = p_quantity;
    END IF;
END //
DELIMITER ;

-- Stored Procedure 11: Delete a pharmacy
DELIMITER //
CREATE PROCEDURE DeletePharmacy(
    IN p_pharmacyID INT
)
BEGIN
    -- Delete related records first
    DELETE FROM PharmacyDrug WHERE pharmacyID = p_pharmacyID;
    DELETE FROM Contract WHERE pharmacyID = p_pharmacyID;
    
    -- Then delete the pharmacy
    DELETE FROM Pharmacy WHERE id = p_pharmacyID;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmacy not found';
    END IF;
END //
DELIMITER ;

-- Stored Procedure 12: Delete a pharmaceutical company
DELIMITER //
CREATE PROCEDURE DeletePharmaceuticalCompany(
    IN p_companyName VARCHAR(100)
)
BEGIN
    -- Drugs will be automatically deleted due to CASCADE
    DELETE FROM Contract WHERE companyName = p_companyName;
    DELETE FROM PharmaceuticalCompany WHERE name = p_companyName;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmaceutical company not found';
    END IF;
END //
DELIMITER ;

-- Stored Procedure 13: Generate patient prescription report for a given period
DELIMITER //
CREATE PROCEDURE GetPatientPrescriptionsInPeriod(
    IN p_patientID VARCHAR(12),
    IN p_startDate DATE,
    IN p_endDate DATE
)
BEGIN
    SELECT 
        p.id AS prescription_id,
        p.prescriptionDate,
        d.name AS doctor_name,
        d.specialty AS doctor_specialty,
        drug.tradeName AS drug_name,
        drug.formula AS drug_formula,
        drug.companyName AS manufacturer,
        pd.quantity
    FROM 
        Prescription p
    JOIN 
        Doctor d ON p.doctorID = d.aadharID
    JOIN 
        PrescriptionDetail pd ON p.id = pd.prescriptionID
    JOIN 
        Drug drug ON pd.drugID = drug.id
    WHERE 
        p.patientID = p_patientID
        AND p.prescriptionDate BETWEEN p_startDate AND p_endDate
    ORDER BY 
        p.prescriptionDate DESC;
END //
DELIMITER ;

-- Stored Procedure 14: Print prescription details for a given patient and date
DELIMITER //
CREATE PROCEDURE GetPrescriptionDetails(
    IN p_patientID VARCHAR(12),
    IN p_date DATE
)
BEGIN
    SELECT 
        p.id AS prescription_id,
        pt.name AS patient_name,
        pt.age AS patient_age,
        pt.address AS patient_address,
        d.name AS doctor_name,
        d.specialty AS doctor_specialty,
        p.prescriptionDate,
        drug.tradeName AS drug_name,
        drug.formula AS drug_formula,
        drug.companyName AS manufacturer,
        pd.quantity
    FROM 
        Prescription p
    JOIN 
        Patient pt ON p.patientID = pt.aadharID
    JOIN 
        Doctor d ON p.doctorID = d.aadharID
    JOIN 
        PrescriptionDetail pd ON p.id = pd.prescriptionID
    JOIN 
        Drug drug ON pd.drugID = drug.id
    WHERE 
        p.patientID = p_patientID
        AND p.prescriptionDate = p_date
    ORDER BY 
        drug.tradeName;
END //
DELIMITER ;

-- Stored Procedure 15: Get details of drugs produced by a company
DELIMITER //
CREATE PROCEDURE GetCompanyDrugs(
    IN p_companyName VARCHAR(100)
)
BEGIN
    SELECT 
        id AS drug_id,
        tradeName,
        formula,
        (SELECT COUNT(*) FROM PharmacyDrug WHERE drugID = Drug.id) AS available_at_pharmacies_count
    FROM 
        Drug
    WHERE 
        companyName = p_companyName
    ORDER BY 
        tradeName;
END //
DELIMITER ;

-- Stored Procedure 16: Print pharmacy stock position
DELIMITER //
CREATE PROCEDURE GetPharmacyStock(
    IN p_pharmacyID INT
)
BEGIN
    SELECT 
        p.name AS pharmacy_name,
        p.address AS pharmacy_address,
        d.tradeName AS drug_name,
        d.formula AS drug_formula,
        d.companyName AS manufacturer,
        pd.price AS selling_price,
        pd.stock AS available_quantity
    FROM 
        Pharmacy p
    JOIN 
        PharmacyDrug pd ON p.id = pd.pharmacyID
    JOIN 
        Drug d ON pd.drugID = d.id
    WHERE 
        p.id = p_pharmacyID
    ORDER BY 
        d.tradeName;
END //
DELIMITER ;

-- Stored Procedure 17: Get pharmacy-pharmaceutical company contract details
DELIMITER //
CREATE PROCEDURE GetContractDetails(
    IN p_pharmacyID INT,
    IN p_companyName VARCHAR(100)
)
BEGIN
    SELECT 
        c.id AS contract_id,
        p.name AS pharmacy_name,
        p.address AS pharmacy_address,
        p.phone AS pharmacy_phone,
        pc.name AS company_name,
        pc.phoneNumber AS company_phone,
        c.startDate,
        c.endDate,
        c.supervisorName,
        c.contractContent
    FROM 
        Contract c
    JOIN 
        Pharmacy p ON c.pharmacyID = p.id
    JOIN 
        PharmaceuticalCompany pc ON c.companyName = pc.name
    WHERE 
        c.pharmacyID = p_pharmacyID
        AND c.companyName = p_companyName
    ORDER BY 
        c.endDate DESC;
END //
DELIMITER ;

-- Stored Procedure 18: Get patients list for a doctor
DELIMITER //
CREATE PROCEDURE GetDoctorPatients(
    IN p_doctorID VARCHAR(12)
)
BEGIN
    SELECT 
        p.aadharID,
        p.name,
        p.address,
        p.age,
        (SELECT COUNT(*) FROM Prescription WHERE doctorID = p_doctorID AND patientID = p.aadharID) AS prescription_count
    FROM 
        Patient p
    WHERE 
        p.primaryPhysician = p_doctorID
    ORDER BY 
        p.name;
END //
DELIMITER ;

-- Stored Procedure 19: Update drug stock at pharmacy
DELIMITER //
CREATE PROCEDURE UpdateDrugStock(
    IN p_pharmacyID INT,
    IN p_drugID INT,
    IN p_newStock INT
)
BEGIN
    UPDATE PharmacyDrug
    SET stock = p_newStock
    WHERE pharmacyID = p_pharmacyID AND drugID = p_drugID;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug not found in pharmacy inventory';
    END IF;
END //
DELIMITER ;

-- Stored Procedure 20: Update drug price at pharmacy
DELIMITER //
CREATE PROCEDURE UpdateDrugPrice(
    IN p_pharmacyID INT,
    IN p_drugID INT,
    IN p_newPrice DECIMAL(10, 2)
)
BEGIN
    UPDATE PharmacyDrug
    SET price = p_newPrice
    WHERE pharmacyID = p_pharmacyID AND drugID = p_drugID;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug not found in pharmacy inventory';
    END IF;
END //
DELIMITER ;



-- Procedure to delete a Patient record
DELIMITER //
CREATE PROCEDURE DeletePatient(
    IN p_aadharID VARCHAR(12)
)
BEGIN
    DECLARE patient_has_prescriptions INT;
    
    -- Check if patient has prescriptions
    SELECT COUNT(*) INTO patient_has_prescriptions FROM Prescription WHERE patientID = p_aadharID;
    
    IF patient_has_prescriptions > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete patient: Patient has existing prescriptions';
    ELSE
        DELETE FROM Patient WHERE aadharID = p_aadharID;
        
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient not found';
        END IF;
    END IF;
END //
DELIMITER ;

-- Procedure to delete a Doctor record
DELIMITER //
CREATE PROCEDURE DeleteDoctor(
    IN p_aadharID VARCHAR(12)
)
BEGIN
    DECLARE doctor_has_patients INT;
    DECLARE doctor_has_prescriptions INT;
    
    -- Check if doctor has patients
    SELECT COUNT(*) INTO doctor_has_patients FROM Patient WHERE primaryPhysician = p_aadharID;
    
    -- Check if doctor has prescriptions
    SELECT COUNT(*) INTO doctor_has_prescriptions FROM Prescription WHERE doctorID = p_aadharID;
    
    IF doctor_has_patients > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete doctor: Doctor has assigned patients';
    ELSEIF doctor_has_prescriptions > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete doctor: Doctor has existing prescriptions';
    ELSE
        DELETE FROM Doctor WHERE aadharID = p_aadharID;
        
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor not found';
        END IF;
    END IF;
END //
DELIMITER ;

-- Procedure to delete a PharmaceuticalCompany record
-- Note: This will cascade delete related drugs due to the ON DELETE CASCADE constraint
DELIMITER //
CREATE PROCEDURE DeletePharmaceuticalCompany(
    IN p_name VARCHAR(100)
)
BEGIN
    -- Delete related contracts first
    DELETE FROM Contract WHERE companyName = p_name;
    
    -- Then delete the company (this will cascade delete drugs)
    DELETE FROM PharmaceuticalCompany WHERE name = p_name;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmaceutical company not found';
    END IF;
END //
DELIMITER ;

-- Procedure to delete a Pharmacy record
DELIMITER //
CREATE PROCEDURE DeletePharmacy(
    IN p_id INT
)
BEGIN
    -- Delete related records first
    DELETE FROM PharmacyDrug WHERE pharmacyID = p_id;
    DELETE FROM Contract WHERE pharmacyID = p_id;
    
    -- Then delete the pharmacy
    DELETE FROM Pharmacy WHERE id = p_id;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmacy not found';
    END IF;
END //
DELIMITER ;

-- Procedure to delete a Drug record
DELIMITER //
CREATE PROCEDURE DeleteDrug(
    IN p_id INT
)
BEGIN
    DECLARE drug_in_prescriptions INT;
    
    -- Check if drug is in any prescription
    SELECT COUNT(*) INTO drug_in_prescriptions FROM PrescriptionDetail WHERE drugID = p_id;
    
    IF drug_in_prescriptions > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete drug: Drug is used in existing prescriptions';
    ELSE
        -- Delete from pharmacy inventory first
        DELETE FROM PharmacyDrug WHERE drugID = p_id;
        
        -- Then delete the drug
        DELETE FROM Drug WHERE id = p_id;
        
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug not found';
        END IF;
    END IF;
END //
DELIMITER ;

-- Procedure to delete a Contract record
DELIMITER //
CREATE PROCEDURE DeleteContract(
    IN p_id INT
)
BEGIN
    DELETE FROM Contract WHERE id = p_id;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Contract not found';
    END IF;
END //
DELIMITER ;

-- Procedure to delete a PharmacyDrug record (remove drug from pharmacy inventory)
DELIMITER //
CREATE PROCEDURE DeletePharmacyDrug(
    IN p_pharmacyID INT,
    IN p_drugID INT
)
BEGIN
    DELETE FROM PharmacyDrug 
    WHERE pharmacyID = p_pharmacyID AND drugID = p_drugID;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug not found in pharmacy inventory';
    END IF;
END //
DELIMITER ;

-- Procedure to delete a Prescription record
DELIMITER //
CREATE PROCEDURE DeletePrescription(
    IN p_id INT
)
BEGIN
    -- Delete prescription details first
    DELETE FROM PrescriptionDetail WHERE prescriptionID = p_id;
    
    -- Then delete the prescription
    DELETE FROM Prescription WHERE id = p_id;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prescription not found';
    END IF;
END //
DELIMITER ;

-- Procedure to delete a PrescriptionDetail record (remove drug from prescription)
DELIMITER //
CREATE PROCEDURE DeletePrescriptionDetail(
    IN p_prescriptionID INT,
    IN p_drugID INT
)
BEGIN
    DELETE FROM PrescriptionDetail 
    WHERE prescriptionID = p_prescriptionID AND drugID = p_drugID;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug not found in prescription';
    END IF;
    
    -- Check if prescription has any drugs left
    DECLARE drugs_left INT;
    SELECT COUNT(*) INTO drugs_left FROM PrescriptionDetail WHERE prescriptionID = p_prescriptionID;
    
    -- If no drugs left, delete the prescription
    IF drugs_left = 0 THEN
        DELETE FROM Prescription WHERE id = p_prescriptionID;
    END IF;
END //
DELIMITER ;


-- Procedure to update Patient information
DELIMITER //
CREATE PROCEDURE UpdatePatient(
    IN p_aadharID VARCHAR(12),
    IN p_name VARCHAR(100),
    IN p_address VARCHAR(255),
    IN p_age INT,
    IN p_primaryPhysician VARCHAR(12)
)
BEGIN
    DECLARE doctor_exists INT;
    
    -- Check if doctor exists
    SELECT COUNT(*) INTO doctor_exists FROM Doctor WHERE aadharID = p_primaryPhysician;
    
    IF doctor_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Primary physician does not exist';
    ELSE
        UPDATE Patient
        SET name = p_name,
            address = p_address,
            age = p_age,
            primaryPhysician = p_primaryPhysician
        WHERE aadharID = p_aadharID;
        
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient not found';
        END IF;
    END IF;
END //
DELIMITER ;

-- Procedure to update Doctor information
DELIMITER //
CREATE PROCEDURE UpdateDoctor(
    IN p_aadharID VARCHAR(12),
    IN p_name VARCHAR(100),
    IN p_specialty VARCHAR(100),
    IN p_yearsOfExperience INT
)
BEGIN
    UPDATE Doctor
    SET name = p_name,
        specialty = p_specialty,
        yearsOfExperience = p_yearsOfExperience
    WHERE aadharID = p_aadharID;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor not found';
    END IF;
END //
DELIMITER ;

-- Procedure to update PharmaceuticalCompany information
DELIMITER //
CREATE PROCEDURE UpdatePharmaceuticalCompany(
    IN p_oldName VARCHAR(100),
    IN p_newName VARCHAR(100),
    IN p_phoneNumber VARCHAR(15)
)
BEGIN
    -- Updating a primary key requires special handling
    -- First, check if the new name already exists (if name is changing)
    IF p_oldName != p_newName THEN
        DECLARE name_exists INT;
        SELECT COUNT(*) INTO name_exists FROM PharmaceuticalCompany WHERE name = p_newName;
        
        IF name_exists > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New company name already exists';
        END IF;
    END IF;
    
    -- Update the company information
    UPDATE PharmaceuticalCompany
    SET name = p_newName,
        phoneNumber = p_phoneNumber
    WHERE name = p_oldName;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmaceutical company not found';
    END IF;
    
    -- If name changed, update related records
    IF p_oldName != p_newName THEN
        -- Update company name in Drug table
        UPDATE Drug SET companyName = p_newName WHERE companyName = p_oldName;
        
        -- Update company name in Contract table
        UPDATE Contract SET companyName = p_newName WHERE companyName = p_oldName;
    END IF;
END //
DELIMITER ;

-- Procedure to update Pharmacy information
DELIMITER //
CREATE PROCEDURE UpdatePharmacy(
    IN p_id INT,
    IN p_name VARCHAR(100),
    IN p_address VARCHAR(255),
    IN p_phone VARCHAR(15)
)
BEGIN
    UPDATE Pharmacy
    SET name = p_name,
        address = p_address,
        phone = p_phone
    WHERE id = p_id;
    
    IF ROW_COUNT() = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmacy not found';
    END IF;
END //
DELIMITER ;

-- Procedure to update Drug information
DELIMITER //
CREATE PROCEDURE UpdateDrug(
    IN p_id INT,
    IN p_tradeName VARCHAR(100),
    IN p_formula VARCHAR(255),
    IN p_companyName VARCHAR(100)
)
BEGIN
    DECLARE company_exists INT;
    
    -- Check if pharmaceutical company exists
    SELECT COUNT(*) INTO company_exists FROM PharmaceuticalCompany 
    WHERE name = p_companyName;
    
    IF company_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmaceutical company does not exist';
    ELSE
        -- Check unique tradename-company constraint
        DECLARE duplicate_exists INT;
        SELECT COUNT(*) INTO duplicate_exists FROM Drug 
        WHERE tradeName = p_tradeName AND companyName = p_companyName AND id != p_id;
        
        IF duplicate_exists > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug with same trade name already exists for this company';
        ELSE
            UPDATE Drug
            SET tradeName = p_tradeName,
                formula = p_formula,
                companyName = p_companyName
            WHERE id = p_id;
            
            IF ROW_COUNT() = 0 THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug not found';
            END IF;
        END IF;
    END IF;
END //
DELIMITER ;

-- Procedure to update Contract information
DELIMITER //
CREATE PROCEDURE UpdateContract(
    IN p_id INT,
    IN p_pharmacyID INT,
    IN p_companyName VARCHAR(100),
    IN p_startDate DATE,
    IN p_endDate DATE,
    IN p_contractContent TEXT,
    IN p_supervisorName VARCHAR(100)
)
BEGIN
    DECLARE pharmacy_exists INT;
    DECLARE company_exists INT;
    
    -- Check if pharmacy exists
    SELECT COUNT(*) INTO pharmacy_exists FROM Pharmacy WHERE id = p_pharmacyID;
    
    -- Check if company exists
    SELECT COUNT(*) INTO company_exists FROM PharmaceuticalCompany 
    WHERE name = p_companyName;
    
    IF pharmacy_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmacy does not exist';
    ELSEIF company_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pharmaceutical company does not exist';
    ELSEIF p_endDate <= p_startDate THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'End date must be after start date';
    ELSE
        UPDATE Contract
        SET pharmacyID = p_pharmacyID,
            companyName = p_companyName,
            startDate = p_startDate,
            endDate = p_endDate,
            contractContent = p_contractContent,
            supervisorName = p_supervisorName
        WHERE id = p_id;
        
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Contract not found';
        END IF;
    END IF;
END //
DELIMITER ;

-- Procedure to update PharmacyDrug information (composite key table)
DELIMITER //
CREATE PROCEDURE UpdatePharmacyDrug(
    IN p_pharmacyID INT,
    IN p_drugID INT,
    IN p_price DECIMAL(10, 2),
    IN p_stock INT
)
BEGIN
    IF p_price <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Price must be greater than zero';
    ELSEIF p_stock < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock cannot be negative';
    ELSE
        UPDATE PharmacyDrug
        SET price = p_price,
            stock = p_stock
        WHERE pharmacyID = p_pharmacyID AND drugID = p_drugID;
        
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug not found in pharmacy inventory';
        END IF;
    END IF;
END //
DELIMITER ;

-- Procedure to update Prescription information
DELIMITER //
CREATE PROCEDURE UpdatePrescription(
    IN p_id INT,
    IN p_patientID VARCHAR(12),
    IN p_doctorID VARCHAR(12),
    IN p_prescriptionDate DATE
)
BEGIN
    DECLARE patient_exists INT;
    DECLARE doctor_exists INT;
    DECLARE duplicate_exists INT;
    
    -- Check if patient exists
    SELECT COUNT(*) INTO patient_exists FROM Patient WHERE aadharID = p_patientID;
    
    -- Check if doctor exists
    SELECT COUNT(*) INTO doctor_exists FROM Doctor WHERE aadharID = p_doctorID;
    
    -- Check for duplicate prescription (same patient, doctor, date)
    SELECT COUNT(*) INTO duplicate_exists FROM Prescription
    WHERE patientID = p_patientID 
    AND doctorID = p_doctorID 
    AND prescriptionDate = p_prescriptionDate
    AND id != p_id;
    
    IF patient_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Patient does not exist';
    ELSEIF doctor_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Doctor does not exist';
    ELSEIF duplicate_exists > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A prescription already exists for this patient, doctor, and date';
    ELSE
        UPDATE Prescription
        SET patientID = p_patientID,
            doctorID = p_doctorID,
            prescriptionDate = p_prescriptionDate
        WHERE id = p_id;
        
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prescription not found';
        END IF;
    END IF;
END //
DELIMITER ;

-- Procedure to update PrescriptionDetail information (composite key table)
DELIMITER //
CREATE PROCEDURE UpdatePrescriptionDetail(
    IN p_prescriptionID INT,
    IN p_drugID INT,
    IN p_quantity INT
)
BEGIN
    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantity must be greater than zero';
    ELSE
        UPDATE PrescriptionDetail
        SET quantity = p_quantity
        WHERE prescriptionID = p_prescriptionID AND drugID = p_drugID;
        
        IF ROW_COUNT() = 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Drug not found in prescription';
        END IF;
    END IF;
END //
DELIMITER ;


-- Create sample data for testing
-- Insert doctors
CALL AddDoctor('123456789012', 'Dr. Sharma', 'Cardiology', 15);
CALL AddDoctor('234567890123', 'Dr. Patel', 'Pediatrics', 8);
CALL AddDoctor('345678901234', 'Dr. Gupta', 'Orthopedics', 12);
CALL AddDoctor('456789012345', 'Dr. Singh', 'Neurology', 20);
CALL AddDoctor('567890123456', 'Dr. Kumar', 'Dermatology', 10);

-- Insert patients
CALL AddPatient('987654321098', 'Rahul Mehta', 'Mumbai', 35, '123456789012');
CALL AddPatient('876543210987', 'Priya Singh', 'Delhi', 28, '234567890123');
CALL AddPatient('765432109876', 'Amit Kumar', 'Bangalore', 42, '345678901234');
CALL AddPatient('654321098765', 'Sneha Sharma', 'Chennai', 25, '456789012345');
CALL AddPatient('543210987654', 'Raj Verma', 'Kolkata', 55, '567890123456');
CALL AddPatient('432109876543', 'Anita Desai', 'Pune', 30, '123456789012');
CALL AddPatient('321098765432', 'Vikram Malhotra', 'Hyderabad', 47, '234567890123');
CALL AddPatient('210987654321', 'Meena Reddy', 'Ahmedabad', 32, '345678901234');
CALL AddPatient('109876543210', 'Suresh Patel', 'Jaipur', 50, '456789012345');
CALL AddPatient('098765432109', 'Neha Joshi', 'Lucknow', 29, '567890123456');

-- Insert pharmaceutical companies
CALL AddPharmaceuticalCompany('Sun Pharma', '9876543210');
CALL AddPharmaceuticalCompany('Cipla', '8765432109');
CALL AddPharmaceuticalCompany('Dr. Reddy\'s', '7654321098');
CALL AddPharmaceuticalCompany('Lupin', '6543210987');
CALL AddPharmaceuticalCompany('Mankind Pharma', '5432109876');

-- Insert pharmacies
CALL AddPharmacy('Nova Central', 'MG Road, Bangalore', '9988776655');
CALL AddPharmacy('Nova Express', 'Connaught Place, Delhi', '8877665544');
CALL AddPharmacy('Nova Plus', 'Bandra, Mumbai', '7766554433');
CALL AddPharmacy('Nova Health', 'T Nagar, Chennai', '6655443322');
CALL AddPharmacy('Nova Care', 'Salt Lake, Kolkata', '5544332211');

-- Insert drugs
CALL AddDrug('Paracetamol 500', 'C8H9NO2', 'Sun Pharma');
CALL AddDrug('Amoxicillin 250', 'C16H19N3O5S', 'Cipla');
CALL AddDrug('Metformin 500', 'C4H11N5', 'Dr. Reddy\'s');
CALL AddDrug('Atorvastatin 10', 'C33H35FN2O5', 'Lupin');
CALL AddDrug('Omeprazole 20', 'C17H19N3O3S', 'Mankind Pharma');
CALL AddDrug('Diazepam 5', 'C16H13ClN2O', 'Sun Pharma');
CALL AddDrug('Ceftriaxone 1g', 'C18H18N8O7S3', 'Cipla');
CALL AddDrug('Lisinopril 10', 'C21H31N3O5', 'Dr. Reddy\'s');
CALL AddDrug('Simvastatin 20', 'C25H38O5', 'Lupin');
CALL AddDrug('Azithromycin 500', 'C38H72N2O12', 'Mankind Pharma');
CALL AddDrug('Ibuprofen 400', 'C13H18O2', 'Sun Pharma');
CALL AddDrug('Losartan 50', 'C22H23ClN6O', 'Cipla');
CALL AddDrug('Amlodipine 5', 'C20H25ClN2O5', 'Dr. Reddy\'s');
CALL AddDrug('Metoprolol 25', 'C15H25NO3', 'Lupin');
CALL AddDrug('Cetirizine 10', 'C21H25ClN2O3', 'Mankind Pharma');

-- Add drugs to pharmacies with prices and stock
-- For Nova Central
CALL AddDrugToPharmacy(1, 1, 5.99, 100);  -- Paracetamol at Nova Central
CALL AddDrugToPharmacy(1, 2, 12.50, 80);  -- Amoxicillin at Nova Central
CALL AddDrugToPharmacy(1, 3, 8.75, 120);  -- Metformin at Nova Central
CALL AddDrugToPharmacy(1, 4, 22.99, 50);  -- Atorvastatin at Nova Central
CALL AddDrugToPharmacy(1, 5, 18.25, 75);  -- Omeprazole at Nova Central
CALL AddDrugToPharmacy(1, 6, 15.00, 60);  -- Diazepam at Nova Central
CALL AddDrugToPharmacy(1, 7, 35.50, 40);  -- Ceftriaxone at Nova Central
CALL AddDrugToPharmacy(1, 8, 20.75, 90);  -- Lisinopril at Nova Central
CALL AddDrugToPharmacy(1, 9, 25.25, 65);  -- Simvastatin at Nova Central
CALL AddDrugToPharmacy(1, 10, 45.99, 30); -- Azithromycin at Nova Central

-- For Nova Express
CALL AddDrugToPharmacy(2, 1, 6.25, 90);   -- Paracetamol at Nova Express
CALL AddDrugToPharmacy(2, 2, 13.00, 70);  -- Amoxicillin at Nova Express
CALL AddDrugToPharmacy(2, 6, 16.50, 55);  -- Diazepam at Nova Express
CALL AddDrugToPharmacy(2, 11, 9.99, 110); -- Ibuprofen at Nova Express
CALL AddDrugToPharmacy(2, 12, 28.75, 45); -- Losartan at Nova Express
CALL AddDrugToPharmacy(2, 13, 32.50, 60); -- Amlodipine at Nova Express
CALL AddDrugToPharmacy(2, 14, 19.25, 80); -- Metoprolol at Nova Express
CALL AddDrugToPharmacy(2, 15, 14.50, 95); -- Cetirizine at Nova Express
CALL AddDrugToPharmacy(2, 3, 9.00, 100);  -- Metformin at Nova Express
CALL AddDrugToPharmacy(2, 4, 23.50, 40);  -- Atorvastatin at Nova Express

-- Create contracts between pharmacies and pharmaceutical companies
CALL AddContract(1, 'Sun Pharma', '2024-01-01', '2024-12-31', 'Supply of pain medications and antibiotics', 'Neha Singh');
CALL AddContract(1, 'Cipla', '2024-02-15', '2025-02-14', 'Supply of antibiotics and cardiovascular drugs', 'Rajesh Kumar');
CALL AddContract(2, 'Dr. Reddy\'s', '2024-03-10', '2025-03-09', 'Supply of diabetes and hypertension medications', 'Amit Sharma');
CALL AddContract(2, 'Lupin', '2024-04-05', '2025-04-04', 'Supply of cholesterol and cardio medications', 'Priya Patel');
CALL AddContract(3, 'Mankind Pharma', '2024-05-20', '2025-05-19', 'Supply of gastrointestinal and antiallergic drugs', 'Sanjay Gupta');

-- Create some prescriptions
CALL AddPrescription('987654321098', '123456789012', '2024-03-15');
SET @prescription1 = LAST_INSERT_ID();
CALL AddDrugToPrescription(@prescription1, 1, 20);  -- 20 tablets of Paracetamol
CALL AddDrugToPrescription(@prescription1, 4, 10);  -- 10 tablets of Atorvastatin

CALL AddPrescription('876543210987', '234567890123', '2024-03-18');
SET @prescription2 = LAST_INSERT_ID();
CALL AddDrugToPrescription(@prescription2, 2, 15);  -- 15 capsules of Amoxicillin
CALL AddDrugToPrescription(@prescription2, 15, 10); -- 10 tablets of Cetirizine

CALL AddPrescription('765432109876', '345678901234', '2024-03-20');
SET @prescription3 = LAST_INSERT_ID();
CALL AddDrugToPrescription(@prescription3, 11, 30); -- 30 tablets of Ibuprofen
CALL AddDrugToPrescription(@prescription3, 3, 60);  -- 60 tablets of Metformin

CALL AddPrescription('654321098765', '456789012345', '2024-03-22');
SET @prescription4 = LAST_INSERT_ID();
CALL AddDrugToPrescription(@prescription4, 13, 30); -- 30 tablets of Amlodipine
CALL AddDrugToPrescription(@prescription4, 14, 30); -- 30 tablets of Metoprolol

CALL AddPrescription('543210987654', '567890123456', '2024-03-25');
SET @prescription5 = LAST_INSERT_ID();
CALL AddDrugToPrescription(@prescription5, 5, 30);