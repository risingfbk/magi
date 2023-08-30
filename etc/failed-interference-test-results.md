# Results of interference tests

## Tools used

- Kubernetes cluster v1.27 as described in the rest of project, with exactly same setup
- The following tools for web stress testing:
  - [Cassowary](https://github.com/rogerwelin/cassowary)
  - [wrk](https://github.com/wg/wrk)
  - [bombardier](https://github.com/codesenberg/bombardier)
  - [Locust](https://github.com/locustio/locust)
- The following web servers:
  - [httpd](https://hub.docker.com/_/httpd)
  - Obese httpd, a Docker image on top of *httpd* that injects a `index.html` file of various sizes (256 KB, 512 KB, 1 MB)
  - Google's [Online Boutique](https://github.com/GoogleCloudPlatform/microservices-demo), a demo made of several microservices

## Results

The goal of these tests was to verify what happened to a Kubernetes node hosting a webserver when our attack was deployed. We monitored all of Prometheus's metrics as in the previous work, and also obtained metrics from each of the tools used. These metrics usually comprised latency, requests per seconds, and more.

In each attack, we first started the webserver and started making requests, and then, at a certain point, started the attack. The attack was carried out with the `MaxParallelImagePull` parameter set to 4 and the `randomgb` image. 

### Locust

First of all, we used Locust to perform some tests on all three types of web servers. Locust works with *locustfiles*, i.e., Python files which instruct Locust to perform certain tasks on the webpage. In *httpd* and *Obese httpd*'s case, we instructed Locust to just visit the index page. In the microservices demo, instead, we created a mock walkthrough of the website, in which we visited some pages, pretended to buy some items, and performed the checkouts.

Results were mixed. With the microservices-demo, which by design has autoscaling enabled, starting the attack triggered the autoscaler, paradoxically decreasing latency and requests per second. By removing the autoscaler, we obtained more consistent results. In the periods of the attack of maximum network usage (e.g. at the very start, when four images were being downloaded concurrently), we decreased by a bit the requests per seconds and increased the latency, although by much.

Soon, we realized that the problem was more on the client side than the receiving side. Indeed, we were overloading the client with an excessive amount of concurrent users, skewing the results. We thus started executing tests with our MacBook Pro M1 as a client, rather than another VM.

Then, we decided to lower the amount of concurrent users (from 40 to 20). This time, we obtained more consistent results, but obtained a different side effect. Instead of increasing latency and decreasing requests per second, we instead increased the total amount of time required by `containerd` to download the image.

### Other tools

Seeking to reproduce these results with other tools, we switched to the other three tools listed above. Similarily to Locust, these three tools work in a DoS-like fashion, bombarding the target with a certain amount of requests. Each one of them opens a set amount of connections and maintains them open. We obtained similar results: each time, the web service would not be impacted much, at least using normal concurrent numbers for the size of our server. However, the total amount needed to download the image always increased.

The only time in which managed to obtain something slightly different was when we used Cassowary AFTER starting the attack and increased the total concurrent users. At a certain point, the server's network buffer was probably overloaded, and started dropping packets. We probably attribute this to Cassowary's implementation, which uses Go sockets and routines and is able to spawn and generated packets extremely fast.

### What does all of this mean?

With the results in hand, we believe we can distinguish two different scenarios:

- running the attack, THEN running the webserver
- running the webserver, THEN running the attack

In the first case, we distinguish between two phases: network-bound and I/O bound. In the network-bound phase, the socket is busy downloading at most four images, and any traffic that is received during that phase is usually dropped because of the high amount of traffic traversing the network. However, in the I/O bound phase, `containerd` is busy unpacking the downloading images, which requires more CPU but no network. In this phase, network traffic not only will be handled normally, but the CPU required for handling this traffic will probably be pre-empted from the unpacking, increasing the unpacking time. Depending on the size of the images, these two phases are not discrete, as perhaps two threads will be busy downloading images while others will unpack others. However, its effect is seen in its full force at the start of the attack

In the second case, we obtain a similar situation to previous one, only that in the network-bound phase, traffic from the webserver is not impacted as much. The attack's traffic has difficulty in saturating the network buffers, as they are already busy themselves with the webserver traffic. This often results in the attack being instead suspended or distrupted, taking longer to complete.
