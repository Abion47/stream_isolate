# multithreaded_noise

A example Flutter app that demos the use of multithreading when generating images of Perlin Noise, showcasing the following:

* The benefit of multithreading by offloading the noise generation to a secondary isolate so that the image can be continuously regenerated without blocking the main thread. 
* The increased benefit of further splitting the workload among multiple worker threads, resulting in increased performance. 
* The diminishing returns of splitting the workload among too many worker threads, resulting in a maximum performance threshold and possibly even performance loss.

The multithreading is achieved using Bidirectional Stream Isolates, which greatly simplifies the process of passing data to and from the worker threads. See [lib/noise_simulation.dart](lib/noise_simulation.dart) for implementation details.
