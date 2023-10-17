# WORK IN PROGRESS

# The InterSystems IRIS DataFest Demo

This is the DataFest Demo, mixing the most exciting IRIS data &amp; analytics features from 2023. 
Best served ice cold!

## Overview

## Tutorial

### Building and starting the image

To build the image, make sure you are in the repository's root directory (`isc-datafest`) and run the following:

```Shell
docker build --tag iris-datafest .
```
or
```Shell
docker-compose build
```

When the image built succesfully, you can start it using the following command, fine tuning any port mappings or image and container names as you prefer.

```Shell
docker run -d --name iris-datafest -p 41773:1972 -p 42773:52773 -p 8080:8080 iris-datafest --check-caps false --ISCAgent false
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

**Ex 1. We will start by creating a simple model that reads the walmart.csv file to generate it's own table. You need to edit the existing dbt_project.yml in dbt/datafest to add in the addition model (Workshop) we also add in an extra variable called StoreId which we will use later**

You can either modify the files in the container or create one in your host machine and copy over to the container using "docker cp", for example:

    docker cp dbt_project.yml e84ccf9d1338:/opt/irisbuild/dbt/datafest/


   **dbt_project.yml**

   
    name: 'datafest'
    version: '1.0.0'
    config-version: 2
    
    # This setting configures which "profile" dbt uses for this project.
    profile: 'datafest'
    
    # These configurations specify where dbt should look for different types of files.
    # The `model-paths` config, for example, states that models in this project can be
    # found in the "models/" directory. You probably won't need to change these!
    model-paths: ["models"]
    analysis-paths: ["analyses"]
    test-paths: ["tests"]
    seed-paths: ["seeds"]
    macro-paths: ["macros"]
    snapshot-paths: ["snapshots"]
    
    clean-targets:         # directories to be removed by `dbt clean`
      - "target"
      - "dbt_packages"
    
    
    # Configuring models
    # Full documentation: https://docs.getdbt.com/docs/configuring-models
    
    # In this example config, we tell dbt to build all models in the example/
    # directory as views. These settings can be overridden in the individual model
    # files using the `{{ config(...) }}` macro.
    models:
      datafest:
        forecast:
          +schema: forecast
          +materialized: table
        starify:
          +schema: star
          +materialized: table
        Workshop:
          +schema: Workshop
          +materialized: table
    vars:
      pivot-field: CAT_ID
      StoreId: 'CA_1'

We will now create a directory "Workshop" under /dbt/datafest/model

In the "Workshop" directory create a file Walmart.sql with the following contents:

    WITH Walmart AS (
      SELECT DT,Store_id,Item_id,Units_Sold as "Sales Amount",Sell_price as "Sales Value"
      FROM {{ source('files', 'walmart') }}
    )
    
    SELECT *
    FROM Walmart

 Navigate to the `dbt/datafest/` folder and run the following:

```Shell
dbt run
```
Take a look at the table dbt_Workshop.Walmart

**Ex 2 - We will now create an aggregate model. Create a file called WalmartState.sql in /dbt/datafest/model/Workshop with the following contents:**

    WITH WalmartState AS (
      SELECT STATE_ID,CAT_ID,SUM(SELL_PRICE) as "Total Sales"
      FROM {{ source('files', 'walmart') }}
      GROUP BY STATE_ID,CAT_ID 
    )
    
    SELECT STATE_ID as State, CAT_ID as "Product Group", "Total Sales"
    FROM WalmartState

 Navigate to the `dbt/datafest/` folder and run the following:

```Shell
dbt run
```

Take a look at the table dbt_Workshop.WalmartState

**Ex 3 - we will now work with input variables in our models. Create a file called WalmartStore.sql in /dbt/datafest/model/Workshop with the following contents:**


    WITH WalmartStore AS (
      SELECT Store_id,Item_id,Sell_price
      FROM {{ source('files', 'walmart') }}
      WHERE STORE_ID %StartsWith '{{var('StoreId')}}'
    )
    
    SELECT *
    FROM WalmartStore


Note that this uses an input variable called StoreId which is defined in dbt_project.yml and defaults to 'CA_1' Modify the parameter below (TX) to whatever you like.

Navigate to the dbt/datafest/ folder and run the following:

```Shell
dbt run --vars '{"StoreId":TX}' 
```
Take a look at the table dbt_Workshop.WalmartStore

We'll use dbt to transform the `data/walmart.csv` file into a star schema for BI-style use cases, as well as a flattened file that's a good for data science and Time Series modeling in particular. Navigate to the `dbt/datafest/` folder and run the following:

```Shell
dbt run
```
Note that this has already been done, but it won't hurt...

To generate and then serve up the documentation for your dbt project, use the `dbt docs` command, after which they are available at [http://localhost:8080/]:

```Shell
dbt docs generate
dbt docs serve
```

To change your dbt project files, you can use `vim` inside the container to edit individual files. It may be nicer though to work on your dbt project from within your host OS. To do this, first install dbt using `pip install dbt-iris` and open the project in your host OS using an IDE such as VS Code. When you do this, please make sure to update the `dbt/profiles.xml` file to use the port exposed by the container (41773) and make sure it is in your `~/.dbt/` folder or refer to it using the `--profiles-dir` argument when using `dbt run` or other commands.


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

CREATE TIME SERIES MODEL walmart PREDICTING (*) BY (sell_date) FROM dbt_forecast.summarize USING { "Forward": 5 };

TRAIN MODEL walmart;

SELECT WITH PREDICTIONS (walmart) %ID, * FROM dbt_forecast.summarize;
```

```SQL
SET ML CONFIGURATION %AutoML;

CREATE TIME SERIES MODEL delhi PREDICTING (*) BY (obsdate) FROM demo_files.delhi USING {"Forward": 10 };

TRAIN MODEL delhi;

SELECT WITH PREDICTIONS (delhi) * FROM (SELECT TOP 100 %ID, * FROM demo_files.delhi);
```
