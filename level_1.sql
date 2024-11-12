--add_transport_type

-- Fonction pour ajouter un nouveau moyen de transport
CREATE OR REPLACE FUNCTION add_transport_type(
    code VARCHAR(3),
    name VARCHAR(32),
    capacity INT,
    avg_interval INT
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Vérifier que la capacité et l'intervalle moyen sont supérieurs à 0
    IF capacity <= 0 THEN
        RAISE EXCEPTION 'Capacity must be greater than 0';
    END IF;
    
    IF avg_interval <= 0 THEN
        RAISE EXCEPTION 'Average interval must be greater than 0';
    END IF;

    -- Insertion dans la table TransportType avec vérification des duplications
    INSERT INTO TransportType (code, name, capacity, avg_interval)
    VALUES (code, name, capacity, avg_interval)
    ON CONFLICT (code, name) DO NOTHING;  -- Empêche l'insertion de duplications

    -- Vérifier si l'insertion a réussi
    IF NOT FOUND THEN
        RETURN FALSE; -- Retourner FALSE si le moyen de transport existe déjà
    END IF;

    RETURN TRUE; -- Retourner TRUE si l'insertion a réussi
END;
$$ LANGUAGE plpgsql;



-- Fonction pour ajouter une nouvelle zone tarifaire
CREATE OR REPLACE FUNCTION add_zone(
    zone_name VARCHAR(32),
    zone_price FLOAT
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Vérifier que le prix est supérieur à 0.001
    IF zone_price < 0.001 THEN
        RAISE EXCEPTION 'Price must be greater than 0.001';
    END IF;

    -- Vérifier si une zone avec le même nom existe déjà
    IF EXISTS (SELECT 1 FROM ZoneTarifaire WHERE nom = zone_name) THEN
        RETURN FALSE; -- Retourner FALSE si la zone existe déjà
    END IF;

    -- Insérer la nouvelle zone
    INSERT INTO ZoneTarifaire (nom, prix)
    VALUES (zone_name, zone_price);

    RETURN TRUE; -- Retourner TRUE si l'insertion a réussi
END;
$$ LANGUAGE plpgsql;




--ajouter station function

CREATE OR REPLACE FUNCTION add_station(
    station_id INT,
    station_name VARCHAR(64),
    station_town VARCHAR(32),
    zone_num INT,
    transport_type VARCHAR(3)
) RETURNS BOOLEAN AS $$
DECLARE
    zone_exists BOOLEAN;
    type_exists BOOLEAN;
BEGIN
    -- Vérifie si la zone existe
    SELECT EXISTS(SELECT 1 FROM ZoneTarifaire WHERE numero = zone_num) INTO zone_exists;
    IF NOT zone_exists THEN
        RAISE EXCEPTION 'Zone % does not exist', zone_num;
    END IF;

    -- Vérifie si le type de transport existe
    SELECT EXISTS(SELECT 1 FROM TransportType WHERE code = transport_type) INTO type_exists;
    IF NOT type_exists THEN
        RAISE EXCEPTION 'Transport type % does not exist', transport_type;
    END IF;

    -- Vérifie les doublons
    IF EXISTS(SELECT 1 FROM Station WHERE id = station_id) THEN
        RETURN FALSE; -- Station déjà existante
    END IF;

    -- Ajoute la station
    INSERT INTO Station (id, nom, commune, zone_numero) 
    VALUES (station_id, station_name, station_town, zone_num);

    RETURN TRUE; -- Ajout réussi
END;
$$ LANGUAGE plpgsql;



--add_ligne fonction