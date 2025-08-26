SELECT 
    b.book_ref,
    COUNT(DISTINCT t.ticket_no) AS num_tickets,
    COUNT(DISTINCT tf.flight_id) AS num_flights,
    SUM(tf.amount) AS total_amount_for_flights,
    AVG(tf.amount) AS average_amount_per_flight,
    MAX(a.model->>'english') AS largest_aircraft_used,
    STRING_AGG(DISTINCT ap.city->>'english', ', ') AS cities_visited,
    (SELECT COUNT(*) 
     FROM boarding_passes bp 
     WHERE bp.ticket_no IN (SELECT ticket_no 
                             FROM tickets 
                             WHERE book_ref = b.book_ref)) AS total_boarding_passes_issued,
    COUNT(DISTINCT f.departure_airport) AS unique_departure_airports,
    SUM(CASE WHEN tf.amount > 500 THEN 1 ELSE 0 END) AS flights_over_500
FROM 
    bookings b
JOIN 
    tickets t ON b.book_ref = t.book_ref
JOIN 
    ticket_flights tf ON t.ticket_no = tf.ticket_no
JOIN 
    flights f ON tf.flight_id = f.flight_id
JOIN 
    aircrafts_data a ON f.aircraft_code = a.aircraft_code
JOIN 
    airports_data ap ON f.arrival_airport = ap.airport_code OR f.departure_airport = ap.airport_code
GROUP BY 
    b.book_ref
HAVING 
    COUNT(DISTINCT tf.flight_id) > 1 AND SUM(tf.amount) > 1000
ORDER BY 
    total_amount_for_flights DESC, num_flights DESC
LIMIT 10;
