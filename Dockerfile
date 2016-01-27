FROM jboss/wildfly

# SHA1 sums for download/extract validation
ENV CONFD_SHA1 dd4479abccb24564827dcf14fcb73ccc5bba8aeb
ENV MYSQL_TAR_SHA1 c76df144d24b4c654dd5417b9b18e094534acba8
ENV MYSQL_JAR_SHA1 7b9bfb6c4e4885660378a9c13330915c321f6cca
ENV POSTGRESQL_JAR_SHA1 f2ea471fbe4446057991e284a6b4b3263731f319
ENV DB2_TAR_SHA1 b806f1304122f09a2ab07cd8035b091b3b465c7c
ENV DB2_JAR_SHA1 9344d4fd41d6511f2d1d1deb7759056495b3a39b

# Important build/config locations
ENV JBOSS_MODULES_DIR $JBOSS_HOME/modules/system/layers/base
ENV MYSQL_MODULE_DIR $JBOSS_MODULES_DIR/com/mysql/driver/main
ENV POSTGRESQL_MODULE_DIR $JBOSS_MODULES_DIR/org/postgresql/driver/main
ENV DB2_MODULE_DIR $JBOSS_MODULES_DIR/com/ibm/db2/driver/main

# Get all needed external resources (confd, drivers, etc)
USER root
RUN curl -s -o /usr/local/bin/confd -L https://github.com/kelseyhightower/confd/releases/download/v0.11.0/confd-0.11.0-linux-amd64 \
    && sha1sum /usr/local/bin/confd | grep $CONFD_SHA1 \
    && chmod +x /usr/local/bin/confd \
    && mkdir -p $MYSQL_MODULE_DIR \
    && cd $MYSQL_MODULE_DIR \
    && curl -s -o /tmp/mysql-connector-java-5.0.8.tar.gz -L https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.0.8.tar.gz \
    && sha1sum /tmp/mysql-connector-java-5.0.8.tar.gz | grep $MYSQL_TAR_SHA1 \
    && tar -zxvf /tmp/mysql-connector-java-5.0.8.tar.gz --strip 1 --no-anchor mysql-connector-java-5.0.8-bin.jar \
    && sha1sum mysql-connector-java-5.0.8-bin.jar | grep $MYSQL_JAR_SHA1 \
    && chown -R jboss:jboss $MYSQL_MODULE_DIR \
    && chmod -R 744 $MYSQL_MODULE_DIR \
    && rm -f /tmp/mysql-connector-java-5.0.8.tar.gz \
    && mkdir -p $POSTGRESQL_MODULE_DIR \
    && cd $POSTGRESQL_MODULE_DIR \
    && curl -s -o ./postgresql-9.4.1207.jar -L https://jdbc.postgresql.org/download/postgresql-9.4.1207.jar \
    && sha1sum postgresql-9.4.1207.jar | grep $POSTGRESQL_JAR_SHA1 \
    && chown -R jboss:jboss $POSTGRESQL_MODULE_DIR \
    && chmod -R 744 $POSTGRESQL_MODULE_DIR \
    && mkdir -p $DB2_MODULE_DIR \
    && cd $DB2_MODULE_DIR \
    && curl -s -o /tmp/v10.5fp6_jdbc_sqlj.tar.gz -L https://delivery04.dhe.ibm.com/sdfdl/v2/sar/CM/IM/05kcg/0/Xa.2/Xb.jusyLTSp44S0BiAKIAqzMTY_UHKOoMoTRZK0Up-PT02py_iUwWBio07bYGs/Xc.CM/IM/05kcg/0/v10.5fp6_jdbc_sqlj.tar.gz/Xd./Xf.LPR.D1vk/Xg.8457930/Xi.habanero/XY.habanero/XZ.hfV9Oy0rt6GqWP_bOUMQPuBp05k/v10.5fp6_jdbc_sqlj.tar.gz \
    && sha1sum /tmp/v10.5fp6_jdbc_sqlj.tar.gz | grep $DB2_TAR_SHA1 \
    && tar -zxvf /tmp/v10.5fp6_jdbc_sqlj.tar.gz --strip 1 --no-anchor db2_db2driver_for_jdbc_sqlj.zip \
    && unzip -jn db2_db2driver_for_jdbc_sqlj.zip db2jcc4.jar -d $DB2_MODULE_DIR \
    && sha1sum db2jcc4.jar | grep $DB2_JAR_SHA1 \
    && rm -f db2_db2driver_for_jdbc_sqlj.zip \
    && rm -f /tmp/v10.5fp6_jdbc_sqlj.tar.gz \
    && chown -R jboss:jboss $DB2_MODULE_DIR \
    && chmod -R 744 $DB2_MODULE_DIR \
    && mkdir -p /etc/confd/conf.d \
    && mkdir -p /etc/confd/templates

# Add the CLI script template confd will use for injecting configuration
ADD wildfly.toml /etc/confd/conf.d/wildfly.toml
ADD config-server.cli.tmpl /etc/confd/templates/config-server.cli.tmpl

# Continue as Wildfly runtime user
USER jboss
RUN cd $JBOSS_HOME
ADD mysql_module.xml $MYSQL_MODULE_DIR/module.xml
ADD postgresql_module.xml $POSTGRESQL_MODULE_DIR/module.xml
ADD db2_module.xml $DB2_MODULE_DIR/module.xml
ADD start_wildfly.sh start_wildfly.sh

# Secure the admin interface
RUN /opt/jboss/wildfly/bin/add-user.sh admin Admin#2016 --silent

# Expose the public and management port
EXPOSE 8080
EXPOSE 9990

# Use entrypoint to start JBoss CLI and configure runtime parameters
ENTRYPOINT [ "/opt/jboss/start_wildfly.sh" ]

# Use CMD, which the start_wildfly.sh script will use to start the Wildfly process
CMD ["/opt/jboss/wildfly/bin/standalone.sh", "-c", "standalone-full.xml" ]
