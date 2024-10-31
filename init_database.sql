
-- Table des moyens de transport
CREATE TABLE Transport (
    id CHAR(3) PRIMARY KEY,
    nom_ligne VARCHAR(32) NOT NULL,
    capacite_max INT CHECK (capacite_max > 0),
    duree_trajet INT CHECK (duree_trajet > 0)
);

