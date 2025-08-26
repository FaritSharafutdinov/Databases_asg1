WITH aircraft_avg_duration AS (
    SELECT 
        f.aircraft_code,
        AVG(EXTRACT(EPOCH FROM (f.actual_arrival - f.scheduled_departure)) / 60) AS avg_duration
    FROM 
        bookings.flights f
    GROUP BY 
        f.aircraft_code
)
UPDATE bookings.ticket_flights tf
SET amount = amount * 1.15  
FROM 
    bookings.flights f
    JOIN aircraft_avg_duration aad ON f.aircraft_code = aad.aircraft_code
WHERE 
    tf.flight_id = f.flight_id
    AND aad.avg_duration > 180;
