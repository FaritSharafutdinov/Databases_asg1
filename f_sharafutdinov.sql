CREATE INDEX idx_flights_join ON flights 
    (flight_id, aircraft_code, departure_airport, arrival_airport);

CREATE INDEX idx_tickets_passenger ON tickets 
    (passenger_name, passenger_id);

CREATE INDEX idx_flights_departure ON flights 
    (actual_departure);

CREATE INDEX idx_flights_route ON flights 
    (departure_airport, arrival_airport, scheduled_departure, status);

CREATE INDEX idx_ticket_flights_fare ON ticket_flights 
    (fare_conditions, flight_id);

CREATE INDEX idx_flights_aircraft ON flights 
    (aircraft_code, actual_arrival);
