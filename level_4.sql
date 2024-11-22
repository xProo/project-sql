
--add_journey j'ai essayé de mettre la logique mais ca marche pas correctement 
CREATE OR REPLACE FUNCTION add_journey(
    email VARCHAR(128),  
    time_start TIMESTAMP,
    time_end TIMESTAMP,
    station_start INT,
    station_end INT
)
RETURNS BOOLEAN AS
$$
DECLARE
    user_id INT;
BEGIN

    SELECT id INTO user_id
    FROM utilisateur
    WHERE utilisateur.email = email;  

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Utilisateur avec cet email non trouvé';
    END IF;

   
    IF EXISTS (
        SELECT 1
        FROM trajet
        WHERE utilisateur_id = user_id
        AND (
            (time_start < time_end AND time_end > time_start)
            OR (time_start = time_end)
        )
    ) THEN
        RAISE EXCEPTION 'Un trajet pour cet utilisateur chevauche les horaires';
    END IF;

 
    IF time_end - time_start > INTERVAL '24 hours' THEN
        RAISE EXCEPTION 'Le trajet ne peut pas durer plus de 24 heures';
    END IF;


    INSERT INTO trajet (utilisateur_id, time_start, time_end, station_start, station_end)
    VALUES (user_id, time_start, time_end, station_start, station_end);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


--quand je fais ca j'ai beaucoup d'erreur que je n'arrive pas a corriger
SELECT add_journey('maximo@example.com', 
                   '2024-11-22 10:00:00'::timestamp,
                   '2024-11-22 12:00:00'::timestamp, 
                   1, 2);


--add_bill, j'ai fais ce que j'ai pu :D

CREATE OR REPLACE FUNCTION add_bill(
    p_email VARCHAR(128),
    p_year INT,
    p_month INT
)
RETURNS BOOLEAN AS
$$
DECLARE
    user_id INT;
    total_amount DECIMAL(10, 2) := 0;
    trajet_amount DECIMAL(10, 2);
    abonnement_amount DECIMAL(10, 2);
    reduction DECIMAL(10, 2) := 0;
BEGIN
    
    SELECT id INTO user_id
    FROM utilisateur
    WHERE email = p_email;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Utilisateur avec cet email non trouvé';
    END IF;


    IF (p_year = EXTRACT(YEAR FROM CURRENT_DATE) AND p_month >= EXTRACT(MONTH FROM CURRENT_DATE)) OR
       (p_year > EXTRACT(YEAR FROM CURRENT_DATE)) THEN
        RAISE EXCEPTION 'Le mois et l\'année doivent être terminés';
    END IF;

    -- Vérifier s'il existe déjà une facture pour cet utilisateur, mois et année
    IF EXISTS (
        SELECT 1
        FROM facture
        WHERE utilisateur_id = user_id
        AND EXTRACT(YEAR FROM date_facture) = p_year
        AND EXTRACT(MONTH FROM date_facture) = p_month
    ) THEN
        RAISE EXCEPTION 'Facture déjà existante pour ce mois et cette année';
    END IF;

    SELECT SUM(prix) INTO trajet_amount
    FROM trajet
    WHERE utilisateur_id = user_id
    AND EXTRACT(YEAR FROM time_start) = p_year
    AND EXTRACT(MONTH FROM time_start) = p_month;

de

    INSERT INTO facture (utilisateur_id, date_facture, montant)
    VALUES (user_id, TO_DATE(CONCAT(p_year, '-', p_month, '-01'), 'YYYY-MM-DD'), total_amount);

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

--Pour le reste des fonctions j'ai trop galerer donc j'ai décider de pas les mettres, je vais quand meme tenter de faire les vues mais bon, juste pour le code mais ca ne marchera pas  :/

--view_all_bills
CREATE VIEW view_all_bills AS
SELECT 
    u.nom AS lastname,
    u.prenom AS firstname,
    f.bill_number,
    f.bill_amount
FROM 
    utilisateur u
JOIN 
    facture f ON u.id = f.utilisateur_id
ORDER BY 
    f.bill_number;

--view_bill_per_month
 CREATE VIEW view_bill_per_month AS
SELECT 
    EXTRACT(YEAR FROM f.bill_date) AS year,
    EXTRACT(MONTH FROM f.bill_date) AS month,
    COUNT(f.bill_number) AS bills,
    SUM(f.bill_amount) AS total
FROM 
    facture f
GROUP BY 
    EXTRACT(YEAR FROM f.bill_date), EXTRACT(MONTH FROM f.bill_date)
HAVING 
    COUNT(f.bill_number) > 0
ORDER BY 
    year, month;
   
--view_average_entries_station
CREATE VIEW view_average_entries_station AS
SELECT 
    s.type AS type,
    s.station_name AS station,
    ROUND(AVG(e.entries_per_day), 2) AS entries
FROM 
    station s
JOIN 
    entry e ON s.station_id = e.station_id
WHERE 
    e.entries_per_day > 0
GROUP BY 
    s.type, s.station_name
ORDER BY 
    s.type, s.station_name;


--view_current_non_paid_bills
CREATE VIEW view_current_non_paid_bills AS
SELECT 
    u.lastname AS lastname,
    u.firstname AS firstname,
    b.bill_number AS bill_number,
    b.bill_amount AS bill_amount
FROM 
    utilisateur u
JOIN 
    facture b ON u.id = b.utilisateur_id
WHERE 
    b.paid = FALSE
ORDER BY 
    u.lastname, u.firstname, b.bill_number;
