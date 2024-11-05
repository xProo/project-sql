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
