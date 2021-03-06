'use strict';

const { Client } = require('pg');

const client = new Client({
    user: 'railway_user',
    host: 'localhost',
    database: 'railway',
    password: 'pa$$w0rd',
    port: 5432,
});
client.connect();

function check_login_password (login, password){
    const VALUES = [login, password];
    const query1 = `
    SELECT account_id
    FROM accounts WHERE login= $1 AND password = $2;
    `;
    client.query(query1,VALUES, (err, res) => {
        if (err) {
            console.error(err);
            return;
        }
        if(!res.rows){console.log('can not find account')}else
        {
            console.table(res.rows)
            return res.rows 
        }
    });
}

function print_passenger_tickets(ticket_num){
    const VALUES = [ticket_num]
    const query1 = `
    SELECT * from print_passenger_tickets($1);
    `;
    client.query(query1,VALUES, (err, res) => {
        if (err) {
            console.error(err);
            return;
        }
        console.table(res.rows)
    });
}

function find_empty_places(route_train_id,wagon_type){
    const VALUES = [route_train_id,wagon_type]
    const query1 = `
    SELECT * from find_empty_places($1,$2);
    `;
    client.query(query1,VALUES, (err, res) => {
        if (err) {
            console.error(err);
            return;
        }
        console.table(res.rows)
    });
}

function insert_passenger_ticket(passenger_id, route_train_id, departure_station, arrival_station, ticket_num, place_num){
    const VALUES = [passenger_id, route_train_id, departure_station, arrival_station, ticket_num, place_num]
    const query1 = `
    SELECT * from insert_passenger_ticket($1,$2,$3,$4,$5,$6);
    `;
    client.query(query1,VALUES, (err, res) => {
        if (err) {
            console.error(err);
            return;
        }
        console.table(res.rows)
    });
}

function show_routes(in_departure_station, in_arrival_station, in_date, in_departure_time){
    const VALUES = [in_departure_station, in_arrival_station, in_date, in_departure_time]
    const query1 = `
    SELECT * from show_routes($1,$2,$3,$4);
    `;
    client.query(query1,VALUES, (err, res) => {
        if (err) {
            console.error(err);
            return;
        }
        console.table(res.rows)
    });
}
//show_routes('????????-????????????????????????','??????????', '2020-11-21',null)
console.table(check_login_password('petrov0405', 'password1'));
//check_login_password('user'+'\''+';select * from accounts;--','')
module.exports = {check_login_password, print_passenger_tickets};
