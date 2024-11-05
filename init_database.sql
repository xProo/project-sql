
-- Table des moyens de transport
CREATE TABLE Transport (
    id CHAR(3) PRIMARY KEY,
    nom_ligne VARCHAR(32) NOT NULL,
    capacite_max INT CHECK (capacite_max > 0),
    duree_trajet INT CHECK (duree_trajet > 0)
);

-- Table des zones tarifaires
CREATE TABLE ZoneTarifaire (
    numero INT PRIMARY KEY,
    nom VARCHAR(32) NOT NULL,
    prix DECIMAL(5, 2) CHECK (prix >= 0)
);

-- Table des stations
CREATE TABLE Station (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(64) NOT NULL,
    commune VARCHAR(32) NOT NULL,
    zone_numero INT,
    FOREIGN KEY (zone_numero) REFERENCES ZoneTarifaire(numero)
);

-- Table des lignes
CREATE TABLE Ligne (
    code CHAR(3) PRIMARY KEY,
    transport_id CHAR(3) NOT NULL,
    FOREIGN KEY (transport_id) REFERENCES Transport(id)
);

-- Table pour associer les lignes aux stations avec position de la station sur la ligne
CREATE TABLE LigneStation (
    ligne_code CHAR(3),
    station_id INT,
    position INT CHECK (position > 0),
    PRIMARY KEY (ligne_code, station_id),
    FOREIGN KEY (ligne_code) REFERENCES Ligne(code),
    FOREIGN KEY (station_id) REFERENCES Station(id)
);

-- Table des lignes
CREATE TABLE Ligne (
    code CHAR(3) PRIMARY KEY,
    transport_id CHAR(3) NOT NULL,
    FOREIGN KEY (transport_id) REFERENCES Transport(id)
);

-- Table des utilisateurs
CREATE TABLE Utilisateur (
    id SERIAL PRIMARY KEY,
    nom VARCHAR(32) NOT NULL,
    prenom VARCHAR(32) NOT NULL,
    email VARCHAR(128) NOT NULL UNIQUE,
    telephone CHAR(10),
    adresse TEXT,
    code_postal CHAR(5),
    commune VARCHAR(32)
);

-- Table des employés, héritant de Utilisateur
CREATE TABLE Employe (
    utilisateur_id INT PRIMARY KEY,
    login VARCHAR(20) NOT NULL UNIQUE,
    FOREIGN KEY (utilisateur_id) REFERENCES Utilisateur(id)
);

-- Table des contrats pour les employés
CREATE TABLE Contrat (
    id SERIAL PRIMARY KEY,
    employe_id INT NOT NULL,
    date_embauche DATE NOT NULL,
    date_depart DATE,
    service VARCHAR(32) NOT NULL,
    FOREIGN KEY (employe_id) REFERENCES Employe(utilisateur_id)
);

-- Table  trajets
CREATE TABLE Trajet (
    id SERIAL PRIMARY KEY,
    utilisateur_id INT NOT NULL,
    date_entree TIMESTAMP NOT NULL,
    station_entree_id INT NOT NULL,
    date_sortie TIMESTAMP,
    station_sortie_id INT,
    FOREIGN KEY (utilisateur_id) REFERENCES Utilisateur(id),
    FOREIGN KEY (station_entree_id) REFERENCES Station(id),
    FOREIGN KEY (station_sortie_id) REFERENCES Station(id)
);

-- Table forfaits
CREATE TABLE Forfait (
    code CHAR(5) PRIMARY KEY,
    nom VARCHAR(32) NOT NULL,
    prix_mois DECIMAL(6, 2) CHECK (prix_mois >= 0),
    duree INT CHECK (duree > 0),
    zone_min INT NOT NULL,
    zone_max INT NOT NULL,
    FOREIGN KEY (zone_min) REFERENCES ZoneTarifaire(numero),
    FOREIGN KEY (zone_max) REFERENCES ZoneTarifaire(numero)
);

-- Table abonnements
CREATE TABLE Abonnement (
    utilisateur_id INT,
    forfait_code CHAR(5),
    date_debut DATE NOT NULL,
    statut VARCHAR(10) CHECK (statut IN ('Registered', 'Pending', 'Incomplete')),
    PRIMARY KEY (utilisateur_id, forfait_code),
    FOREIGN KEY (utilisateur_id) REFERENCES Utilisateur(id),
    FOREIGN KEY (forfait_code) REFERENCES Forfait(code)
);