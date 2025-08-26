SELECT 
    t.passenger_name,
    t.passenger_id,
    COUNT(DISTINCT tf.ticket_no) AS total_tickets,
    SUM(tf.amount) AS total_amount_spent,
    COUNT(DISTINCT f.flight_id) AS total_flights,
    COUNT(DISTINCT bp.seat_no) AS total_seats_used,
    COUNT(DISTINCT a.aircraft_code) AS total_aircrafts_used
FROM 
    tickets t
JOIN 
    ticket_flights tf ON t.ticket_no = tf.ticket_no
JOIN 
    flights f ON tf.flight_id = f.flight_id
JOIN 
    boarding_passes bp ON tf.ticket_no = bp.ticket_no AND tf.flight_id = bp.flight_id
JOIN 
    aircrafts_data a ON f.aircraft_code = a.aircraft_code
WHERE 
    f.actual_departure >= '2012-01-01 00:00:00'
    AND f.actual_departure < '2017-12-31 23:59:59'
GROUP BY 
    t.passenger_name, t.passenger_id
HAVING 
    COUNT(DISTINCT tf.ticket_no) > 0
ORDER BY 
    total_amount_spent DESC;
