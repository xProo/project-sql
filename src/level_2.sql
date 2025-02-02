--Fonctions d'insertion
--add_person

CREATE OR REPLACE FUNCTION add_person(
    firstname VARCHAR(32),
    lastname VARCHAR(32),
    email VARCHAR(128),
    phone VARCHAR(10),
    address TEXT,
    town VARCHAR(32),
    zipcode VARCHAR(5)
)
RETURNS BOOLEAN AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM Utilisateur WHERE Utilisateur.email = $3) THEN
        RETURN FALSE;
    ELSE
        INSERT INTO Utilisateur (nom, prenom, email, telephone, adresse, commune, code_postal)
        VALUES (lastname, firstname, email, phone, address, town, zipcode);
        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql;


--add_offer

CREATE OR REPLACE FUNCTION add_offer(
    code VARCHAR(5),
    name VARCHAR(32),
    price FLOAT,
    nb_month INT,
    zone_from INT,
    zone_to INT
)
RETURNS BOOLEAN AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ZoneTarifaire WHERE numero = zone_from) THEN
        RETURN FALSE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM ZoneTarifaire WHERE numero = zone_to) THEN
        RETURN FALSE;
    END IF;
    
    IF zone_from > zone_to THEN
        RETURN FALSE;
    END IF;

    INSERT INTO Forfait (code, nom, prix_mois, duree, zone_min, zone_max)
    VALUES (code, name, price, nb_month, zone_from, zone_to);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;



--add subscription

-- J'avais une erreur bizarre que j'ai eu du mal à résoudre '' utilisateur_id is ambigous'' et pareil pour l'utilisateur donc j'ai du faire plein de changement  ''

CREATE OR REPLACE FUNCTION add_subscription(
    num INT,
    email VARCHAR(128),
    code VARCHAR(5),
    date_sub DATE
)
RETURNS BOOLEAN AS $$
DECLARE
    user_id INT;
    existing_subscription_count INT;
BEGIN
    SELECT id INTO user_id
    FROM Utilisateur
    WHERE Utilisateur.email = $2;

    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT COUNT(*) INTO existing_subscription_count
    FROM Abonnement
    WHERE Abonnement.utilisateur_id = user_id
    AND (statut IN ('Pending', 'Incomplete'));

    IF existing_subscription_count > 0 THEN
        RETURN FALSE;
    END IF;

    IF EXISTS (SELECT 1 FROM Abonnement WHERE Abonnement.utilisateur_id = user_id AND forfait_code = $3) THEN
        RETURN FALSE;
    END IF;

    INSERT INTO Abonnement (utilisateur_id, forfait_code, date_debut, statut)
    VALUES (user_id, $3, $4, 'Incomplete');

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;



--Fonctions de mise à jour
--update_status


CREATE OR REPLACE FUNCTION update_status(
    num INT,
    new_status VARCHAR(32)
)
RETURNS BOOLEAN AS $$
DECLARE
    existing_status VARCHAR(32);
BEGIN
    SELECT statut INTO existing_status
    FROM Abonnement
    WHERE num = $1;

    IF existing_status IS NULL THEN
        RETURN FALSE;  -- L'abonnement n'existe pas
    END IF;

    IF existing_status = new_status THEN
        RETURN TRUE;  -- Le statut est déjà celui demandé
    END IF;

    UPDATE Abonnement
    SET statut = $2
    WHERE num = $1;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;




--update_offer_price

CREATE OR REPLACE FUNCTION update_offer_price(
    offer_code VARCHAR(5),
    price FLOAT
)
RETURNS BOOLEAN AS $$
BEGIN
    
    IF price <= 0 THEN
        RETURN FALSE;
    END IF;

   
    IF NOT EXISTS (SELECT 1 FROM Forfait WHERE code = offer_code) THEN
        RETURN FALSE;
    END IF;

  
    UPDATE Forfait
    SET prix_mois = price
    WHERE code = offer_code;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


--les vues


--vue view_user_small_name 

CREATE OR REPLACE VIEW view_user_small_name AS
SELECT nom, prenom
FROM Utilisateur
WHERE LENGTH(nom) <= 4
ORDER BY nom ASC, prenom ASC;



--vue view_user_subscription


CREATE OR REPLACE VIEW view_user_subscription AS
SELECT
    CONCAT(U.prenom, ' ', U.nom) AS "user",
    F.nom AS "offer"
FROM
    Utilisateur U
JOIN
    Abonnement A ON U.id = A.utilisateur_id
JOIN
    Forfait F ON A.forfait_code = F.code
ORDER BY
    "user" ASC, "offer" ASC;


--vue view_unloved_offers

CREATE OR REPLACE VIEW view_unloved_offers AS
SELECT
    F.nom AS "offer"
FROM
    Forfait F
LEFT JOIN
    Abonnement A ON F.code = A.forfait_code
WHERE
    A.utilisateur_id IS NULL
ORDER BY
    F.nom ASC;


-- vue view_pending_subscriptions

--j'ai pas mal de conflit avec la table utilisateur, mais comme c'est relier a abonnement je peux pas supprimer les dérniers utilisateurs de la table utilisateur
    CREATE OR REPLACE VIEW view_pending_subscriptions AS
SELECT
    U.nom AS "lastname",
    U.prenom AS "firstname"
FROM
    Utilisateur U
JOIN
    Abonnement A ON U.id = A.utilisateur_id
WHERE
    A.statut = 'Pending'
ORDER BY
    A.date_debut ASC;


-- vue view_old_subscription
CREATE OR REPLACE VIEW view_old_subscription AS
SELECT
    U.nom || ' ' || U.prenom AS "user",
    F.nom AS "offer",
    A.statut AS "status"
FROM
    Abonnement A
JOIN
    Utilisateur U ON A.utilisateur_id = U.id
JOIN
    Forfait F ON A.forfait_code = F.code
WHERE
    A.statut IN ('Incomplete', 'Pending', 'Active')  -- Inclure d'autres statuts ici
    AND A.date_debut <= CURRENT_DATE - INTERVAL '1 year'
ORDER BY
    "user", "offer";


--Procédures
--list_station_near_user

CREATE OR REPLACE FUNCTION list_station_near_user(user_email VARCHAR(128))
RETURNS TABLE(station_name VARCHAR(64)) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT LOWER(s.nom)::VARCHAR(64) AS station_name
    FROM Station s
    JOIN Utilisateur u ON s.commune = u.commune
    WHERE u.email = user_email
    ORDER BY station_name;
END;
$$ LANGUAGE plpgsql;

--list_subscribers
CREATE OR REPLACE FUNCTION list_subscribers(code_offer VARCHAR(5))
RETURNS SETOF VARCHAR(65) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT CONCAT(u.prenom, ' ', u.nom)::VARCHAR(65) AS full_name
    FROM utilisateur u
    JOIN abonnement a ON u.id = a.utilisateur_id
    JOIN forfait f ON a.forfait_code = f.code
    WHERE f.code = code_offer
    ORDER BY full_name;
END;
$$ LANGUAGE plpgsql;


--list_subscription
CREATE OR REPLACE FUNCTION list_subscription(user_email VARCHAR(128), subscription_date DATE)
RETURNS SETOF VARCHAR(5) AS $$
BEGIN
    RETURN QUERY
    SELECT a.forfait_code::VARCHAR(5)
    FROM abonnement a
    JOIN utilisateur u ON a.utilisateur_id = u.id
    WHERE u.email = user_email
      AND a.statut = 'Registered'
      AND a.date_debut = subscription_date
    GROUP BY a.forfait_code 
    ORDER BY a.forfait_code;
END;
$$ LANGUAGE plpgsql;


