CREATE OR REPLACE FUNCTION find_arrival_station(IN in_route_train_id INT, OUT INT) AS
$find$
SELECT routes_stations.station_id
FROM routes
         INNER JOIN routes_stations ON routes.route_id = routes_stations.route_id AND
                                       routes_stations.departure_time IS NULL
         INNER JOIN routes_trains ON routes.route_id = routes_trains.route_id AND
                                     routes_trains.route_train_id = in_route_train_id;
$find$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION find_departure_station(IN in_route_train_id INT, OUT INT) AS
$find$
SELECT routes_stations.station_id
FROM routes
         INNER JOIN routes_stations ON routes.route_id = routes_stations.route_id AND
                                       routes_stations.arrival_time IS NULL
         INNER JOIN routes_trains ON routes.route_id = routes_trains.route_id AND
                                     routes_trains.route_train_id = in_route_train_id;
$find$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION find_passenger_account(IN in_passenger_id INT, OUT INT) AS
$find$
SELECT passengers.account_id
FROM tickets
         INNER JOIN passengers ON passengers.passenger_id = in_passenger_id;
$find$ LANGUAGE sql;

CREATE PROCEDURE update_score(IN in_account_id INT, IN new_accrued NUMERIC(5, 2), IN new_paid NUMERIC(5, 2)) AS
$body$
BEGIN
    UPDATE accounts
    SET bonus_score = bonus_score + new_accrued - new_paid
    WHERE account_id = in_account_id;
END;
$body$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION find_route_station_id(IN in_station_id INT, IN in_route_id INT, OUT INT) AS
$$
SELECT routes_stations.route_station_id
FROM routes_stations
WHERE routes_stations.station_id = in_station_id
  AND routes_stations.route_id = in_route_id
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION count_distance(IN in_departure_station_id INT, IN in_arrival_station_id INT,
                                          IN in_route_id INT, OUT NUMERIC(6, 1)) AS
$body$
SELECT SUM(routes_stations.distance) AS distance
FROM routes_stations
WHERE routes_stations.route_id = in_route_id
  AND routes_stations.route_station_id BETWEEN
    find_route_station_id(in_departure_station_id, in_route_id) + 1 AND
    find_route_station_id(in_arrival_station_id, in_route_id);
$body$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION find_ticket_price(IN in_route_train_id INT, IN in_wagon_in_train_id INT,
                                             OUT NUMERIC(7, 2)) AS
$body$
SELECT count_distance(
               find_departure_station(routes_trains.route_train_id),
               find_arrival_station(routes_trains.route_train_id),
               routes_trains.route_id
           ) * wagon_models.price_k
FROM trains
         INNER JOIN routes_trains ON routes_trains.train_id = trains.train_id AND
                                     routes_trains.route_train_id = in_route_train_id
         INNER JOIN wagons_in_train ON wagons_in_train.train_id = trains.train_id AND
                                       wagons_in_train.wagon_in_train_id = in_wagon_in_train_id
         INNER JOIN wagons ON wagons.wagon_id = wagons_in_train.wagon_id
         INNER JOIN wagon_models ON wagon_models.wagon_model_id = wagons.wagon_model_id;
$body$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION set_price_bonus() RETURNS TRIGGER AS
$bonus$
BEGIN
    IF (find_ticket_price(new.route_train_id, new.wagon_in_train_id)) IS NULL
    THEN
        RAISE EXCEPTION 'price is NULL';
    END IF;
    new.price := find_ticket_price(new.route_train_id, new.wagon_in_train_id);
    IF (find_passenger_account(new.passenger_id) IS NOT NULL)
    THEN
        new.accrued_bonuses := new.price / 100;
        new.paid_bonuses := (
            SELECT accounts.bonus_score
            FROM accounts
            WHERE account_id = find_passenger_account(new.passenger_id));
        CALL update_score(
                find_passenger_account(new.passenger_id),
                new.accrued_bonuses,
                new.paid_bonuses);
    END IF;
    RETURN new;
END
$bonus$ LANGUAGE plpgsql;

CREATE TRIGGER bonus
    BEFORE INSERT
    ON tickets
    FOR EACH ROW
EXECUTE PROCEDURE set_price_bonus();


/*
DROP FUNCTION print_passenger_tickets(int);

SELECT * FROM print_passenger_tickets(1000260254);

CREATE FUNCTION find_free(table_name varchar(60)) RETURNS int AS $$

SELECT locomotives.locomotive_id FROM locomotives
LEFT JOIN trains ON locomotives.locomotive_id = trains.locomotive_id
WHERE trains.locomotive_id IS NULL;
    $$ LANGUAGE sql;

CREATE PROCEDURE find_free_locomotives()
LANGUAGE sql
AS $$
START TRANSACTION

COMMIT
$$;

call find_free_locomotives();

CREATE TRIGGER delete_locomotive
    BEFORE DELETE ON locomotives
    FOR EACH ROW
   EXECUTE PROCEDURE find_free_locomotives();
*/
/*
drop function find_passenger_account(int);
drop function set_bonus() Cascade;
drop procedure update_score( int,  numeric,  numeric);


TABLE(
    passenger_last_name varchar(255),
    passenger_first_name varchar(255),
    departure_station varchar(255),
    departure_country varchar(255),
    departure_local_time smallint,
    departure_platform smallint,
    departure_time time,
    arrival_station varchar(255),
    arrival_country varchar(255),
    arrival_local_time smallint,
    arrival_platform smallint,
    arrival_time time,
    route_date date,
    train_num int,
    wagon_train_num smallint,
    place_num smallint,
    ticket_price numeric(7,2),
    total_price numeric(8,2),
    paid_bonuses numeric(5,2),
    accrued_bonuses numeric (5,2)
    )
-- CREATE TRIGGER
drop function show_routes( varchar(255),  varchar(255),  date,  time);
*/

/*
drop function find_departure_station(int);
drop function find_arrival_station(int);

DROP FUNCTION print_passenger_tickets(int);

 */