using LibPQ
using Random: rand, shuffle
using Tables
using UUIDs: UUID, uuid4

const FAST = false

Base.@kwdef struct Signal
    id::UUID
    recording::UUID
    span::String
    sensor_label::String
    sensor_type::String
    channels::Vector{String}
    sample_unit::String
    sample_resolution_in_unit::Float64
    sample_offset_in_unit::Float64
    sample_type::String
    sample_rate::Float64
    data
end

function simulate_headband(conn::LibPQ.Connection)
    recording = uuid4()

    eeg_channel_options = (
        ["f7-o1", "f8-o2", "f8-f7", "f8-o1", "f7-o2"],
        ["foo", "bar"],
        ["a", "b", "c", "d", "e"],
    )
    eeg_channels = eeg_channel_options[rand([1,1,1,1,2,3])]
    span = "[1,300_000_000_000)"

    signals = [
        Signal(; id=uuid4(), recording, span, sensor_label="eeg", sensor_type="eeg",
                channels=eeg_channels, sample_unit="microvolt",
                sample_resolution_in_unit=1, sample_offset_in_unit=0,
                sample_type="float32", sample_rate=250, data=b"abc")
        Signal(; id=uuid4(), recording, span, sensor_label="accelerometer", sensor_type="accelerometer",
                channels=["x", "y", "z"], sample_unit="gforce",
                sample_resolution_in_unit=1, sample_offset_in_unit=0,
                sample_type="float32", sample_rate=50, data=b"xyz")
        Signal(; id=uuid4(), recording, span, sensor_label="ignore", sensor_type="ignore",
                channels=["foo", "bar"], sample_unit="beat",
                sample_resolution_in_unit=1, sample_offset_in_unit=0,
                sample_type="uint8", sample_rate=1, data=b"---")
    ]

    # Simulate signals sometimes not being uploaded
    mask = rand(1:3, length(signals)) .!= 1

    for signal in shuffle(signals[mask])
        @info "Inserting: $signal"
        LibPQ.load!(
            Tables.columntable([signal]),
            conn,
            """
            INSERT INTO datastore.signal ($(join(fieldnames(Signal), ", ")))
                VALUES ($(join(["\$$i" for i in 1:fieldcount(Signal)], ", ")));
            """)
        sleep(FAST ? rand(0:0.1:1) : rand(0:10))
    end
end

function main()
    get_conn = retry(; delays=ExponentialBackOff(n=4),
                     check=(s,e) -> e isa LibPQ.Errors.JLConnectionError) do
        LibPQ.Connection("host=postgres user=postgres dbname=beacon password=demo")
    end

    conn = get_conn()
    while true
        simulate_headband(conn)
        FAST || sleep(5)
    end
end

#=
include("/app/headband.jl")
=#

if @__FILE__() == abspath(PROGRAM_FILE)
    main()
end
