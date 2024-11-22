--add_transport_type

-- Fonction pour nouveau moyen de transport
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



--add_line fonction

CREATE OR REPLACE FUNCTION add_line(code VARCHAR(3), type VARCHAR(3)) 
RETURNS BOOLEAN AS $$
DECLARE
    type_exists BOOLEAN;
BEGIN
    -- Vérifie si le type existe dans la table des types de ligne
    SELECT EXISTS (SELECT 1 FROM TypeLigne WHERE type = $2) INTO type_exists;

    -- Si le type n'existe pas, retourne FALSE
    IF NOT type_exists THEN
        RETURN FALSE;
    END IF;

    -- Insère la ligne avec le code et le type spécifié s'il n'existe pas déjà un code identique
    INSERT INTO Ligne (code, type)
    VALUES ($1, $2)
    ON CONFLICT (code) DO NOTHING;

    -- Retourne TRUE si la ligne est ajoutée avec succès, sinon FALSE
    RETURN (FOUND);
END;
$$ LANGUAGE plpgsql;



--add_station_to_line fonction

CREATE OR REPLACE FUNCTION add_station_to_line(
    station INT, 
    line CHAR(3), 
    pos INT
) 
RETURNS BOOLEAN AS $$
DECLARE
    line_exists BOOLEAN;
    station_exists BOOLEAN;
    same_position_exists BOOLEAN;
    same_type BOOLEAN;
BEGIN
    -- Vérifier si la ligne existe
    SELECT EXISTS (SELECT 1 FROM Ligne WHERE code = line) INTO line_exists;
    IF NOT line_exists THEN
        RETURN FALSE;
    END IF;

    -- Vérifier si la station existe
    SELECT EXISTS (SELECT 1 FROM Station WHERE id = station) INTO station_exists;
    IF NOT station_exists THEN
        RETURN FALSE;
    END IF;

    -- Vérifier si la station est déjà associée à la ligne à cette position
    SELECT EXISTS (SELECT 1 FROM LigneStation WHERE ligne_code = line AND position = pos) INTO same_position_exists;
    IF same_position_exists THEN
        RETURN FALSE;
    END IF;

    -- Vérifier si le type de la station correspond à celui de la ligne
    DECLARE
        line_transport_type VARCHAR(3);
        station_zone_number INT;
    BEGIN
        -- Obtenir le type de transport de la ligne
        SELECT t.transport_id 
        INTO line_transport_type
        FROM Ligne l
        JOIN Transport t ON l.transport_id = t.id
        WHERE l.code = line;

        -- Obtenir la zone de la station
        SELECT s.zone_numero 
        INTO station_zone_number
        FROM Station s
        WHERE s.id = station;

      
        IF line_transport_type != station_zone_number THEN
            RETURN FALSE;
        END IF;
    END;

    -- Ajouter la station à la ligne à la position donnée
    INSERT INTO LigneStation (ligne_code, station_id, position)
    VALUES (line, station, pos);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;



--création vue  view_transport_50_300_users 

CREATE VIEW view_transport_50_300_users AS
SELECT nom_ligne AS transport
FROM Transport
WHERE capacite_max BETWEEN 50 AND 300
ORDER BY nom_ligne;

--création vue view_stations_from_paris
CREATE VIEW view_stations_from_paris AS
SELECT nom
FROM Station
WHERE commune ILIKE 'Paris'
ORDER BY nom;

--création vue view_stations_zones
CREATE VIEW view_stations_zones AS
SELECT 
    s.nom AS station,
    z.nom AS zone
FROM 
    Station s
JOIN 
    ZoneTarifaire z
ON 
    s.zone_numero = z.numero
ORDER BY 
    z.numero ASC, -- Tri par identifiant de la zone (croissant)
    s.nom ASC;    -- Puis tri par nom de la station



-- création vue  view_nb_station_type
CREATE VIEW view_nb_station_type AS
SELECT 
    t.nom_ligne AS type,
    COUNT(ls.station_id) AS stations
FROM 
    Transport t
JOIN 
    Ligne l ON t.id = l.transport_id
JOIN 
    LigneStation ls ON l.code = ls.ligne_code
GROUP BY 
    t.nom_ligne
ORDER BY 
    stations DESC,  -- Tri par nombre de station (décroissant)
    t.nom_ligne ASC;  -- Puis tri par nom du type d transport (alphabétique)


--création vue   view_line_duration 
DROP VIEW IF EXISTS view_line_duration; -- j'ai drop car j'avais un souci

CREATE VIEW view_line_duration AS
SELECT
    t.nom_ligne AS type,
    l.code AS line,
    t.duree_trajet AS minutes
FROM
    Ligne l
JOIN 
    Transport t ON l.transport_id = t.id
ORDER BY 
    t.nom_ligne, l.code;




--création vue  view_station_capacity
DROP VIEW IF EXISTS view_station_capacity;

CREATE VIEW view_station_capacity AS
SELECT
    s.nom AS station,
    t.capacite_max AS capacity
FROM
    Station s
JOIN
    LigneStation ls ON s.id = ls.station_id
JOIN
    Ligne l ON ls.ligne_code = l.code
JOIN
    Transport t ON l.transport_id = t.id
WHERE
    LOWER(s.nom) LIKE 'a%'  -- Filtrer les stations dont le nom commence par "A"
ORDER BY
    s.nom ASC, t.capacite_max ASC;  -- Trier par nom de station, puis par capacité



--Procédures :

-- procedure  list_station_in_line

CREATE OR REPLACE FUNCTION list_station_in_line(line_code VARCHAR(3))
RETURNS SETOF VARCHAR(64) AS $$
BEGIN
    RETURN QUERY
    SELECT s.nom
    FROM Station s
    JOIN LigneStation ls ON s.id = ls.station_id
    WHERE ls.ligne_code = line_code
    ORDER BY ls.position ASC;
END;
$$ LANGUAGE plpgsql;


-- procedure  list_types_in_zone

CREATE OR REPLACE FUNCTION list_types_in_zone(zone INT)
RETURNS SETOF VARCHAR(32) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT t.nom_ligne
    FROM Transport t
    JOIN Ligne l ON t.id = l.transport_id
    JOIN LigneStation ls ON l.code = ls.ligne_code
    JOIN Station s ON ls.station_id = s.id
    WHERE s.zone_numero = zone
    ORDER BY t.nom_ligne;
END;
$$ LANGUAGE plpgsql;



--procedure :  get_cost_travel


--je fais des CREATE OR REPLACE car je fais pleinnnnn de test avant

CREATE OR REPLACE FUNCTION get_cost_travel(station_start INT, station_end INT)
RETURNS FLOAT AS $$
DECLARE
    start_zone INT;
    end_zone INT;
    total_cost FLOAT := 0;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM Station WHERE id = station_start) OR
       NOT EXISTS (SELECT 1 FROM Station WHERE id = station_end) THEN
        RETURN 0;
    END IF;

    SELECT zone_numero INTO start_zone FROM Station WHERE id = station_start;
    SELECT zone_numero INTO end_zone FROM Station WHERE id = station_end;

    IF start_zone < end_zone THEN
        FOR i IN start_zone..end_zone LOOP
            total_cost := total_cost + i;
        END LOOP;
    ELSIF start_zone > end_zone THEN
        FOR i IN end_zone..start_zone LOOP
            total_cost := total_cost + i;
        END LOOP;
    ELSE
        total_cost := start_zone;
    END IF;

    RETURN total_cost;
END;
$$ LANGUAGE plpgsql;




