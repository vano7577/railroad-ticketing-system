# Design Document

## Context and Scope

The main purpose of the system is to provide railway passengers with participation in the loyalty program when purchasing tickets.

At the moment, there is no loyalty program for passengers in Ukraine. There is a need to implement it to increase ticket sales. Passengers will prefer rail transportation, as opposed to air, auto and shipping. A bonus program was taken as a loyalty program.

## Goals and non-goals

### Goals

* introduce into the system the participation of passengers in discount programs;
* ensure the accrual of bonuses for the purchase of a ticket;
* provide automatic write-off of existing bonuses when buying a ticket;

### Non-goals

* provide the passenger with special offers in honor of his birthday;

## The actual design

### APIs

For the user, the system must provide endpoints for:
* authorization;
* buying a ticket;
* viewing information about the ticket;
* purchased tickets;

For the railway administration, the system must provide endpoints for:
* view information about sold tickets on certain routes
* drawing up and changing transportation routes;
* changes in the types of discounts;

### Data storage

The system must store information about passengers, their accounts, tickets, routes, train trains, discounts, and services.

All information will be stored in a relational database.

## Alternatives considered

instead of a relational database, a graph was considered, but due to the insignificant number of links, this architecture will be less productive than a relational one.

As alternatives, various loyalty programs were considered: free tickets, the opportunity to win a prize, etc. According to surveys, passengers like discount and savings programs more, so it was decided to opt for a bonus loyalty program.

## Cross-cutting concerns

To ensure the security of the system, you will need:
* reliable safety of passwords of passengers;
* limited access to changes to data (tables), to which only the administration of the railway has the right;
* competent distribution of access roles and their rights to the database;