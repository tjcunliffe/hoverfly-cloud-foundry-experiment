# Hoverfly Cloud Foundry Experiment


## Dependencies

- [Cloud Foundry CLI](https://github.com/cloudfoundry/cli)
- [Hoverfly](https://github.com/SpectoLabs/hoverfly):

```
brew install cloudfoundry/tap/cf-cli
brew install SpectoLabs/tap/hoverfly
```

## Get the latest Hoverfly Linux 64bit binary

Before proceeding, get the latest Linux 64bit binary:

```
./get-hoverfly-linux-amd64.sh
chmod +x hoverfly
```

## Hoverfly serving a "simulation" on $PORT

A website was [captured](https://docs.hoverfly.io/en/latest/pages/keyconcepts/modes/capture.html) using a local instance of Hoverfly and the resulting "simulation" was exported to a JSON file (`simulation.json`).

Push the Hoverfly app using the `hoverfly` manifest:

```
cf p -f manifests/hoverfly.yml
```

Point your browser at the app: [https://hoverfly.cfapps.io/](https://hoverfly.cfapps.io/).

Next, point you browser at [https://hoverfly.cfapps.io/about](https://hoverfly.cfapps.io/about).

Because the HTTP requests and responses for this page were not captured, the Hoverfly instance returns an error.

## Hoverfly serving a simulation on $PORT, with remote middleware pre-configured

This [simple Hoverfly middleware webserver](https://github.com/tjcunliffe/fixed-delay-middleware) injects a 5 second delay before each response is returned.

See also: [Hoverfly middleware](https://docs.hoverfly.io/en/latest/pages/keyconcepts/middleware.html)

First, push the middleware webserver:

```
git clone https://github.com/tjcunliffe/fixed-delay-middleware.git 
cd fixed-delay-middleware
cf p
```

Next, push the Hoverfly app using the `hoverfly-middleware` manifest: 

```
cf p -f manifests/hoverfly-middleware.yml
```

In this manifest, Hoverfly has been configured to use the middleware webserver via a flag in `command` value:

```
---
applications:
  - name: hoverfly-middleware
    buildpack: binary_buildpack
    memory: 64M
    command: ./hoverfly -webserver -pp $PORT -import simulation.json -middleware https://fixed-delay-middleware.cfapps.io/process
```


Tail the middleware webserver app log output:

```
cf logs fixed-delay-middleware
```

Now navigate to [https://hoverfly-middleware.cfapps.io/](https://hoverfly-middleware.cfapps.io/).

The page takes over 5 seconds to load, and the middleware webserver log output shows that each response is being delayed. For example:

```
2017-10-02T17:08:27.91+0100 [APP/PROC/WEB/0] OUT Delaying response by 5s
```

## Hoverfly serving the admin API on $PORT

Hoverfly requires two open ports: one for serving the simulation and the other for serving the admin API and the web UI.

First, push the Hoverfly app using the `hoverfly-admin` manifest:

```
cf p -f manifests/hoverfly-admin.yml
```

The Hoverfly admin API can be called directly:

```
curl https://hoverfly-admin.cfapps.io/api/v2/hoverfly
```

Or the hoverctl CLI can be used to manage the application:

```
hoverctl targets create hoverfly-cf \
                        --host https://hoverfly-admin.cfapps.io \
                        --admin-port 443
hoverctl -t hoverfly-cf version
```

Since Hoverfly is serving the admin API and the web UI on the only available port, it is not possible to view the simulation in a browser.

If you navigate to [https://hoverfly-admin.cfapps.io](https://hoverfly-admin.cfapps.io), you will see the Hoverfly web UI, not the simulation.

## Using the hoverctl CLI to configure remote middleware

Middleware can be configured when Hoverfly starts via a flag, or when Hoverfly is already running via the admin API or CLI.

Use hoverctl to check the status of the `hoverfly-admin` app:

```
hoverctl -t hoverfly-cf status
```

Next, configure the `hoverfly-admin` app to use the `fixed-delay-middleware`:

```
hoverctl -t hoverfly-cf middleware \
         --remote https://fixed-delay-middleware.cfapps.io/process
```

And re-check the status of the `hoverfly-admin` app:

```
+------------+----------+
| Hoverfly   | running  |
| Admin port |      443 |
| Proxy port |     8500 |
| Mode       | simulate |
| Middleware | enabled  |
+------------+----------+

Hoverfly is using remote middleware:
https://fixed-delay-middleware.cfapps.io/process
```

## Autoscaling a Hoverfly app

Start an instance of the App Autoscaler service:

```
cf cs app-autoscaler standard hoverfly-autoscaler
```

Push the Hoverfly app using the `hoverfly-autoscale` manifest: 

```
cf p -f manifests/hoverfly-autoscale.yml
```

Attempts were made to trigger the App Autoscaler by adjusting the scaling rules and firing load at the `hoverfly-autoscale` app.

Load was generated first from a laptop using a basic open source load testing tool:

```
brew install vegeta
echo "GET https://hoverfly-autoscale.cfapps.io" | vegeta attack -duration=30s -rate=50 | tee results.bin | vegeta report
```

And then using the LoadImpact service (which was configured using the LoadImpact web UI):

```
cf cs loadimpact lifree hoverfly-load-test
```

The Autoscaler did not appear to behave as expected when the Hoverfly app was under load, and time constraints prevented any further exploration.

However, the Hoverfly app was able to handle signficant load when scaled manually:

```
cf scale hoverfly -i 6
```





 

