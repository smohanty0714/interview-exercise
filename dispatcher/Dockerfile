FROM julia:1.10

COPY Project.toml Manifest.toml /app/
RUN julia --project=/app -e ' \
        using Pkg; \
        Pkg.instantiate(); \
        Pkg.precompile(strict=true, timing=true)'

COPY . /app/

ENV JULIA_PROJECT="/app"
WORKDIR /app
ENTRYPOINT ["julia", "dispatcher.jl"]
