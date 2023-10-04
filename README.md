# The InterSystems IRIS DataFest Demo

This is the DataFest Demo, mixing the most exciting IRIS data &amp; analytics features from 2023. 
Best served ice cold!

## Overview

## Tutorial

### Building and starting the image

To build the image, make sure you are in the repository's root directory (`isc-datafest`) and run the following:

```Shell
docker build . --tag iris-datafest
```
or
```Shell
docker-compose build
```

When the image built succesfully, you can start it using the following command, fine tuning any port mappings or image and container names as you prefer.

```
docker run -d --name iris-datafest -p 41773:1972 -p 42773:52773 iris-datafest --check-caps false --ISCAgent false
```
or (after changing any settings in the `docker-compose.yml` file)
```Shell
docker-compose up
```

To log in to the container, use `docker exec -it <container-name> bash`, or use your favourite SQL tool to connect through port 41773.

### Creating the Foreign Tables

Shortcut:
```ObjectScript
do ##class(bdb.sql.InferSchema).CreateForeignTables("/opt/irisbuild/data/*.csv", { "verbose":1, "targetSchema":"demo_files" })
```

or 

```SQL
CALL bdb_sql.CreateForeignTables('/opt/irisbuild/data/*.csv', '{ "verbose":1, "targetSchema":"demo_files" }')
```

### Working with dbt

Never heard of [dbt](http://getdbt.com)? It's the T in ELT (and if you haven't heard of that either, you're missing out!)


### Building models with IntegratedML

Starting with IRIS 2023.2, for security reasons we're no longer including a web server in default InterSystems IRIS installations, except for the Community Edition, which is not meant to be used for production deployments anyway. The docker script to build this image starts from the Community Edition, so the SMP is still available at [http://localhost:42773/csp/sys/UtilHome.csp], but we recommend you try using a client such as DBeaver to run SQL commands against the demo image.


#### A basic regression model

This takes very long if you stick with the default ML Provider (AutoML)! Please note that using `SET ML CONFIGURATION` in the SMP's SQL screen does not help a lot as it only sets the default for your current process, which in the current SMP design is a background process (to support long-running commands) and is gone right after it finishes. In general it is good practice to select the ML provider at the start of your script to avoid surprises.

```SQL
SET ML CONFIGURATION %H2O;

CREATE MODEL distance PREDICTING (trip_distance) FROM demo_files.nytaxi_2020_05;

TRAIN MODEL distance;
```

#### Time Series modeling

For this model, we'll use the new Time Series modeling capability in InterSystems IRIS 2023.2. This technique does not just look at the different attributes of a single observation (row in the training data), but at a window of past observations. Therefore, the training data needs to include a date or timestamp column in order for the algorithm to know how to sort the data and interpret that window. This kind of model is well-suited for forecasting, including when there is some sort of seasonality in the data, such as weekly or monthly patterns that would otherwise not show up.

```SQL
SET ML CONFIGURATION %AutoML;

CREATE TIME SERIES MODEL walmart PREDICTING (units_sold, sell_price) BY (dt) FROM demo_files.walmart;

TRAIN MODEL walmart;
```

```SQL
SET ML CONFIGURATION %AutoML;

CREATE TIME SERIES MODEL delhi PREDICTING (*) BY (obsdate) FROM demo_files.delhi USING {"forward": 10 };

TRAIN MODEL delhi;

SELECT WITH PREDICTIONS (delhi) * FROM (SELECT TOP 10 %ID, * FROM demo_files.delhi);
```