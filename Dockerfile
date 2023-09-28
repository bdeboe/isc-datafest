ARG IMAGE=intersystemsdc/iris-ml-community:preview

FROM ${IMAGE}

USER root

WORKDIR /opt/irisbuild

RUN mkdir /opt/irisbuild/data/ && \
  chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisbuild && \
  chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisbuild/data 
#  && \
#  pip3 install --upgrade pip && \
#  pip3 install pandas pyarrow fastparquet requests

USER ${ISC_PACKAGE_MGRUSER}

COPY iris.script iris.script
COPY data/taxi/ /opt/irisbuild/data/taxi/

RUN iris start IRIS \
    && iris session IRIS < iris.script \
    && iris stop IRIS quietly 