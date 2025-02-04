# https://strimzi.io/docs/operators/latest/full/deploying#creating-new-image-from-base-str
FROM quay.io/strimzi/kafka:0.42.0-kafka-3.7.1
USER root:root

# Download and install Debezium PostgreSQL connector plugin
ARG DEBEZIUM_VERSION="2.7.1.Final"
RUN curl -fsSL -O https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/${DEBEZIUM_VERSION}/debezium-connector-postgres-${DEBEZIUM_VERSION}-plugin.tar.gz && \
    tar -xvf debezium-connector-postgres-${DEBEZIUM_VERSION}-plugin.tar.gz && \
    mv debezium-connector-postgres /opt/kafka/plugins/ && \
    rm debezium-connector-postgres-${DEBEZIUM_VERSION}-plugin.tar.gz

USER 1001
