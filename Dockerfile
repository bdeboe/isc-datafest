# use 2023.3 Developer Preview if you're adventurous
# ARG IMAGE=intersystemsdc/iris-ml-community:preview
ARG IMAGE=intersystemsdc/iris-ml-community:2023.2.0.227.0-zpm

FROM ${IMAGE}

USER root

WORKDIR /opt/irisbuild

RUN python3 -m pip install --upgrade pip 

USER ${ISC_PACKAGE_MGRUSER}

# stage data
COPY data/ /opt/irisbuild/data/

# IRIS setup
COPY iris.script iris.script
RUN iris start IRIS && \
    iris session IRIS < iris.script && \
    iris stop IRIS quietly


# dbt setup
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

COPY src/dbt/profiles.yml /home/irisowner/.dbt/profiles.yml
COPY src/dbt/ dbt/


# ensure dbt and data folders are writable and ready to roll
USER root
RUN chown -R ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisbuild 
USER ${ISC_PACKAGE_MGRUSER}
RUN dbt deps --project-dir ./dbt/datafest/