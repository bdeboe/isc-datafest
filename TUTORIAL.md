# WORK IN PROGRESS

# The InterSystems IRIS DataFest Demo

This is the DataFest Demo, mixing the most exciting IRIS data &amp; analytics features from 2023. 
Best served ice cold!

## Overview

In this demonstration, you'll experience a number of key innovations introduced with InterSystems IRIS in recent releases for enhancing our ability to support analytics, data fabric and general lakehouse scenarios. 

You'll see how we can quickly access external data using [Foreign Tables](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_tables#GSQL_tables_federated), and query it just like any other IRIS SQL table. Foreign Tables are an alternative for copying the data into IRIS using the `LOAD DATA` command, and can be more practical when the data is managed externally and maintaining a copy inside IRIS adds complexity to keep the data current or would be a poor use of storage. As such, it is an essential tool when implementing Data Fabric architectures.

We'll then use our new [dbt adapter](https://www.getdbt.com/) to transform the data into a format that is fit-for-purpose. The [data build tool](https://www.getdbt.com/) is an open source solution that implements the *T* in *ELT* (Extract-Load-Transform). It leaves the *EL* part to other tools that may be very platform-specific and exploit specialized ingestion utilities, and focuses squarely on the transformations. Dbt projects are file-based repositories of simple SQL files with parameters, and therefore empower analyst and other SQL-literate personas to implement complex bulk data transformations in a familiar language. Our dbt support is currently experimental, but we believe it can already benefit many customers looking to transform data from one schema into another for analytics and general data fabric use cases.

In one of the schemas created using dbt, we'll use [Columnar Storage](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GSOD_storage) to ensure top query performance for analytical queries. Columnar Storage is an Advanced Server feature that stores table data using a different global structure and low-level encoding that enables highly efficient query plans and chipset-level optimizations for queries scanning and aggregating vast amounts of data. 
While this demo may not include the data volumes at which the performance benefits become obvious, other metrics illustrate the IO-level benefits and a reference to a separate high-volume demo is included.

Finally, in another materialization facilitated by dbt, we've organized the data such that is ready for building a forecasting model using the new [IntegratedML](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GIML_Intro) support for such model types. IntegratedML empowers analysts and SQL developers to get started quickly with Machine Learning by offering a simple set of SQL commands to define, train and use ML models without requiring a PhD in data science. This is a quick way to enrich applications and offload true data scientists to increase the overall productivity of the data team.


## Tutorial

This step-by-step guide will walk you through the different parts of the overall demo, and presents a few exercises so you can get hands-on with the various technologies. It assumes basic familiarity with docker to build and run the container image, and with IRIS SQL as the main language used in the exercises.

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

To log in to the container, use your favourite SQL tool such as DBeaver to connect through port 41773, or log in to the container and access the SQL Shell directly using the following command:

```Shell
$ docker exec -it iris-datafest bash
irisowner@iris:/opt/irisbuild$ iris sql iris
```

:information_source: Starting with IRIS 2023.2, for security reasons we're no longer including a web server in default InterSystems IRIS installations, except for the Community Edition, which is not meant to be used for production deployments anyway. The docker script to build this image starts from the Community Edition, so the SMP is still available at http://localhost:42773/csp/sys/UtilHome.csp, but we recommend you try using a client such as DBeaver to run SQL commands against the demo image.


### Accessing external data using Foreign Tables

[Foreign Tables](https://learning.intersystems.com/course/view.php?name=ForeignTables) are an ANSI SQL standard capability for projecting external data to SQL. Each Foreign Table is associated with a Foreign Server that groups metadata and credentials for a particular external source, which can be a filesystem directory (to project file-based data) or a remote database (IRIS or third-party). 
In this tutorial, we'll work with file-based data, so we want to create a Foreign Server representing the `/opt/irisbuild/data/` folder where our demo CSV files are located:

```SQL
CREATE FOREIGN SERVER datafest.FServer FOREIGN DATA WRAPPER CSV HOST '/opt/irisbuild/data/'
```

In the previous command, we're referring to a _Foreign Data Wrapper_, which is the "type" of server we'd like to create. The Foreign Tables specification covers a pluggable framework in which FDWs can be thought of as "plugins" that implement how you can access that particular type of server. As of IRIS 2023.3, we support FDWs for CSV and JDBC sources, with ODBC expected in the near future.

With the Foreign Server in place, we can create a Foreign Table for the individual files in the data folder. Take a look at the `delhi.csv` file in the `data/` folder of the repository, either from inside the container using `vim`, or outside of the container with your preferred host OS tool. The file contains historical weather information for the city of Delhi.

```CSV
OBSDATE,HUMIDITY,PRESSURE,TEMPERATURECEL,TEMPERATUREFAR,WINDSPEED
2013-1-1 00:00:00,84.5,1015.666667,10,50,0
2013-1-2 00:00:00,92,1017.8,7.4,45.32,2.98
2013-1-3 00:00:00,87,1018.666667,7.166666667,44.9,4.633333333
2013-1-4 00:00:00,71.33333333,1017.166667,8.666666667,47.6,1.233333333
...
```

The command to create a Foreign Table is very similar to the the regular `CREATE TABLE` command. You specify the desired table structure through a list of column names and types, and then add a clause that refers to the Foreign Server to project from and the remaining details to identify the specific source for this table, in our case a file. 

Complete the following command and run it to project the file to SQL.

```SQL
CREATE FOREIGN TABLE datafest.Delhi (
  OBSDATE TIMESTAMP,
  HUMIDITY NUMERIC(10,5),
  ...
) SERVER ... FILE ...
  USING { "from" : {"file" : {"header": 1 } } }
```
:warning: This `USING` clause may look a little verbose at first, but we're aiming to keep the set of options supported by these two commands 100% consistent, which may include error handling that is specified at the top level of this JSON structure rather than inside the trivial `from.file.*` nesting level. Note also that Foreign Tables, like `LOAD DATA`, is currently limited to dates and timestamps in ODBC format in order to facilitate fast client-side parsing.

If the command is successful, you should be able to query the data just like any other SQL table:

```SQL
SELECT TOP 10 * FROM datafest.Delhi
```

Take a look at the query plan (enhanced on 2023.3) using the `EXPLAIN` command. We're querying a simple file-based server, so there isn't much to optimize other than reading the file. When the external data comes from a remote database though, the IRIS SQL optimizer will identify any filter predicates that pertain to the remote table and can be _pushed down_ to that database. For such queries, the query plan will include the exact statement that is sent to the remote database, including any pushed-down predicates in an additional `WHERE` clause.

Now you create additional table projections for the other files in the `data/` folder.
You can refine your `CREATE FOREIGN TABLE` commands to rename or reorder columns by using the `COLUMNS` and `VALUES` clauses, similar to what you used for `LOAD DATA`. Check the [SQL reference](https://docs.intersystems.com/iris20231/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_createforeigntable) for more details and examples.

#### Cleaning up

If you ran into trouble with any of the previous commands, you can drop individual tables and servers using the corresponding `DROP` commands. To clean up an entire package in one command, use the `DROP SCHEMA` command:

```SQL
DROP FOREIGN TABLE datafest.Delhi;
DROP FOREIGN SCHEMA datafest;
DROP SCHEMA datafest CASCADE;
```

#### Additional exercise

If you'd like to experiment with a Foreign Table that's based on a remote database, you can mock one up using a JDBC connection to the same IRIS instance we're currently working in (we didn't want to complicate the setup with a second database). JDBC-based Foreign Servers currently work off the same SQL Gateway connections you may have used in the past for programmatic access or in Interoperability productions, and we've included a connection named `MySelf` in the image:

```SQL
CREATE FOREIGN SERVER datafest.MySelf FOREIGN DATA WRAPPER JDBC CONNECTION 'MySelf'
```

When creating a table for a remote database, there is actually enough metadata we can scrape from the remote database to build the column list automatically, so if you want your foreign table to mirror the remote one, all you need to run is:

```SQL
CREATE FOREIGN TABLE datafest.RemoteDelhi SERVER datafest.MySelf TABLE 'datafest.Delhi'
```

Note that in the previous commands, we're using (quoted) literals for the remote table name, as the remote server may use a different type of identifiers.

Play around with these tables and the `EXPLAIN` command to see how predicates can be pushed down to the remote server.


#### Cheat Sheet

If you managed to complete all the above steps successfully, congratulations! Just to make sure we start from a common base in the next part of the tutorial, you can run the following utility to generate Foreign Tables in exactly the structure dbt expects in a new `demo_files` schema. 

If you feel adventurous, feel free to skip this shortcut and go into your dbt project to change all references to the source tables' schema to `datafest`.

```ObjectScript
do ##class(bdb.sql.InferSchema).CreateForeignTables("/opt/irisbuild/data/*.csv", { "verbose":1, "targetSchema":"demo_files" })
```

or 

```SQL
CALL bdb_sql.CreateForeignTables('/opt/irisbuild/data/*.csv', '{ "verbose":1, "targetSchema":"demo_files" }')
```

#### References

If you'd like to learn more about Foreign Tables, feel free to check out the following resources:
* [Online Learning video on Foreign Tables](https://learning.intersystems.com/course/view.php?name=ForeignTables)
* Michael Golden's [Foreign Table demo repository](https://github.com/mgoldenisc/isc-resort-demo)
* IRIS SQL [product documentation on Foreign Tables](https://docs.intersystems.com/iris20231/csp/docbook/DocBook.UI.Page.cls?KEY=GSQL_tables#GSQL_tables_foreign) and reference pages for [`CREATE FOREIGN SERVER`](https://docs.intersystems.com/iris20231/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_createserver) and [`CREATE FOREIGN TABLE`](https://docs.intersystems.com/iris20231/csp/docbook/DocBook.UI.Page.cls?KEY=RSQL_createforeigntable)

Please note that Foreign Tables is still labelled as an experimental feature in InterSystems IRIS 2023.3 as we still plan a number of enhancements, including better feature parity with `LOAD DATA`. 


### Working with dbt

Never heard of [dbt](http://getdbt.com)? It's the T in ELT (and if you haven't heard of that either, you're missing out!)

#### Creating a new project

Let's get a dbt project started!

In order to create the project, move to the `opt/irisbuild/dbt/` directory and run the following command:

```Shell
  dbt init
```
call the project "exercises" and choose IRIS (1) as the database to be used.

This will give us a sample project in which we will create some models (a "[model](https://docs.getdbt.com/docs/build/models)" in dbt is a simple transformation, expressed as a SQL statement).

After navigating into the folder named after the project you just created (exercises) through `dbt init`, you can check the directory structure it created using the `ls` command. The simple folder structure with flat files makes it easy to integrate with version control systems. 
One file is special: `dbt_project.yml` has all the key properties of your project. One of those is the "[profile](https://docs.getdbt.com/docs/core/connect-data-platform/connection-profiles)" to be used when executing the project, which  holds the coordinates and credentials of the target platform. In this demo image, we have put a `profiles.yml` file in the `~/.dbt/` folder where dbt will look by default. All we need to to is make sure our project properties point to the "datafest" profile configured in that file. To achieve this, open `dbt_project.yml` and change the value of the `profile:` setting to `datafest`, save, and exit. We will change the value of the profile in exercise 1 below.

:information_source: To change your dbt project files, you can use `vim` inside the container to edit individual files. It may be nicer though to work on your dbt project from within your host OS. To do this, first install dbt using `pip install dbt-iris` and open the project in your host OS using an IDE such as VS Code. When you do this, please make sure to update the `dbt/profiles.xml` file to use the port exposed by the container (41773) and make sure it is in your `~/.dbt/` folder or refer to it using the `--profiles-dir` argument when using `dbt run` or other commands.

Alternatively, you can create and or modify the file on your host machine and copy over to the container using "docker cp", for example:

    docker cp dbt_project.yml e84ccf9d1338:/opt/irisbuild/dbt/exercises/

#### Exercises

**Ex 1. We will start by creating a simple model that reads the walmart.csv file, through a foreign table, to generate its own table. You need to edit the existing dbt_project.yml in dbt/exercises to add in the  profile (datafest) and model (workshop). We also add in a variable, under the :vars section, called StoreId which we will use later**

As already mentioned, you can either modify the files in the container or create one in your host machine and copy over to the container using "docker cp", for example:

    docker cp dbt_project.yml e84ccf9d1338:/opt/irisbuild/dbt/exercises/


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
        workshop:
          +schema: workshop
          +materialized: table
    vars:
      StoreId: 'CA_1'
    
We will now create a directory "workshop" under /dbt/exercises/models

In the "workshop" directory create a file Walmart.sql with the following contents:

    WITH Walmart AS (
      SELECT DT,Store_id,Item_id,Units_Sold as "Sales Amount",Sell_price as "Sales Value"
      FROM demo_files.walmart
    )
    
    SELECT *
    FROM Walmart

 Navigate to the `dbt/exercises/` folder and run the following:

```Shell
dbt run
```
Take a look at the table dbt_Workshop.Walmart

**Ex 2 - We will now create an aggregate model. Create a file called WalmartState.sql in /dbt/exercises/models/workshop with the following contents:**

    WITH WalmartState AS (
      SELECT STATE_ID,CAT_ID,SUM(SELL_PRICE) as "Total Sales"
      FROM demo_files.walmart
      GROUP BY STATE_ID,CAT_ID 
    )
    
    SELECT STATE_ID as State, CAT_ID as "Product Group", "Total Sales"
    FROM WalmartState

 Navigate to the `dbt/exercises/` folder and run the following:

```Shell
dbt run
```

Take a look at the table dbt_Workshop.WalmartState

**Ex 3 - we will now work with input variables in our models. Create a file called WalmartStore.sql in /dbt/exercises/models/workshop with the following contents:**


    WITH WalmartState AS (
      SELECT STATE_ID,CAT_ID,SUM(SELL_PRICE) as "Total Sales"
      FROM demo_files.walmart
      GROUP BY STATE_ID,CAT_ID 
    )
    
    SELECT STATE_ID as State, CAT_ID as "Product Group", "Total Sales"
    FROM WalmartState


Note that this uses an input variable called StoreId which is defined in dbt_project.yml and defaults to 'CA_1'. Modify the parameter below (TX) to whatever you like.

Navigate to the dbt/exercises/ folder and run the following:

```Shell
dbt run --vars '{"StoreId":TX}' 
```
Take a look at the table dbt_Workshop.WalmartStore

#### A bigger project

This demo image also contains a fully built-out dbt project that touches on several more advanced dbt capabilities. 

In this project, we'll transform the `data/walmart.csv` file (projected through Foreign Tables we created in the first segment) into a star schema for BI-style use cases, as well as a flattened file that's a good for data science and Time Series modeling in particular. Navigate to the `dbt/datafest/` folder and execute the following command to run the project:

```Shell
dbt run
```

To generate and then serve up the documentation for your dbt project, use the `dbt docs` command, after which they are available at http://localhost:8080/:

```Shell
dbt docs generate
dbt docs serve
```

#### References

To learn more about dbt, check out their really nice [documentation](https://docs.getdbt.com/docs/build/projects). 

For a very comprehensive example project, that started from the FHIR SQL Builder, then used dbt to transform that data into an ML-friendly layout, and then uses IntegratedML to build predictive models, check out [this repository](https://github.com/isc-tdyar/iris-fhirsqlbuilder-dbt-integratedml) and the corresponding [Global Summit presentation](https://www.intersystems.com/fhir-to-integratedml-can-you-get-there-from-here-intersystems/).


### Building models with IntegratedML


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
