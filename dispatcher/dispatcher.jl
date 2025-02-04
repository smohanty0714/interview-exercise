using LibPQ
using Tables
using UUIDs: UUID
using TimeZones

function main()
    get_conn = retry(; delays=ExponentialBackOff(n=4),
                     check=(s,e) -> e isa LibPQ.Errors.JLConnectionError) do
        LibPQ.Connection("host=postgres user=postgres dbname=beacon password=demo")
    end

    conn = get_conn()

    latest_processed = ZonedDateTime(1970, 1, 1, tz"UTC")

    # TODO: Inserted at isn't perfect for tracking state.
    # PostgreSQL uses microsecond precision for `inserted_at` where as Julia uses
    # millisecond precision for `ZonedDateTime`s.
    query = """
        WITH eeg_signals AS (
            SELECT id, recording, inserted_at
            FROM datastore.signal
            WHERE
                sensor_type = 'eeg' AND
                channels @> array['f7-o1', 'f8-o2', 'f8-f7', 'f8-o1', 'f7-o2'] AND
                date_trunc('millisecond', inserted_at) > \$1
        ), accel_signals AS (
            SELECT id, recording, inserted_at
            FROM datastore.signal
            WHERE
                sensor_type = 'accelerometer' AND
                channels @> array['x', 'y', 'z'] AND
                date_trunc('millisecond', inserted_at) > \$1
        )
        SELECT
            eeg_signals.recording AS recording,
            eeg_signals.id AS eeg_signal,
            accel_signals.id AS accel_signal,
            GREATEST(eeg_signals.inserted_at, accel_signals.inserted_at) AS inserted_at
        FROM eeg_signals, accel_signals
        WHERE eeg_signals.recording = accel_signals.recording;
        """

    while true
        result = execute(conn, query, [latest_processed])
        data = columntable(result)

        for row in Tables.rows(data)
            recording = UUID(row[:recording])
            eeg_signal = UUID(row[:eeg_signal])
            accel_signal = UUID(row[:accel_signal])
            inserted_at = row[:inserted_at]

            process_recording(recording, eeg_signal, accel_signal)

            latest_processed = max(inserted_at, latest_processed)
        end

        sleep(1)
    end
end

function process_recording(recording::UUID, eeg_signal::UUID, accel_signal::UUID)
    println("Processing recording $recording...")
end

if @__FILE__() == abspath(PROGRAM_FILE)
    main()
end
