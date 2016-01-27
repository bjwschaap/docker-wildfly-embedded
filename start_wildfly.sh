#!/bin/bash
#
# Generate the CLI script with confd
echo "-----------------------------------------------------------------------------------"
echo "Generating CLI with CONFD for runtime container configuration"
echo "-----------------------------------------------------------------------------------"
confd -onetime -backend consul -node 192.168.99.100:8500

# Configure the server with CLI script
echo "-----------------------------------------------------------------------------------"
echo "Starting embedded Wildfly in management-mode using JBoss CLI to configure container"
echo "-----------------------------------------------------------------------------------"
/opt/jboss/wildfly/bin/jboss-cli.sh --file=/tmp/config-server.cli

# Now start the server with command specified by CMD
echo "-----------------------------------------------------------------------------------"
echo "Starting Wildfly with: ${@}"
echo "-----------------------------------------------------------------------------------"
exec "$@"
