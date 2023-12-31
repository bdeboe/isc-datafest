# The InterSystems IRIS DataFest Demo

This is the DataFest Demo, mixing the most exciting IRIS data &amp; analytics features from 2023. 
Best served ice cold!

## Overview

In this demonstration, you'll experience a number of key innovations introduced with InterSystems IRIS in recent releases for enhancing our ability to support analytics, data fabric and general lakehouse scenarios. 

You'll see how we can quickly access external data using [Foreign Tables](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_tables#GSQL_tables_federated), and query it just like any other IRIS SQL table. Foreign tables are an alternative for copying the data into IRIS using the `LOAD DATA` command, and can be more practical when the data is managed externally, where maintaining a copy inside IRIS adds complexity to keep the data current or would be a poor use of storage. As such, it is an essential tool when implementing Data Fabric architectures.

We'll then use our new [dbt adapter](https://www.getdbt.com/) to transform the data into a format that is fit-for-purpose. The [data build tool](https://www.getdbt.com/) is an open source solution that implements the *T* in *ELT* (Extract-Load-Transform). It leaves the *EL* part to other tools that may be very platform-specific and exploit specialized ingestion utilities, and focuses squarely on the transformations. Dbt projects are file-based repositories of simple SQL files with parameters, and therefore empower data analysts and other SQL-literate personas to implement complex bulk data transformations using a familiar language. Our dbt support is currently experimental, but we believe it can already benefit many customers looking to transform data from one schema into another for analytics and general data fabric use cases.

In one of the schemas created using dbt, we've organized the data such that is ready for building a forecasting model using the new [IntegratedML](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GIML_Intro) support for such model types. IntegratedML empowers analysts and SQL developers to get started quickly with Machine Learning by offering a simple set of SQL commands to define, train and use ML models without requiring a PhD in data science. This is a quick way to enrich applications and offload true data scientists to increase the overall productivity of the data team.

Finally, we'll demonstrate how [Columnar Storage](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSOD_storage) ensures top query performance for analytical queries. Columnar Storage is an Advanced Server feature that stores table data using a different global structure and low-level encoding that enables highly efficient query plans and chipset-level optimizations for queries scanning and aggregating vast amounts of data. 
While this demo only includes a small dataset and the performance benefits are visible but close to the noise level, we'll also look at other metrics that illustrate the IO-level benefits, and a reference to a separate high-volume demo is included.

# Tutorial

This step-by-step guide will walk you through the different parts of the overall demo, and presents a few exercises so you can get hands-on with the various technologies. It assumes basic familiarity with [docker](https://docker.com/) to build and run the container image, and with IRIS SQL as the main language used throughout the exercises.


- [Building and starting the image](#building-and-starting-the-image)
- [Accessing external data using Foreign Tables](#accessing-external-data-using-foreign-tables)
  - [Cleaning up](#cleaning-up)
  - [Additional exercise](#additional-exercise)
  - [Cheat Sheet](#cheat-sheet)
  - [References](#references)
- [Working with dbt](#working-with-dbt)
  - [Creating a new project](#creating-a-new-project)
  - [Exercises](#exercises)
  - [A bigger project](#a-bigger-project)
  - [References](#references-1)
- [Building models with IntegratedML](#building-models-with-integratedml)
  - [A basic regression model](#a-basic-regression-model)
  - [Time Series modeling](#time-series-modeling)
  - [References](#references-2)
- [Leveraging Columnar Storage](#leveraging-columnar-storage)
  - [Creating the tables](#creating-the-tables)
  - [Running a few queries](#running-a-few-queries)
  - [References](#references-3)
- [Wrapping up](#wrapping-up)

## Building and starting the image

To build the image, make sure you are in the repository's root directory (`isc-datafest`) and run the following:

```Shell
docker build --tag iris-datafest .
```
or
```Shell
docker-compose build
```

When the image built succesfully, you can launch a container it using the following command, fine tuning any port mappings or image and container names as you prefer.

```Shell
docker run -d --name iris-datafest -p 41773:1972 -p 42773:52773 -p 8080:8080 iris-datafest --check-caps false --ISCAgent false
```
or (after changing any settings in the `docker-compose.yml` file)
```Shell
docker-compose up
```

To log in to the container, use your favourite SQL tool such as DBeaver to connect through port 41773, or log in to the container and access the SQL Shell directly using the following command:

```Shell
$ docker exec -it iris-datafest bash
irisowner@iris:/opt/irisbuild$ iris sql iris
```

:information_source: Starting with IRIS 2023.2, for security reasons we're no longer including a web server in default InterSystems IRIS installations, except for the Community Edition, which is not meant to be used for production deployments anyway. The docker script to build this image starts from a Community Edition image, so the SMP is still available at http://localhost:42773/csp/sys/UtilHome.csp, but we recommend you try using a client such as DBeaver to run SQL commands against the demo image.


## Accessing external data using Foreign Tables

[Foreign Tables](https://learning.intersystems.com/course/view.php?name=ForeignTables) are an ANSI SQL standard capability for projecting external data to SQL. Each foreign table is associated with a foreign server that groups metadata and credentials for a particular external source, which can be a filesystem directory (to project file-based data) or a remote database (IRIS or third-party). 
In this tutorial, we'll work with file-based data, so we want to create a foreign server representing the `/opt/irisbuild/data/` folder where our demo CSV files are located:

```SQL
CREATE FOREIGN SERVER datafest.FServer FOREIGN DATA WRAPPER CSV HOST '/opt/irisbuild/data/'
```

In the previous command, we're referring to a _Foreign Data Wrapper_, which is the "type" of server we'd like to create. The foreign tables specification covers a pluggable framework in which FDWs can be thought of as "plugins" that implement how you can access that particular type of server. As of IRIS 2023.3, we support FDWs for CSV and JDBC sources, with ODBC to become available in the near future.

With the foreign server in place, we can create a foreign table for the individual files in the data folder. Take a look at the `delhi.csv` file in the `data/` folder of the repository, either from inside the container using `vim`, or outside of the container with your preferred host OS tool. The file contains historical weather information for the city of Delhi.

```CSV
OBSDATE,HUMIDITY,PRESSURE,TEMPERATURECEL,TEMPERATUREFAR,WINDSPEED
2013-1-1 00:00:00,84.5,1015.666667,10,50,0
2013-1-2 00:00:00,92,1017.8,7.4,45.32,2.98
2013-1-3 00:00:00,87,1018.666667,7.166666667,44.9,4.633333333
2013-1-4 00:00:00,71.33333333,1017.166667,8.666666667,47.6,1.233333333
...
```

The command to create a foreign table is very similar to the the regular `CREATE TABLE` command. You specify the desired table structure through a list of column names and types, and then add a clause that refers to the foreign server to project from and the remaining details to identify the specific source for this table, in our case a file. 

Complete the following command and run it to project the file to SQL.

```SQL
CREATE FOREIGN TABLE datafest.Delhi (
  OBSDATE TIMESTAMP,
  HUMIDITY NUMERIC(10,5),
  ...
) SERVER ... FILE ...
  USING { "from" : {"file" : {"header": 1 } } }
```
:warning: This `USING` clause may look a little verbose at first, but we're aiming to keep the set of options supported by foreign tables and the `LOAD DATA` command 100% consistent, which may include error handling that is specified at the top level of this JSON structure rather than inside the trivial `from.file.*` nesting level that looks excessive here. Note also that foreign tables, like `LOAD DATA`, currently require dates and timestamps are specified in ODBC format in order to facilitate fast client-side parsing.

If the command is successful, you should be able to query the data just like any other SQL table:

```SQL
SELECT TOP 10 * FROM datafest.Delhi
```

Take a look at the query plan (enhanced on 2023.3) using the `EXPLAIN` command. We're querying a simple file-based server, so there isn't much to optimize other than reading the file. When the external data comes from a remote database though, the IRIS SQL optimizer will identify any filter predicates that pertain to the remote table and can be _pushed down_ to that database. For such queries, the query plan will include the exact statement that is sent to the remote database, including any pushed-down predicates in an additional `WHERE` clause.

Now you create additional table projections for the other files in the `data/` folder.
You can refine your `CREATE FOREIGN TABLE` commands to rename or reorder columns by using the `COLUMNS` and `VALUES` clauses, similar to what you used for `LOAD DATA`. Check the [SQL reference](https://docs.intersystems.com/iris20231/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_createforeigntable) for more details and examples.

### Cleaning up

If you ran into trouble with any of the previous commands, you can drop individual tables and servers using the corresponding `DROP` commands. To clean up an entire package in one command, use the `DROP SCHEMA` command:

```SQL
DROP FOREIGN TABLE datafest.Delhi;
DROP FOREIGN SCHEMA datafest;
DROP SCHEMA datafest CASCADE;
```

### Additional exercise

If you'd like to experiment with a foreign table that's based on a remote database, you can mock one up using a JDBC connection to the same IRIS instance we're currently working in (we didn't want to complicate the setup with a second database). JDBC-based foreign servers currently work off the same SQL Gateway connections you may have used in the past for programmatic access or in Interoperability productions, and we've included a connection named `MySelf` in the image we can leverage when creating a foreign server:

```SQL
CREATE FOREIGN SERVER datafest.MySelf FOREIGN DATA WRAPPER JDBC CONNECTION 'MySelf'
```

When creating a table projecting from a remote database, there is actually enough metadata we can scrape from the remote database to build the column list automatically, so if you want your foreign table to mirror the remote one, all you need to run is:

```SQL
CREATE FOREIGN TABLE datafest.RemoteDelhi SERVER datafest.MySelf TABLE 'datafest.Delhi'
```

:information_source: Note that in the previous command, we're using (quoted) literals for the remote table name, as the remote server may use a different type of identifiers.

Play around with these tables and the `EXPLAIN` command to see how predicates can be pushed down to the remote server.


### Cheat Sheet

If you managed to complete all the above steps successfully, congratulations! Just to make sure we start from a common base in the next sections of the tutorial, you can run the following utility to generate foreign tables in exactly the structure dbt expects in a new `demo_files` schema. 

If you feel adventurous, feel free to skip this shortcut and go into your dbt project to change all references to the source tables' schema to `datafest`.

```ObjectScript
do ##class(bdb.sql.InferSchema).CreateForeignTables("/opt/irisbuild/data/*.csv", { "verbose":1, "targetSchema":"demo_files" })
```
or 
```SQL
CALL bdb_sql.CreateForeignTables('/opt/irisbuild/data/*.csv', '{ "verbose":1, "targetSchema":"demo_files" }')
```

### References

If you'd like to learn more about foreign tables, check out the following resources:
* [Online Learning video on foreign tables](https://learning.intersystems.com/course/view.php?name=ForeignTables)
* Michael Golden's [foreign table demo repository](https://github.com/mgoldenisc/isc-resort-demo)
* IRIS SQL [product documentation on foreign tables](https://docs.intersystems.com/iris20231/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_tables#GSQL_tables_foreign) and reference pages for [`CREATE FOREIGN SERVER`](https://docs.intersystems.com/iris20231/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_createserver) and [`CREATE FOREIGN TABLE`](https://docs.intersystems.com/iris20231/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_createforeigntable)

:information_source: Please note that foreign tables is still labelled as an experimental feature in InterSystems IRIS 2023.3 as we still plan a number of enhancements, including better feature parity with `LOAD DATA`. Please do not hesitate to report any issues or feedback to help us build a great product.


## Working with dbt

Never heard of [dbt](http://getdbt.com)? It's the T in ELT (and if you haven't heard of that either, you're missing out!)

### Creating a new project

Let's get a dbt project started!

In order to create the project, navigate to the `opt/irisbuild/dbt/` directory and run the following command:

```Shell
dbt init
```
Name the project "exercises" and choose IRIS (1) as the database to be used.

This will give us a sample project in which we will create some models (a "[model](https://docs.getdbt.com/docs/build/models)" in dbt is a simple transformation, expressed as a SQL statement).

After navigating into the folder named after the project you just created (exercises) through `dbt init`, you can check the directory structure it created using the `ls` command. The simple folder structure with flat files makes it easy to integrate with version control systems. 
One file is special: `dbt_project.yml` has all the key properties of your project. One of those is the "[profile](https://docs.getdbt.com/docs/core/connect-data-platform/connection-profiles)" to be used when executing the project, which  holds the coordinates and credentials of the target platform. In this demo image, we have put a `profiles.yml` file in the `~/.dbt/` folder where dbt will look by default. All we need to to is make sure our project properties point to the "datafest" profile configured in that file. To achieve this, open `dbt_project.yml` and change the value of the `profile:` setting to `datafest`, save, and exit. We will change the value of the profile in exercise 1 below.

:information_source: To change your dbt project files, you can use `vim` inside the container to edit individual files. It may be nicer though to work on your dbt project from within your host OS. To do this, first install dbt using `pip install dbt-iris` and open the project in your host OS using an IDE such as VS Code. When you do this, please make sure to update the `dbt/profiles.xml` file to use the port exposed by the container (41773) and make sure it is in your `~/.dbt/` folder or refer to it using the `--profiles-dir` argument when using `dbt run` or other commands.

Alternatively, you can create and or modify the file on your host machine and copy over to the container using `docker cp`, for example:

```Shell
docker cp dbt_project.yml iris-datafest:/opt/irisbuild/dbt/exercises/
```

### Exercises

#### Exercise 1: a first model 

We will start by creating a simple model that reads the `walmart.csv` file, through a foreign table, to generate its own table. 
You first need to edit the existing `dbt_project.yml` in `dbt/exercises` to set the profile (datafest) and refine our model (workshop). We also add in a variable, under the `vars:` section, called StoreId which we will use later.

As already mentioned, you can either modify the files in the container or create one in your host machine and copy over to the container using "docker cp", for example:

```Shell
docker cp dbt_project.yml iris-datafest:/opt/irisbuild/dbt/exercises/
```

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
      exercises:
        workshop:
          +schema: workshop
          +materialized: table
    vars:
      StoreId: 'CA_1'
    
We will now create a directory "workshop" under `dbt/exercises/models`, to make sure our exercise material remains separate from the default examples the `dbt init` command generated. Note how this makes it easy to organize your overall transformations using simple folder structures. If you accidentally or intentionally put the files straight under the `models` folder, note that the `+schema: workshop` configuration won't be applied and your tables will materialize in the default target schema.

In the new `workshop` directory create a file `Walmart.sql` with the following contents:

```SQL
WITH Walmart AS (
  SELECT DT,Store_id,Item_id,Units_Sold as "Sales Amount",Sell_price as "Sales Value"
  FROM demo_files.walmart
)

SELECT *
FROM Walmart
```

:information_source: Use of the `WITH` clause here is optional, but common practice in dbt. You can just stick with the inner `SELECT` statement and leave out the second `SELECT *`. Note that this syntax (also known as _Common Table Expressions_) is not yet supported in IRIS SQL and specifically catered to in the dbt adapter. Proper server-side support for CTEs is planned with IRIS 2024.1.

Navigate to the `dbt/exercises/` folder and execute `dbt run`, after which you should see the following:

```Shell
irisowner@iris:/opt/irisbuild/dbt/exercises$ dbt run
07:03:31  Running with dbt=1.5.8
07:03:31  Registered adapter: iris=1.5.6
07:03:31  Unable to do partial parsing because a project config has changed
07:03:32  Found 3 models, 4 tests, 0 snapshots, 0 analyses, 314 macros, 0 operations, 0 seed files, 0 sources, 0 exposures, 0 metrics, 0 groups
07:03:32
07:03:32  Concurrency: 1 threads (target='iris')
07:03:32
07:03:32  1 of 3 START sql table model dbt.my_first_dbt_model ............................ [RUN]
07:03:32  1 of 3 OK created sql table model dbt.my_first_dbt_model ....................... [SUCCESS 2 in 0.39s]
07:03:32  2 of 3 START sql view model dbt_workshop.Walmart ............................... [RUN]
07:03:33  2 of 3 OK created sql view model dbt_workshop.Walmart .......................... [SUCCESS 6900 in 0.38s]
07:03:33  3 of 3 START sql view model dbt.my_second_dbt_model ............................ [RUN]
07:03:33  3 of 3 OK created sql view model dbt.my_second_dbt_model ....................... [SUCCESS 1 in 0.27s]
07:03:33
07:03:33  Finished running 1 table model, 2 view models in 0 hours 0 minutes and 1.21 seconds (1.21s).
07:03:33
07:03:33  Completed successfully
07:03:33
07:03:33  Done. PASS=3 WARN=0 ERROR=0 SKIP=0 TOTAL=3
```

Take a look at the table `dbt_Workshop.Walmart`.
Can you guess what the numbers right behind "SUCCESS" mean?

#### Exercise 2: adding another model

We will now create an aggregate model. Create a file called `WalmartState.sql` in `dbt/exercises/models/workshop` with the following contents:

```SQL
WITH WalmartState AS (
  SELECT STATE_ID,CAT_ID,SUM(SELL_PRICE) as "Total Sales"
  FROM demo_files.walmart
  GROUP BY STATE_ID,CAT_ID 
)

SELECT STATE_ID as State, CAT_ID as "Product Group", "Total Sales"
FROM WalmartState
```

Navigate to the `dbt/exercises/` folder and run the following:

```Shell
dbt run
```

Take a look at the table `dbt_Workshop.WalmartState`.

#### Exercise 3: using variables

We will now work with input variables in our models. Create a third file called `WalmartStore.sql` in `dbt/exercises/models/workshop` with the following contents:


```SQL
WITH WalmartStore AS (
  SELECT Store_id,Item_id,Sell_price
  FROM demo_files.walmart
  WHERE STORE_ID %StartsWith '{{var('StoreId')}}'
)

SELECT *
FROM WalmartStore
```


Note that this uses the input variable called StoreId which is defined in `dbt_project.yml` and defaults to 'CA_1'. Modify the parameter below (TX) to whatever you like.

Navigate to the `dbt/exercises/` folder again and run the following:

```Shell
dbt run --vars '{"StoreId":TX}' 
```

Take a look at the table `dbt_Workshop.WalmartStore`. Try again with a different parameter value.


#### Exercise 4: ~~writing~~ generating documentation 

To conclude, let's explore how dbt can automatically generate comprehensive project documentation. To generate and then serve up the documentation for your dbt project, use the `dbt docs` command from the main project folder `dbt/exercises/`, after which they are available at http://localhost:8080/:

```Shell
dbt docs generate
dbt docs serve
```

### A bigger project

This demo image also contains a fully built-out dbt project that touches on several more advanced dbt capabilities. 

In this project, we transform the `data/walmart.csv` file (projected through foreign tables we created in the first section of this tutorial) into a star schema for BI-style use cases, as well as a flattened file that's a good for data science and Time Series modeling in particular. Navigate to the `dbt/datafest/` folder and execute the following command to run the project:

```Shell
dbt run
```
Take a look at the `models.yml` file in `dbt/datafest/models/` where you can see how we can define sources which are then used in models. Also check out some of the models in the two directories, which demonstrate some advanced features, such as the use of the Jinja templates (the `{{ .. }}` and `{% .. %}` snippets included in the SQL source files) and dbt's built-in unit tests (look for the `tests:` section in `dbt/datafest/models/models.yml`).

Use the following commands to explore the documentation for this project:

```Shell
dbt docs generate
dbt docs serve
```

:information_source: Note that in this project we'll have models that depend on one another, for which dbt will create good-looking lineage diagrams. Look for the icon on the lower left corner of a model details page.

### References

To learn more about dbt, check out their really nice [documentation](https://docs.getdbt.com/docs/build/projects). 

For a _very_ comprehensive example project, that started from the FHIR SQL Builder, then used dbt to transform that data into an ML-friendly layout, and then uses IntegratedML to build predictive models, check out [this repository](https://github.com/isc-tdyar/iris-fhirsqlbuilder-dbt-integratedml) and the corresponding [Global Summit presentation](https://www.intersystems.com/fhir-to-integratedml-can-you-get-there-from-here-intersystems/).


## Building models with IntegratedML

In this section of the tutorial, we'll use [IntegratedML](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GIML_Intro) to train predictive models based on the datasets we've loaded and transformed in the previous exercises.

:information_source: Please pay attention to selecting the right ML provider for the right job to avoid long training times in the following exercises. Note that using `SET ML CONFIGURATION` in the SMP's SQL screen does not help a lot as it only sets the default for your current process, which in the current SMP design is a background process (to support long-running commands) that will be gone right after it finishes. In general it is good practice to select the ML provider at the start of your script to avoid surprises.

### A basic regression model

Let's start with a simple regression model to predict the distance covered in a New York taxi ride, based on the other properties of the ride log in the `data/nytaxi*.csv` files. This is a textbook IntegratedML scenario, so it shouldn't be more than a refresher exercise if you've used IntegratedML before.

:warning: The following command takes about 2 to3 minutes using the H2O provider on 2023.3. If you are using a different version or provider, training may take significantly longer and you may want to use the second `TRAIN MODEL` command that uses a smaller training dataset.

```SQL
SET ML CONFIGURATION %H2O;

CREATE MODEL distance PREDICTING (trip_distance) FROM demo_files.nytaxi_2020_05;

TRAIN MODEL distance;

-- for a shorter training time
CREATE VIEW demo.nytaxi_training AS SELECT TOP 10000 * FROM demo_files.nytaxi_2020_05;
TRAIN MODEL distance FROM demo.nytaxi_training;
```

Now you can test the model using the `PREDICT()` function:

```SQL
SELECT TOP 100 trip_distance AS actual_distance, PREDICT(distance) AS predicted_distance FROM demo_files.nytaxi_2020_05;
```

This should yield reasonable predictions, even if you only trained on the smaller dataset. 
However, we're testing the model against the same data we trained on, which is considered a capital sin by data scientists (luckily they aren't looking :wink:). Let's try on the data for the following month:

```SQL
SELECT TOP 10 trip_distance AS actual_distance, PREDICT(distance) AS predicted_distance FROM demo_files.nytaxi_2020_06;
```

Take a look at the quality of these predictions. 
Can you explain what is happening? 

:information_source: Here's a tip:

```SQL
SELECT TOP 10 trip_distance AS actual_distance, PREDICT(distance) AS predicted_distance FROM (SELECT VendorID, DATEADD("M",-1,tpep_pickup_datetime) AS tpep_pickup_datetime, DATEADD("M",-1,tpep_dropoff_datetime) AS tpep_dropoff_datetime, passenger_count, trip_distance, RatecodeID, store_and_fwd_flag, PULocationID, DOLocationID, payment_type, fare_amount, extra, mta_tax, tip_amount, tolls_amount, improvement_surcharge, total_amount, congestion_surcharge FROM demo_files.nytaxi_2020_06)
```

How would you address this for real?

:alert: There appears to be some variability in the quality of the trained model, depending on the random seed used as part of training, and also a late version upgrade since this exercise was first produced seems to have an impact. Please consider this a thorugh exercise if the numbers don't work out as well!


### Time Series modeling

For our second model, we'll use the new Time Series modeling capability introduced in InterSystems IRIS 2023.2. This technique does not just look at the different attributes of a single observation (a row in the training dataset), but at a whole window of past observations. Therefore, the training data needs to include a date or timestamp column in order for the algorithm to know how to sort the data and interpret that window. This kind of model is well-suited for forecasting, including when there is some sort of seasonality in the data, such as weekly or monthly patterns that would otherwise not show up in single-row predictions.

:information_source: Time Series modeling is currently only supported with the AutoML provider.

The following commands will start from the walmart dataset we restructured using dbt. If you hadn't completed that exercise, navigate to the `dbt/datafest/` folder and use `dbt run` to make sure the source tables are properly populated.

```SQL
SET ML CONFIGURATION %AutoML;

CREATE TIME SERIES MODEL walmart PREDICTING (*) BY (sell_date) FROM dbt_forecast.summarize USING { "Forward": 5 };

TRAIN MODEL walmart;

SELECT WITH PREDICTIONS (walmart) %ID, * FROM dbt_forecast.summarize;
```

Note how the `WITH PREDICTIONS (<model-name>)` clause adds rows rather than a column, as we saw in the previous exercise with a classic `PREDICT(<model-name>)` function. You'll notice that these additional rows with predictions (what's in a name!) don't have a RowID, which is how you can recognize them. Experiment with the `Forward` parameter in the `USING` clause (creating a new model) if you'd like a model with a different horizon.

Here's a second model that predicts the various properties of the Delhi Weather dataset:

```SQL
SET ML CONFIGURATION %AutoML;

CREATE TIME SERIES MODEL delhi PREDICTING (*) BY (obsdate) FROM demo_files.delhi USING {"Forward": 10 };

TRAIN MODEL delhi;

SELECT WITH PREDICTIONS (delhi) * FROM (SELECT TOP 100 %ID, * FROM demo_files.delhi);
```

As an advanced exercise, try building a query that shows the predicted values for a given timeframe alongside the actual observed values so you can evaluate the model's accuracy. If you're interested in more formal model performance metrics, try the `VALIDATE MODEL` command. 

```SQL
VALIDATE MODEL distance;
VALIDATE MODEL walmart;

SELECT * FROM INFORMATION_SCHEMA.ML_VALIDATION_METRICS;
```
:information_source: Please note validating time series models is computationally expensive and will take several minutes for the `delhi` model. 

A full explanation of the meaning of these metrics is outside the scope of this tutorial, but Wikipedia has great pages on the [MAPE](https://en.wikipedia.org/wiki/Mean_absolute_percentage_error), [RMSE](https://en.wikipedia.org/wiki/Root-mean-square_deviation) and [MdRAE](https://en.wikipedia.org/wiki/Mean_absolute_error) metrics we calculate for time series models.


### References

* Product documentation for [IntegratedML](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GIML_Intro)
* SQL Reference pages for [`CREATE MODEL`](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_createmodel) and [`SELECT`](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_select), which describe the new syntax
* [Global Summit presentation](https://www.intersystems.com/integratedml-new-next-intersystems/) introducing Time Series modeling


## Leveraging Columnar Storage

In this last section of our tutorial, we'll briefly explore [Columnar Storage](https://learning.intersystems.com/course/view.php?id=2112), an alternative for the classic row-based storage that is most commonly used in and the best fit for transactional applications. However, retrieving data that's stored in a row format can get costly for large analytical queries that need to aggregate data across millions of rows. This is where a column-organized storage structure is more appropriate, and it's available as a fully supported feature of InterSystems IRIS as of 2023.1.

:information_source: In this demo, you may not see the 10x performance improvements we claim in some of our [online learning resources](https://learning.intersystems.com/course/view.php?id=2077), for the very simple reason that this is a small demo with a small dataset. The performance benefits brought by columnar storage get lost in the noise for such small data, requiring at least a few millions of rows to show properly. [This more elaborate demo repository](https://github.com/bdeboe/isc-taxi-demo) loads a much larger dataset and comes with a full-documented Python notebook that properly illustrates the gains. In the space of this small-data demo, we'll focus on global references as a metric for the number of IO operations, as the differences for row- and columnar-organized tables will already indicate what to expect at a larger scale.

### Creating the tables

Let's set up the regular row-organized table first, and include a few indices:

```SQL
CREATE TABLE taxi.row AS 
  SELECT * FROM demo_files.nytaxi_2020_05 
    UNION 
  SELECT * FROM demo_files.nytaxi_2020_06;

CREATE INDEX pickup_time ON taxi.row(tpep_pickup_datetime);
CREATE BITMAP INDEX passenger_count ON taxi.row(passenger_count);
CREATE BITMAP INDEX payment_type ON taxi.row(payment_type);
```

We can set up the columnar-organized table with the same command; we only need to specify the `STORAGETYPE` and won't need any indices:
```SQL
CREATE TABLE taxi.col AS 
  SELECT * FROM demo_files.nytaxi_2020_05 
    UNION 
  SELECT * FROM demo_files.nytaxi_2020_06
WITH STORAGETYPE = COLUMNAR;
```

Note the difference in time required to build these two tables and associated indices. Building a columnar table takes more time, but it's not a different order of magnitude. Let's also take a look at the size these two variants take on disk, using the `bdb_sql.TableSize()` query in the SQL utility package that's preloaded on this image:

```SQL
SELECT * FROM bdb_sql.TableSize('taxi.row');
SELECT * FROM bdb_sql.TableSize('taxi.col');
```

That ratio should be about the inverse of the load time difference, so that's 1:1 in this row/columnar bake-off :wink:.


### Running a few queries

In this exercise, we'll focus on the number of global references as an indication of the IO cost of a query, and compare query plans. 

:information_source: If you're using a tool to connect to IRIS through JDBC rather than the SQL Shell or SMP (who show this by default), you can use the following crude utility to help track global references, approximately. Just remember to also call it _before_ running the query of interest, especially if you're also running queries several times to avoid cold cache bias.
```SQL
CREATE OR REPLACE FUNCTION GloRefs() 
  RETURNS INTEGER 
  LANGUAGE OBJECTSCRIPT 
  {  
    set now = $zu(61,43,$zu(61)) + $SYSTEM.Context.WorkMgr().GlobalReferences
    set since = now - $g(^demo.grefs), ^demo.grefs = now
    quit since
  }

SELECT GloRefs();  -- call it once to set the baseline
```

:information_source: If, on the other hand, you're using the SQL Shell or the SMP, please make sure to set the [select mode](https://docs.intersystems.com/iris20232/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_shell#GSQL_shell_selectmode) to ODBC as we'll be using some date arguments in the following queries. For the SMP, there is a dropdown list right above the query editor. In the SQL Shell, use the following command:
```SQL
set selectmode = odbc
```

:information_source: For looking query plans, the SQL page in the SMP still offers the most convenient rendering, as unfortunately most query tools such as DBeaver will collapse the XML version to a single line that's very hard to read.

Let's start with a basic analytical query, calculating the average total fare for multi-passenger rides in the first two weeks of May:

```SQL
SELECT 
  AVG(total_amount) AS avg_fare, 
  COUNT(*) AS ride_count
FROM taxi.row
WHERE passenger_count > 2 
  AND tpep_pickup_datetime BETWEEN '2020-05-01' AND '2020-05-14'
```

First run the query against the `taxi.row` table and then run it against the `taxi.col` data. You may want to run it multiple times to make sure it's a fair comparison and data is cached for both cases. Depending on your hardware, you should see a significant difference in performance, and independent of any hardware aspects a much larger difference in the number of global references these two queries take.

Now, take a look at the query plans for both queries and identify the differences that may be responsible. You may want to try varying the time window and removing the filter on passenger count to make the differences stand out.

Let's first consider the row-based plan:

![Row-based query plan](/img/plan-row-1.png)

In the row-based query plan, you'll see how the optimizer uses the index on `tpep_pickup_datetime`, because the time window we're considering is highly selective. If you extend the time window, it will combine this index with the bitmap index on `passenger_count` to further minimize the number of master map reads.

:information_source: Note how in 2023.3 we're now showing you the _actual_ query plan used at runtime, based on the query parameter values in the query text.On earlier versions, by default we would show the plan for the generalized statement, with all parameter values parsed out. This new default should make it easier to understand what IRIS SQL is doing, and you can still get the generalized plan by using at least one `?` placeholder instead of parameter values.

![Vectorized query plan](/img/plan-col-1.png)

In the columnar query plan, you'll see a fully _vectorized_ plan, which means the work can be split in small chunks that are executed in parallel using the recently introduced Adaptive Parallel Execution framework. Note how these chunks make use of efficient vector operations, which will take advantage of chipset level SIMD optimizations.

As mentioned at the start of this section, we're only scratching the surface here and the [other demo](https://github.com/bdeboe/isc-taxi-demo), with much more data, offers a more colourful illustration of the benefits of columnar storage.

### References

* Product documentation on [Columnar Storage](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSOD_storage)
* [Global Summit presentation](https://www.intersystems.com/columnar-storage-the-lean-data-warehouse-intersystems/), including customer testimonial
* [Full New York Taxi demo repository](https://github.com/bdeboe/isc-taxi-demo) 

## Wrapping up

That's all folks! If you ran into any issues during this tutorial, please log them on the [GitHub repository](https://github.com/bdeboe/isc-datafest).