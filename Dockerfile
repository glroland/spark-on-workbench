#FROM quay.io/modh/odh-minimal-notebook-container:v3-20250704-9251d2c
FROM quay.io/modh/odh-workbench-jupyter-minimal-cpu-py311-ubi9:rhoai-2.21

ENV HADOOP_VERSION=3.4.1
ENV SPARK_VERSION=3.5.6
ENV SCALA_VERSION=2.12
ENV PY4J_VERSION=0.10.9.7

ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV SPARK_HOME=/opt/spark-${SPARK_VERSION}-bin-hadoop3

USER root

RUN yum install -y java-21-openjdk

RUN curl -o /tmp/hadoop.tgz https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz

RUN curl -o /tmp/spark.tgz https://dlcdn.apache.org/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}-bin-hadoop3.tgz

RUN tar -xvzf /tmp/hadoop.tgz -C /opt

RUN tar -xvzf /tmp/spark.tgz -C /opt

RUN rm -f /tmp/hadoop.tgz && rm -f /tmp/spark.tgz

RUN ln -s ${HADOOP_HOME} /opt/hadoop

RUN ln -s ${SPARK_HOME} /opt/spark

# Set Spark binary links
RUN rm -f /usr/local/bin/spark-submit /usr/local/bin/spark-class && \
    ln -s ${SPARK_HOME}/bin/spark-submit /usr/local/bin/spark-submit && \
    ln -s ${SPARK_HOME}/bin/spark-class /usr/local/bin/spark-class

# Persist environment for shell sessions
RUN echo "export JAVA_HOME=$(alternatives --display java | grep ' link currently points to ' | sed 's| link currently points to ||g' | sed 's|/bin/java$||g')" >> /etc/profile && \
    echo "export HADOOP_HOME=$HADOOP_HOME" >> /etc/profile && \
    echo "export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop" >> /etc/profile && \
    echo "export SPARK_HOME=$SPARK_HOME" >> /etc/profile && \
    echo "export PYSPARK_PYTHON=python" >> /etc/profile && \
    echo "export PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-$PY4J_VERSION-src.zip" >> /etc/profile && \
    echo "export SPARK_DIST_CLASSPATH=$SPARK_HOME/assembly/target/$SCALA_VERSION/jars/*" >> /etc/profile && \
    echo "export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$SPARK_HOME/bin:$PATH" >> /etc/profile

# Symlink for CDH Spark path (Cloudera expects it)
RUN mkdir -p /opt/cloudera/parcels/CDH-7.1.7-1.cdh7.1.7.p1000.24102687/lib/ && \
    ln -s ${SPARK_HOME} /opt/cloudera/parcels/CDH-7.1.7-1.cdh7.1.7.p1000.24102687/lib/spark
 
# ---- REMOVE Atlas Configs Completely ----
RUN find ${SPARK_HOME} -type f \( -iname "*atlas*" -o -iname "*atlas*.zip" -o -iname "*atlas*.egg" \) -delete && \
    find /opt/cloudera -type f \( -iname "*atlas*" -o -iname "*atlas*.zip" -o -iname "*atlas*.egg" \) -delete && \
    find / -type f -name "atlas-application.properties" -delete 2>/dev/null || true && \
    sed -i '/spark.extraListeners/d' ${SPARK_HOME}/conf/spark-defaults.conf || true && \
    sed -i '/SparkAtlasEventTracker/d' ${SPARK_HOME}/conf/spark-defaults.conf || true && \
    sed -i '/SparkAtlasStreamingQueryEventTracker/d' ${SPARK_HOME}/conf/spark-defaults.conf || true && \
    sed -i '/SPARK_EXTRA_LISTENERS/d' ${SPARK_HOME}/conf/spark-env.sh || true
 
# Create required keystore path for SSL / Kerberos
RUN mkdir -p /etc/pki/glroland_replace_me
 
# If building locally, copy keystore into image (place `java-keystore.jks` next to Dockerfile)
#COPY java-keystore.jks /etc/pki/glroland_replace_me/java-keystore.jks
RUN touch /etc/pki/glroland_replace_me/java-keystore.jks
 
# OpenShift best practice: ensure container doesn't require root
RUN chown -R 1001:root /opt /etc/pki/glroland_replace_me /tmp && \
    chmod -R 775 /opt /etc/pki/glroland_replace_me /tmp
 
USER 1001

ADD requirements.txt ./requirements.txt

RUN pip install -r ./requirements.txt

# Port for Pyspark Executor
EXPOSE 20000
