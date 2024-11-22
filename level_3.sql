--fonction add_service
CREATE OR REPLACE FUNCTION add_service(name VARCHAR(32), discount INT)
RETURNS BOOLEAN AS $$
BEGIN
   
    IF EXISTS (SELECT 1 FROM service WHERE service_name = name) THEN
        RAISE EXCEPTION 'Le nom du service % existe déjà.', name;
    END IF;
  
    IF discount < 0 OR discount > 100 THEN
        RAISE EXCEPTION 'La réduction doit être entre 0 et 100. Réduction fournie : %', discount;
    END IF;  
 
    INSERT INTO service (service_name, discount)
    VALUES (name, discount);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


--add_contract mais pas reussi donc bon, ca marche pas, j'ai un souci dans mes appelations services car je n'arrive pas a resoudre
CREATE OR REPLACE FUNCTION add_contract(
    login VARCHAR(20),
    email VARCHAR(128),
    date_beginning DATE,
    service_name VARCHAR(32)
)
RETURNS BOOLEAN AS $$
DECLARE
    last_end_date DATE;
    service_exists BOOLEAN;
BEGIN

    SELECT EXISTS (SELECT 1 FROM service WHERE service_name = $4) INTO service_exists;
    IF NOT service_exists THEN
        RAISE EXCEPTION 'Le service % n''existe pas.', service_name;
    END IF;

    
    SELECT MAX(date_fin) INTO last_end_date
    FROM contrat c
    JOIN utilisateur u ON c.utilisateur_id = u.id
    WHERE u.email = email;

    IF last_end_date IS NOT NULL AND date_beginning <= last_end_date THEN
        RAISE EXCEPTION 'La date de début du nouveau contrat doit être postérieure à la date de fin du dernier contrat.';
    END IF;

    -- Ajout du nouveau contrat
    INSERT INTO contrat (utilisateur_id, service_name, date_debut, login)
    SELECT u.id, service_name, date_beginning, login
    FROM utilisateur u
    WHERE u.email = email;
    

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


--end_contract


CREATE OR REPLACE FUNCTION end_contract(
    employe_id INT 
)
RETURNS BOOLEAN AS $$
DECLARE
    current_contract_id INT;
    contract_end_date DATE := CURRENT_DATE;  

    SELECT id INTO current_contract_id
    FROM contrat
    WHERE employe_id = employe_id
    AND date_fin IS NULL;

    IF current_contract_id IS NULL THEN
        RAISE EXCEPTION 'L''employé avec l''ID % n''a pas de contrat en cours.', employe_id;
    END IF;


    UPDATE contrat
    SET date_fin = contract_end_date
    WHERE id = current_contract_id;

 
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;


--update_service
CREATE OR REPLACE FUNCTION update_service(
    name VARCHAR(32),
    discount INT
)
RETURNS BOOLEAN AS $$
DECLARE
    service_exists BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM service WHERE service_name = name) INTO service_exists;

    IF NOT service_exists THEN
        RAISE EXCEPTION 'Le service % n''existe pas.', name;
    END IF;

    UPDATE service
    SET discount = $2
    WHERE service_name = $1;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

--les views
--view_employees

CREATE VIEW view_employees AS
SELECT
    e.login,
    e.email,
    s.service_name AS service
FROM
    employe e
JOIN
    service s ON e.service_id = s.service_id
ORDER BY
    e.login;




--view_nb_employees_per_service 
CREATE VIEW view_nb_employees_per_service AS
SELECT
    s.service_name AS service,                    
    COUNT(e.utilisateur_id) AS nb                
FROM
    service s
LEFT JOIN
    employe e ON s.service_id = e.service_id     
GROUP BY
    s.service_name                           
ORDER BY
    s.service_name;                              



--list_login_employee, j'ai tester avec cette date : SELECT * FROM list_login_employee('2024-11-22');

CREATE OR REPLACE FUNCTION list_login_employee(date_service DATE) 
RETURNS SETOF VARCHAR(20) AS
$$
BEGIN
    RETURN QUERY
    SELECT e.login
    FROM employe e
    JOIN affectation_service es ON e.utilisateur_id = es.utilisateur_id
    WHERE es.date_affectation <= date_service
    AND (es.date_fin IS NULL OR es.date_fin >= date_service)
    ORDER BY e.login;
END;
$$ LANGUAGE plpgsql;



--list_not_employee, pas reussi malheureusment
CREATE OR REPLACE FUNCTION list_not_employee(date_service DATE)
RETURNS TABLE(
    lastname VARCHAR(32),
    firstname VARCHAR(32),
    has_worked TEXT
) AS
$$
BEGIN
    RETURN QUERY
    SELECT 
        u.lastname, 
        u.firstname,
        CASE
            WHEN es.utilisateur_id IS NOT NULL THEN 'YES'
            ELSE 'NO'
        END AS has_worked
    FROM utilisateur u
    LEFT JOIN employe e ON u.utilisateur_id = e.utilisateur_id  
    LEFT JOIN affectation_service es ON u.utilisateur_id = es.utilisateur_id 
        AND es.date_affectation <= date_service
        AND (es.date_fin IS NULL OR es.date_fin >= date_service)
    WHERE e.utilisateur_id IS NULL  
    ORDER BY u.lastname, u.firstname; 
END;
$$ LANGUAGE plpgsql;




--list_subscription_history

--pas compris ni reussi celle la