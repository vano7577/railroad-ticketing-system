CREATE OR REPLACE FUNCTION discount_k(IN in_ticket_id int, OUT out_discount_k numeric(5, 4)) AS
$$
DECLARE
    sum_dis numeric(5, 2) ;
BEGIN
    sum_dis := (
        SELECT SUM(percent)
        FROM discounts_tickets
                 INNER JOIN discounts ON discounts_tickets.discount_id = discounts.discount_id
        WHERE discounts_tickets.ticket_id = in_ticket_id);
    IF (sum_dis IS NOT NULL)
    THEN
        out_discount_k := 1 - sum_dis / 100;
    ELSE
        out_discount_k := 1;
    END IF;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE FUNCTION find_total_price(IN in_ticket_id int, OUT out_total_price numeric(8, 2)) AS
$$
DECLARE
    ticket_price numeric(7, 2);
    sum_ser      numeric(7, 2) DEFAULT 0;
BEGIN
    ticket_price := (SELECT price FROM tickets WHERE ticket_id = in_ticket_id);
    sum_ser := (
        SELECT SUM(services.price * services_tickets.quantity)
        FROM services_tickets
                 INNER JOIN services ON services.service_id = services_tickets.service_id
        WHERE services_tickets.ticket_id = in_ticket_id);
    IF sum_ser IS NOT NULL
    THEN
        out_total_price := ticket_price * discount_k(in_ticket_id) + sum_ser;
    ELSE
        out_total_price := ticket_price * discount_k(in_ticket_id);
    END IF;
END;
$$ LANGUAGE PLPGSQL;

CREATE OR REPLACE VIEW printed_tickets AS
SELECT tickets.ticket_num,
       passengers.passenger_last_name,
       passengers.passenger_first_name,
       departure_stations.station_name          AS departure_station,
       departure_stations.country               AS departure_country,
       departure_stations.local_time            AS departure_local_time,
       departure_routes_stations.platform       AS departure_platform,
       departure_routes_stations.departure_time AS departure_time,
       arrival_stations.station_name            AS arrival_station,
       arrival_stations.country                 AS arrival_country,
       arrival_stations.local_time              AS arrival_local_time,
       arrival_routes_stations.platform         AS arrival_platform,
       arrival_routes_stations.arrival_time     AS arrival_time,
       routes_trains.route_date,
       trains.train_num,
       wagons_in_train.wagon_train_num,
       tickets.place_num,
       tickets.price,
       find_total_price(tickets.ticket_id),
       tickets.paid_bonuses,
       tickets.accrued_bonuses
FROM tickets
         INNER JOIN passengers
                    ON tickets.passenger_id = passengers.passenger_id
         INNER JOIN routes_trains
                    ON tickets.route_train_id = routes_trains.route_train_id
         INNER JOIN wagons_in_train
                    ON tickets.wagon_in_train_id = wagons_in_train.wagon_in_train_id
         INNER JOIN trains
                    ON wagons_in_train.train_id = trains.train_id
         INNER JOIN stations AS arrival_stations
                    ON tickets.arrival_station = arrival_stations.station_id OR
                       (tickets.arrival_station IS NULL AND
                        arrival_stations.station_id = find_arrival_station(tickets.route_train_id))
         INNER JOIN stations AS departure_stations
                    ON tickets.departure_station = departure_stations.station_id OR
                       (tickets.departure_station IS NULL AND
                        departure_stations.station_id = find_departure_station(tickets.route_train_id))
         INNER JOIN routes_stations AS departure_routes_stations
                    ON departure_stations.station_id = departure_routes_stations.station_id
                        AND
                       routes_trains.route_id = departure_routes_stations.route_id
         INNER JOIN routes_stations AS arrival_routes_stations
                    ON arrival_stations.station_id = arrival_routes_stations.station_id
                        AND
                       routes_trains.route_id = arrival_routes_stations.route_id;

CREATE OR REPLACE FUNCTION print_passenger_tickets(in_ticket_num int)
    RETURNS printed_tickets
AS
$print$
SELECT *
FROM printed_tickets
WHERE printed_tickets.ticket_num = in_ticket_num;
$print$ LANGUAGE SQL;

SELECT *
FROM find_total_price(1);

SELECT locomotives.locomotive_id
FROM locomotives
         LEFT JOIN trains ON locomotives.locomotive_id = trains.locomotive_id AND trains.locomotive_id IS NULL;

CREATE FUNCTION spent_time_func(IN departure_time time, IN arrival_time time, OUT spent time) AS
$BODY$
BEGIN
    IF arrival_time >= departure_time THEN
        spent := arrival_time - departure_time;
    ELSE
        spent := arrival_time + '24:00' - departure_time;
    END IF;
    RETURN;
END
$BODY$ LANGUAGE plpgsql;

CREATE VIEW schedule AS
SELECT trains.train_num,
       departure_stations.station_name                                                                  AS departure_stations,
       arrival_stations.station_name                                                                    AS arrival_stations,
       routes_trains.route_date,
       departure_routes_stations.departure_time,
       arrival_routes_stations.arrival_time,
       spent_time_func(departure_routes_stations.departure_time, arrival_routes_stations.arrival_time)  AS spent_time,
       wagon_types.wagon_type_name,
       (wagon_types.seat_quantity * COUNT(wagons_in_train.train_id) - COUNT(tickets.wagon_in_train_id)) AS free_places
FROM routes
         INNER JOIN routes_stations AS departure_routes_stations ON routes.route_id = departure_routes_stations.route_id
         INNER JOIN routes_stations AS arrival_routes_stations ON routes.route_id = arrival_routes_stations.route_id AND
                                                                  arrival_routes_stations.route_station_id >=
                                                                  departure_routes_stations.route_station_id
         INNER JOIN stations AS departure_stations
                    ON departure_stations.station_id = departure_routes_stations.station_id
         INNER JOIN stations AS arrival_stations ON arrival_stations.station_id = arrival_routes_stations.station_id
         INNER JOIN routes_trains ON routes.route_id = routes_trains.route_id
         INNER JOIN trains ON routes_trains.train_id = trains.train_id
         INNER JOIN wagons_in_train ON trains.train_id = wagons_in_train.train_id
         INNER JOIN wagons ON wagons_in_train.wagon_id = wagons.wagon_id
         INNER JOIN wagon_models ON wagons.wagon_model_id = wagon_models.wagon_model_id
         INNER JOIN wagon_types ON wagon_models.wagon_type_id = wagon_types.wagon_type_id
         LEFT OUTER JOIN tickets ON wagons_in_train.wagon_in_train_id = tickets.wagon_in_train_id AND
                                    routes_trains.route_train_id = tickets.route_train_id AND
                                    (tickets.departure_station IS NULL OR
                                     tickets.departure_station <= departure_stations.station_id) AND
                                    (tickets.arrival_station IS NULL OR
                                     tickets.arrival_station >= arrival_stations.station_id)

GROUP BY trains.train_num,
         routes.route_num,
         departure_stations.station_name,
         arrival_stations.station_name,
         departure_routes_stations.departure_time,
         arrival_routes_stations.arrival_time,
         routes_trains.route_date,
         wagon_types.wagon_type_name,
         wagon_types.seat_quantity;
SELECT *
FROM schedule;

CREATE FUNCTION show_routes(in_departure_station varchar(255), in_arrival_station varchar(255), in_date date,
                            in_departure_time time)
    RETURNS TABLE
            (
                train_num         int,
                departure_station varchar(255),
                arrival_station   varchar(255),
                route_date        date,
                departure_time    time,
                arrival_time      time,
                spent_time        time,
                wagon_type        varchar(60),
                free_places       bigint
            )
AS
$show$
SELECT trains.train_num,
       departure_stations.station_name,
       arrival_stations.station_name,
       routes_trains.route_date,
       departure_routes_stations.departure_time,
       arrival_routes_stations.arrival_time,
       spent_time_func(departure_routes_stations.departure_time, arrival_routes_stations.arrival_time)  AS spent_time,
       wagon_types.wagon_type_name,
       (wagon_types.seat_quantity * COUNT(wagons_in_train.train_id) - COUNT(tickets.wagon_in_train_id)) AS free_places
FROM routes
         INNER JOIN routes_stations AS departure_routes_stations ON routes.route_id = departure_routes_stations.route_id
         INNER JOIN routes_stations AS arrival_routes_stations ON routes.route_id = arrival_routes_stations.route_id AND
                                                                  arrival_routes_stations.route_station_id >=
                                                                  departure_routes_stations.route_station_id
         INNER JOIN stations AS departure_stations
                    ON departure_stations.station_id = departure_routes_stations.station_id AND
                       departure_stations.station_name = in_departure_station AND
                       (in_departure_time IS NULL OR
                        departure_routes_stations.departure_time >= in_departure_time)
         INNER JOIN stations AS arrival_stations ON arrival_stations.station_id = arrival_routes_stations.station_id AND
                                                    arrival_stations.station_name = in_arrival_station
         INNER JOIN routes_trains ON routes.route_id = routes_trains.route_id AND
                                     routes_trains.route_date = in_date AND
                                     routes_trains.route_status
         INNER JOIN trains ON routes_trains.train_id = trains.train_id
         INNER JOIN wagons_in_train ON trains.train_id = wagons_in_train.train_id
         INNER JOIN wagons ON wagons_in_train.wagon_id = wagons.wagon_id
         INNER JOIN wagon_models ON wagons.wagon_model_id = wagon_models.wagon_model_id
         INNER JOIN wagon_types ON wagon_models.wagon_type_id = wagon_types.wagon_type_id
         LEFT OUTER JOIN tickets ON wagons_in_train.wagon_in_train_id = tickets.wagon_in_train_id AND
                                    routes_trains.route_train_id = tickets.route_train_id AND
                                    (tickets.departure_station IS NULL OR
                                     tickets.departure_station <= departure_stations.station_id) AND
                                    (tickets.arrival_station IS NULL OR
                                     tickets.arrival_station >= arrival_stations.station_id)

GROUP BY trains.train_num,
         routes.route_num,
         departure_stations.station_name,
         arrival_stations.station_name,
         departure_routes_stations.departure_time,
         arrival_routes_stations.arrival_time,
         routes_trains.route_date,
         wagon_types.wagon_type_name,
         wagon_types.seat_quantity;
$show$ LANGUAGE SQL;
/*
SELECT * from print_passenger_tickets(1000260258);
select  find_departure_station(1000260258);
SELECT * from show_routes('Киев-Пассажирский','Львов', '2020-11-21',NULL);

 */
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO railway_admin;