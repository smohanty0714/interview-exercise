# Interview Exercise: Event Driven Dispatcher

This exercise is intended to simulate the experience of being introduced by your colleagues to an existing Beacon codebase that you would need to use and extend. To make the pairing more concrete and effective, you and your colleagues (interviewers) will work through the process of designing and implemention. Afterwards, your colleagues will invite you to zoom out and discuss the context in which this codebase is used.

Beacon as a whole makes extensive use of the [Julia programming language](https://julialang.org). As such, if you join us, you'll most likely be working with some Julia code. If you have never encountered Julia, **DON'T PANIC**. Most candidates have not and that is perfectly okay; you won't be at a disadvantage if you haven't. In fact, most of Beacon's scientists and engineers who work with Julia on a daily basis had never used it before joining!

Additionally, you'll during the interview you'll also be using Kafka and Kubernetes. Once again, you do not need to be familiar with any of these tools beforehand.

This is *not* is a traditional coding exercise where we watch you solve a problem on your own. Instead it is about us working together and attempting to simulate day-to-day collaboration. As such, during the interview you can (and should!) ask any and all questions, which we will gladly answer as we work through the exercise together.

## Before the interview

Please be prepare for the interview by performing the following steps in advance. You shouldn't expect to spend more than an hour to prepare. Ideally, you will have:

1. [Set up your Google Cloud Shell environment](#setup).
2. Prepared to share your screen over Google Meet.
3. Familized yourself with the [how to view and edit files in the Cloud Shell Editor](https://cloud.google.com/shell/docs/editor-overview).
4. Read this README (including skimming the [hints at the end](#hints) which will come in handy).

Once again you are *not* required to be familar with Julia, Kafka, or Kubernetes before the interview exercise to be successful. The exercise is a chance for us to see what it is like to work with you and assess your problem solving skills. We'll happily answer any questions you have as we go, but if you do want to learn more about the tooling you'll be using during the exercise we've provided this (entirely optional) reading list to help familiarize yourself with some of the essentials:

- The Julia Programming Language
    - [Official Documentation](https://docs.julialang.org): search is useful for discovering built-in function names.
        - [Functions](https://docs.julialang.org/en/v1/manual/functions/): You'll be both writing and calling functions.
    - [Reading JSON data using JSON3.jl](https://quinnj.github.io/JSON3.jl/stable/#Basic-reading-and-writing).
- [Kafka terminology](https://docs.confluent.io/kafka/introduction.html#terminology).
- A high-level [overview of Kubernetes](https://kubernetes.io/docs/concepts/overview/).

### Setup

We'll be using a Google Cloud Shell environment for the exercise which requires that you have a Google
account. You can provision a cloud shell environment in your browser by navigating to https://shell.cloud.google.com.

Then upload the provided `interview-exercise` folder: https://cloud.google.com/shell/docs/uploading-and-downloading-files

Run the following commands to install the necessary tooling:

```sh
# Install the asdf package manager
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
echo -e '. "$HOME/.asdf/asdf.sh"\n. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc

# Install direnv
asdf plugin add direnv
asdf install direnv latest
asdf global direnv latest
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
source ~/.bashrc

# Install Julia
curl -fsSL https://install.julialang.org | sh
source ~/.bashrc
```

Then startup a K8s environment using `minikube` and build the images. Ideally, do this as close to your start time as possible since the cloudshell may not persist the minikube state or the images over a long period of time (e.g. overnight). This should take 10-20 minutes to execute, so if we have to re-do it during the interview it's not a big deal.

```bash
source ~/.bashrc
cd "interview-exercise"
direnv allow

minikube start --cpus=2 --memory=4096
skaffold build
```

## During the interview

This next section will be what we go through during the interview. There's no need for you to do anything in this section beforehand, but feel free to read it over so you have a feel for what the exercise will entail on the day of. You don't need to remember the specifics of this section, your interviewers will guide you through it. And feel free to ask any questions that you have, your interviewers are here to help!

### Background

Beacon has developed a series of polling based services which monitor the Postgres database
and perform automated processing of data produced from Beacon's EEG headband. Additional services have been added over time and the polling based approach has been found to be scaling poorly and is causing performance issues with the database. After researching various options it was decided to switch the services to a message based setup using Kafka.

### Task

You'll be updating the Julia based `dispatcher` service to no longer poll the Postgres database but instead switch to a message based system utilizing Kafka. The included `headband` service periodically adds new signal data into the database which simulates incoming data from Beacon's EEG headband.

The team which setup Kafka on the database provided you with a [reference to the Kafka message format](https://debezium.io/documentation/reference/stable/connectors/postgresql.html#postgresql-events) and this command to view the Kafka messages produced when changes are made to the `datastore.signal` table (once the services are [deployed and ready](#deploying)):

```sh
kubectl run -it --rm kafka-consumer --image=quay.io/strimzi/kafka:0.42.0-kafka-3.7.1 --restart=Never -- bin/kafka-console-consumer.sh --bootstrap-server debezium-cluster-kafka-bootstrap:9092 --topic postgres.datastore.signal --from-beginning
```

There will be three main parts:

#### Part 1: Architecture design/exploration

1. [Deploy the the `dispatcher` service by following the instructions](#deploying).
2. Familiarize yourself with the existing `dispatcher` implementation and explain what the service is currently doing.
3. Discuss how you would update the implementation to use Kafka.

#### Part 2: Basic implementation

1. Implement a function to read a single Kafka message in Julia using [RDKafka.jl](https://github.com/dfdx/RDKafka.jl) (recommended to do this from inside the K8s cluster) and print the contents.
2. Enhance your function to parse the Kafka message using JSON3.jl to extract and return any information you need for your proposed implementation.
3. Use this function in the dispatcher loop to replace the global database poll, and call the `process_record` function for every complete set of signals.

#### Part 3: Follow-up discussions

After working through a basic implementation for an event-driven dispatcher, we'll discuss further architectural issues

1. How would you ensure the service is fault tolerant (i.e. the service should continue from where it left off when the pod restarts and avoid reprocessing).
2. Discuss approaches and limitations for introducing replica `dispatcher` pods.

### Deploying

You can deploy the `dispatcher` service and it's dependencies by running the following command:

```sh
skaffold dev --port-forward --tail=false --trigger=manual
```

This will deploy the various resources into a Kubernetes namespace and port forward all services to the host (allows `psql` access) once deployed. After the initial deployment Skaffold continue to run and monitor for any resource changes. Once you can press any key in the terminal running `skaffold dev` to cause Skaffold to re-build and re-deploy any modified resources. Be sure to save your changes!

It takes around 3 minutes for all of the resources to be ready. If you what to monitor the deployment you can use the following command in a separate terminal. The Kafka services are the slowest to start and the `READY` column under the `kafka`/`kafkaconnect`/`kafkaconnector` resources provides a more accurate indication if the `debezium-cluster` is ready:

```sh
watch kubectl get pod,deployment,kafka,kafkaconnect,kafkaconnector
```

Note that the pod `debezium-connect-cluster-connect` is currently expected to restart around 3 times as it requires the Kafka cluster to be ready before it can successfully run.

### Hints

#### Monitoring Pod Logs

You can monitor the logs from the various deployments or pods via `kubectl logs`:

```sh
kubectl logs -f deployment/dispatcher
```

#### Interactive Pod Connections

You can interactively connect to the pod using:

```sh
kubectl exec -it deployment/dispatcher -- /bin/bash
```

#### Interative Database Connections

You can simply run `psql` from within the `interview-exercise` directory to connect to the `postgres` pod's database. This requires you've run `direnv allow` and have ran `skaffold` with `--port-forward=true`.

#### Fixing Redeployment

If you get your `dispatcher` service into a bad state where Skaffold isn't redeploying upon a save then you should run `kubectl delete deployment/dispatcher`. The next time you make a change to `dispatcher` and save it the service will redeploy.

#### Manually Inserting

You can use the following Postgres code to insert a valid EEG and accelerometer signal for the same recording:

```sql
SELECT
    gen_random_uuid() AS recording1
\gset

INSERT INTO datastore.signal (
    id, data, recording, span, sensor_label, sensor_type, channels, sample_unit,
    sample_resolution_in_unit, sample_offset_in_unit, sample_type, sample_rate
) VALUES (
    gen_random_uuid(),
    'x'::bytea,
    :'recording1'::uuid,
    '[0,60_000_000_000)'::datastore.time_span,
    'eeg'::datastore.signal_label,
    'eeg'::datastore.signal_label,
    array['f7-o1', 'f8-o2', 'f8-f7', 'f8-o1', 'f7-o2'],
    'microvolt'::datastore.signal_label,
    1,
    0,
    'float32'::datastore.sample_type,
    250
), (
    gen_random_uuid(),
    'b'::bytea,
    :'recording1'::uuid,
    '[0,60_000_000_000)'::datastore.time_span,
    'accelerometer'::datastore.signal_label,
    'accelerometer'::datastore.signal_label,
    array['x', 'y', 'z'],
    'gforce'::datastore.signal_label,
    1,
    0,
    'float32'::datastore.sample_type,
    50
);
```
