WITH RECURSIVE recursive_routes AS (
    SELECT f.departure_airport AS origin, f.arrival_airport AS destination, ARRAY[f.flight_id] AS flight_path, ARRAY[f.departure_airport, f.arrival_airport]::bpchar[] AS airport_path, (f.scheduled_arrival - f.scheduled_departure) AS total_duration, 1 AS hops, f.flight_no, f.scheduled_departure, f.scheduled_arrival, tf.amount::numeric AS base_cost
    FROM 
    flights f
    JOIN ticket_flights tf ON f.flight_id = tf.flight_id
    JOIN seats s ON f.aircraft_code = s.aircraft_code
    WHERE 
    f.status NOT IN ('Cancelled')
    AND f.scheduled_departure > bookings.now()
    AND f.scheduled_departure < bookings.now() + INTERVAL '30 days'
    AND tf.fare_conditions = 'Economy'
    AND s.fare_conditions = 'Economy'
    UNION ALL
    SELECT r.origin, f.arrival_airport AS destination, r.flight_path || f.flight_id, r.airport_path || f.arrival_airport, r.total_duration + (f.scheduled_arrival - f.scheduled_departure), r.hops + 1, r.flight_no, r.scheduled_departure, f.scheduled_arrival, r.base_cost + tf.amount
    FROM 
    recursive_routes r
    JOIN flights f ON r.destination = f.departure_airport
    JOIN ticket_flights tf ON f.flight_id = tf.flight_id
    JOIN seats s ON f.aircraft_code = s.aircraft_code
    WHERE 
    f.status NOT IN ('Cancelled')
    AND f.scheduled_departure > r.scheduled_arrival + INTERVAL '1 hour'
    AND f.scheduled_departure < r.scheduled_arrival + INTERVAL '24 hours'
    AND NOT f.arrival_airport = ANY(r.airport_path)
    AND r.hops < 5
    AND tf.fare_conditions = 'Economy'
    AND s.fare_conditions = 'Economy'
),
route_details AS (
    SELECT r.origin, r.destination, r.hops, r.flight_path, r.airport_path, r.total_duration, r.base_cost, r.scheduled_departure, r.scheduled_arrival,
    (SELECT COUNT(*)
        FROM flights f6
        WHERE f6.departure_airport = r.origin
        AND f6.arrival_airport = r.destination
        AND f6.status NOT IN ('Cancelled')
        AND f6.scheduled_departure > bookings.now()
        AND f6.scheduled_departure < bookings.now() + INTERVAL '30 days'
    ) AS direct_flight_count
    FROM 
    recursive_routes r
)

SELECT DISTINCT ON (rd.origin, rd.destination) rd.origin, dep.city AS departure_city, rd.destination, arr.city AS arrival_city, rd.hops, rd.flight_path, rd.airport_path, rd.total_duration, rd.base_cost,
    (
    SELECT AVG(tf2.amount)
    FROM ticket_flights tf2
    JOIN flights f2 ON tf2.flight_id = f2.flight_id
    WHERE f2.departure_airport = rd.origin
    AND f2.arrival_airport = rd.destination
    AND tf2.fare_conditions = 'Economy'
    AND f2.scheduled_departure > bookings.now() - INTERVAL '180 days'
    ) AS avg_direct_cost,
    (
    SELECT COUNT(*)
    FROM boarding_passes bp
    JOIN flights f3 ON bp.flight_id = f3.flight_id
    WHERE f3.departure_airport = rd.origin
    AND f3.arrival_airport = rd.destination
    AND f3.scheduled_departure > bookings.now() - INTERVAL '30 days'
    ) AS recent_passenger_count,
    (
    SELECT AVG(EXTRACT(EPOCH FROM (f5.actual_arrival - f5.scheduled_arrival)))
    FROM flights f5
    WHERE f5.departure_airport = rd.origin
    AND f5.arrival_airport = rd.destination
    AND f5.scheduled_departure > bookings.now() - INTERVAL '180 days'
    AND f5.actual_arrival IS NOT NULL
    ) AS avg_delay_seconds,
    jsonb_agg(DISTINCT jsonb_build_object(
    'aircraft_code', ac.aircraft_code,
    'model', ac.model,
    'range', ac.range
    )) AS aircraft_used,
    (
    SELECT json_agg(monthly_data)
    FROM (
        SELECT json_build_object(
        'month', EXTRACT(MONTH FROM f4.scheduled_departure),
        'passengers', COUNT(DISTINCT bp2.ticket_no),
        'top_passengers', json_agg(
            json_build_object(
            'ticket_no', top_passengers.ticket_no,
            'flight_count', top_passengers.flight_count
            )
        )
        ) AS monthly_data
        FROM flights f4
        LEFT JOIN boarding_passes bp2 ON f4.flight_id = bp2.flight_id
        LEFT JOIN LATERAL (
        SELECT bp2_inner.ticket_no, COUNT(*) AS flight_count
        FROM boarding_passes bp2_inner
        JOIN flights f_inner ON bp2_inner.flight_id = f_inner.flight_id
        WHERE f_inner.departure_airport = rd.origin
        AND f_inner.arrival_airport = rd.destination
        AND EXTRACT(MONTH FROM f_inner.scheduled_departure) = EXTRACT(MONTH FROM f4.scheduled_departure)
        GROUP BY bp2_inner.ticket_no
        ORDER BY flight_count DESC
        LIMIT 3
        ) AS top_passengers ON true
        WHERE f4.departure_airport = rd.origin
        AND f4.arrival_airport = rd.destination
        AND f4.scheduled_departure > bookings.now() - INTERVAL '730 days'
        GROUP BY EXTRACT(MONTH FROM f4.scheduled_departure)
    ) AS monthly_counts
    ) AS historical_monthly_data,
    RANK() OVER (PARTITION BY rd.origin, rd.destination ORDER BY rd.total_duration) AS duration_rank
FROM 
    route_details rd
    JOIN airports_data dep ON rd.origin = dep.airport_code
    JOIN airports_data arr ON rd.destination = arr.airport_code
    JOIN LATERAL (
    SELECT DISTINCT ac.aircraft_code, ac.model, ac.range
    FROM unnest(rd.flight_path) AS flight_ids
    JOIN flights f5 ON f5.flight_id = flight_ids
    JOIN aircrafts_data ac ON f5.aircraft_code = ac.aircraft_code
    ) ac ON true
WHERE 
    (rd.hops > 1 OR rd.direct_flight_count < 10)
    AND dep.city <> arr.city
GROUP BY 
    rd.origin, dep.city, rd.destination, arr.city, rd.hops, rd.flight_path, 
    rd.airport_path, rd.total_duration, rd.base_cost
ORDER BY 
    rd.origin, rd.destination, rd.total_duration, rd.base_cost;