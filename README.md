# Hoverfly Cloud Foundry Experiment

## Dependencies

- [Cloud Foundry CLI](https://github.com/cloudfoundry/cli)
- [Hoverfly](https://github.com/SpectoLabs/hoverfly)

```
brew install cloudfoundry/tap/cf-cli
brew install SpectoLabs/tap/hoverfly
```

Before proceeding, download a Hoverfly binary for 64bit Linux:

```
./get-hoverfly-linux-amd64.sh
chmod +x hoverfly
```

## Serving a simulation

Hoverfly allows you to create "simulations" of HTTP(S) APIs for use in testing. It can also "simulate" websites.

A website was [captured](https://docs.hoverfly.io/en/latest/pages/keyconcepts/modes/capture.html) using a local instance of Hoverfly, and the resulting "simulation" was exported to a JSON file (`simulation.json`).

Push the Hoverfly app using the `hoverfly` manifest:

```
cf p -f manifests/hoverfly.yml
```

In this manifest, Hoverfly has been configured to serve the simulation on the only available port via a flag (`-pp`) in the `command` value:

```
...
   command: ./hoverfly -webserver -pp $PORT -import simulation.json
```

Point your browser at the app: [https://hoverfly.cfapps.io](https://hoverfly.cfapps.io/). This is the website simulation.

Next, point you browser at [https://hoverfly.cfapps.io/about](https://hoverfly.cfapps.io/about). Because the HTTP requests and responses for this page were not captured when the simulation was created, Hoverfly returns an error.

## Serving a simulation with remote middleware pre-configured

This [simple Hoverfly middleware webserver](https://github.com/tjcunliffe/fixed-delay-middleware) injects a 5 second delay before each response is returned. See also: [Hoverfly middleware](https://docs.hoverfly.io/en/latest/pages/keyconcepts/middleware.html).

First, clone and push the middleware webserver app:

```
git clone https://github.com/tjcunliffe/fixed-delay-middleware.git 
cd fixed-delay-middleware
cf p
```

Next, push the Hoverfly app using the `hoverfly-middleware` manifest: 

```
cf p -f manifests/hoverfly-middleware.yml
```

In this manifest, Hoverfly has been configured to use the middleware webserver app via a flag (`-middleware`) in the `command` value:

```
...
   command: ./hoverfly -webserver -pp $PORT -import simulation.json -middleware https://fixed-delay-middleware.cfapps.io/process
```


Tail the middleware webserver app log output:

```
cf logs fixed-delay-middleware
```

Now navigate to [https://hoverfly-middleware.cfapps.io/](https://hoverfly-middleware.cfapps.io/). The page takes over 5 seconds to load, and the middleware webserver app log output shows that each response is being delayed. For example:

```
2017-10-02T17:08:27.91+0100 [APP/PROC/WEB/0] OUT Delaying response by 5s
```

## Serving the admin API

Hoverfly requires two ports: one for serving simulations, and the other for serving its admin API and web UI.

First, push the Hoverfly app using the `hoverfly-admin` manifest:

```
cf p -f manifests/hoverfly-admin.yml
```

In this manifest, Hoverfly has been configured to serve its **admin API and web UI** on the only available port via a flag (`-ap`) in the `command` value:

```
...
   command: ./hoverfly -webserver -ap $PORT -import simulation.json
```

Use the Hoverfly CLI (hoverctl) to check the version of the Hoverfly app you just pushed:

```
hoverctl targets create hoverfly-cf \
                        --host https://hoverfly-admin.cfapps.io \
                        --admin-port 443

hoverctl -t hoverfly-cf version
```

Since Hoverfly is serving its admin API and web UI on the only available port, it is not possible to view the simulation in a browser. If you navigate to [https://hoverfly-admin.cfapps.io](https://hoverfly-admin.cfapps.io), you will see the Hoverfly web UI, not the simulation.

## Configuring remote middleware while Hoverfly is running

Hoverfly can be configured to use middleware either using a flag (`-middleware`) when it is started, or via the admin API or CLI (hoverctl) while it is running.

Use the CLI to check the status of the Hoverfly app:

```
hoverctl -t hoverfly-cf status
```

Hoverfly reports that middleware is disabled.

Next, configure the Hoverfly app to use the middleware webserver:

```
hoverctl -t hoverfly-cf middleware \
         --remote https://fixed-delay-middleware.cfapps.io/process
```

Now re-check the status of the Hoverfly app:

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

This manifest binds the Hoverfly app to the `hoverfly-autoscaler` service.

Attempts were made to trigger the App Autoscaler by adjusting the scaling rules and firing load at the Hoverfly app.

Load was generated first from a laptop using a basic load testing tool:

```
brew install vegeta
echo "GET https://hoverfly-autoscale.cfapps.io" | vegeta attack -duration=30s -rate=50 | tee results.bin | vegeta report
```

And then using the LoadImpact service (which was configured using the LoadImpact web UI):

```
cf cs loadimpact lifree hoverfly-load-test
```

The Autoscaler did not appear to behave as expected when the Hoverfly app was under load. Time constraints prevented any further exploration. However, the Hoverfly app was able to handle signficant load when scaled manually:

```
cf scale hoverfly -i 6
```





 

