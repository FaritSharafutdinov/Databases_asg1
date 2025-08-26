SELECT p.passenger_id, p.passenger_name, fd.flight_no, fd.scheduled_departure, fd.scheduled_arrival, da.airport_name AS dep_airport, aa.airport_name AS arr_airport, a.model, fs.seat_no, li.next_flight_no, li.layover_duration
FROM
  (SELECT ticket_no, passenger_id, passenger_name
   FROM Tickets
   WHERE passenger_name = 'ADELINA IVANOVA') AS p
INNER JOIN Ticket_flights ON p.ticket_no = Ticket_flights.ticket_no
INNER JOIN Flights AS fd ON Ticket_flights.flight_id = fd.flight_id
INNER JOIN Airports AS da ON fd.departure_airport = da.airport_code
INNER JOIN Airports AS aa ON fd.arrival_airport = aa.airport_code
INNER JOIN Aircrafts AS a ON fd.aircraft_code = a.aircraft_code
INNER JOIN Boarding_passes AS fs ON Ticket_flights.ticket_no = fs.ticket_no AND Ticket_flights.flight_id = fs.flight_id
LEFT JOIN
  (SELECT bp.ticket_no, f2.flight_no AS next_flight_no, MIN(f2.scheduled_departure) OVER (PARTITION BY bp.ticket_no) - MAX(f1.scheduled_arrival) OVER (PARTITION BY bp.ticket_no) AS layover_duration
   FROM Boarding_passes bp
   INNER JOIN Flights f1 ON bp.flight_id = f1.flight_id
   INNER JOIN Flights f2 ON f1.arrival_airport = f2.departure_airport AND f2.scheduled_departure > f1.scheduled_arrival) AS li ON Ticket_flights.ticket_no = li.ticket_no
ORDER BY fd.scheduled_arrival DESC;
