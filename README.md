# docker-wildfly-embedded
A Docker container for Wildfly that allows configuration injection when booting the container. The container uses `confd` for generating a jboss-cli script that injects the configuration. The advantage of using `confd` is that it has many backends you can use, making it more versatile than using e.g. `consul-template`.

This is simple proof of concept to demonstrate how one could configure a default immutable Wildfly container, that would be usable in multiple environments (e.g. dev, test, UAT, staging, production, etc.), without having to 'hard-code' configuration into containers. I believe containers should adhere to the [12 factor principles](http://12factor.net), and should _not_ be purpose built for a specific environment.

## How it works
A new Wildfly container is generated using `docker build`. This build adds and pre-configures resources like JDBC drivers. These can be used/referenced to from other configuration. The build also adds `confd` and a `TOML` configuration + template for `confd`. A custom start script is used by the container to start Wildfly. Checkout the `Dockerfile` to see how the container is constructed.

The first thing this script does it use `confd` to generate a `jboss-cli` CLI script. In this script all runtime configuration to be injected into Wildfly is put. The configuration is retrieved from any backend that `confd` supports (e.g. environment variables, `etcd`, `consul`, `zookeeper`, etc.). The second thing the start script does is start `jboss-cli` and run an embedded Wildfly container in management mode. This means the server is started, and can be configured, but doesn't accept any requests on the public and/or management interfaces. It then uses the generated CLI script to configure the Wildfly server. As the CLI script ends, the server is automatically stopped. In the third and final step the start script starts the Wildfly container in stand-alone mode, as the official `jboss/wildfly` container does.

So it's kind of a 4 stage rocket:

1. The container is built, and all needed resources are added and preconfigured (as long as they're not environment specific, e.g. JDBC drivers)
2. At container start `confd` generates a `jboss-cli` script with all specific configurations
3. `jboss-cli` is started with the generated CLI script from step 1. This starts the Wildfly server in embedded mode and configures environment specific resources (e.g. LDAP, datasources, JavaMail sessions, security domains, etc.)
4. Wildfly is started in standalone mode, just like the official Wildfly container does

# Using this sample application
## Start a Consul server instance

```
docker run -d --net=host --name=consul gliderlabs/consul-server -bootstrap -advertise 192.168.99.100
```

Here 192.168.99.100 is my boot2docker virtualbox instance

## Prepare testdata in Consul

```
curl -X PUT -d '{ "name":"testDS", "type":"mysql", "host":"db.example.com", "port":"3306", "database":"example", "username": "user1", "password":"s3cr3t" }' http://192.168.99.100:8500/v1/kv/myapp/datasources/testDS
curl -X PUT -d '{ "name":"anotherDS", "type":"postgresql", "host":"db2.example.com", "port":"12345", "database":"pgsample", "username":"pgsql1", "password":"s3cr3t" }' http://192.168.99.100:8500/v1/kv/myapp/datasources/anotherDS
```

or simply use [Consul's web GUI](http://192.168.99.100:8500/ui/).

![Consul web UI Screenshot](https://cloud.githubusercontent.com/assets/2477789/12617640/e40c8568-c510-11e5-85fe-d18ae4729228.png)

Please note that the JSON format of the datasource definition needs to conform to a predetermined standard in order to be able to use it in the `confd` template. Check out `config-server.cli.tmpl` to see how the JSON values are parsed.

## Start Wildfly

```
docker build -t gntry/wildfly .
docker run -p 8080:8080 -p 9990:9990 gntry/wildfly
```

## See your configuration
Navigate to the Wildfly management console, and see your configuration in action:

![Wildfly datasource](https://cloud.githubusercontent.com/assets/2477789/12618819/de7269ce-c515-11e5-8d15-a7e051c65462.png)
