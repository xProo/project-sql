
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