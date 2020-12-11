# Beats Keystore Add

Add in beats keystores a set of keys sourced from shell env-file.

## Usage

to get help use: `./beats-keystore-add.sh -h`
```
Usage:
  ./beats-keystore-add.sh [OPTION]...

Options:
  -h, --help                Show this message
  -b, --beat <beatname>     Chose beats who will append the pass in keystore (Default metricbeat)
  -f, --env-file <filename> Source envs from shell file and store them in chosed beats (Default .beatpass)
  -v, --verbose             Verbose mode
  -d, --debug               Debug mode

By Env:
  You can pass parameters as env for script
  BEATS    - space separated list of beats
  ENV_FILE - path of env file


Examples:-
  ./beats-keystore-add.sh --help
  ./beats-keystore-add.sh --debug -v -b metricbeat
  ./beats-keystore-add.sh --beat metricbeat --beat filebeat --env-file all_envs.sh
  BEATS="journalbeat auditbeat" ENV_FILE="all_pass.sh" ./beats-keystore-add.sh

Beats:
  metricbeat
  filebeat
  heartbeat
  packetbeat
  auditbeat
  journalbeat

EnvFile:
  sh or bash format
```

## Example EnvFile
example of env-file used in beats

```sh
#!/bin/sh

# .beatkeys

## elasticsearch
ES_USER=esuser
ES_PASS=STRONGESPASS

## kibana
KIBANA_USER=kibanauser
KIBANA_PASS=STRONGKIBANAPASS
```

then you can use it in call of module
```yaml
- module: elasticsearch
  xpack.enabled: true
  period: 10s
  hosts:
    - https://node1.coolhost.com:9200
    - https://node2.coolhost.com:9200
  protocol: https
  username: "${ES_USER}"
  password: "${ES_PASS}"
```


