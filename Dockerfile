ARG IMAGE=intersystemsdc/iris-ml-community:preview

FROM ${IMAGE}

USER root

# ENV PIP_TARGET=${ISC_PACKAGE_INSTALLDIR}/mgr/python

WORKDIR /opt/irisbuild

RUN mkdir /opt/irisbuild/data/ && \
  chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisbuild && \
  chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisbuild/data  && \
  python3 -m pip install --upgrade pip 

USER ${ISC_PACKAGE_MGRUSER}

COPY iris.script iris.script
COPY requirements.txt requirements.txt
COPY data/ /opt/irisbuild/data/

RUN iris start IRIS && \
    iris session IRIS < iris.script && \
    iris stop IRIS quietly && \
    pip install -r requirements.txt

# not working with virtual env right now
# RUN python3 -m venv .venv && \
#    . .venv/bin/activate && \
#    pip install -r requirements.txt