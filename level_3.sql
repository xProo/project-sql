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
