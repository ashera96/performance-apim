# {{ parameters.application_name }} Performance Test Results

During each release, we execute various automated performance test scenarios and publish the results.

| Test Scenarios | Description |
| --- | --- |
{%- for test_scenario in parameters.test_scenarios %}
| {{test_scenario.display_name}} | {{test_scenario.description}} |
{%- endfor %}

Our test client is [Apache JMeter](https://jmeter.apache.org/index.html). We test each scenario for a fixed duration of
time. We split the test results into warmup and measurement parts and use the measurement part to compute the
performance metrics.

Test scenarios use a [Netty](https://netty.io/) based back-end service which echoes back any request
posted to it after a specified period of time.

We run the performance tests under different numbers of concurrent users, message sizes (payloads) and back-end service
delays.

The main performance metrics:

1. **Throughput**: The number of requests that the {{ parameters.application_name }} processes during a specific time interval (e.g. per second).
2. **Response Time**: The end-to-end latency for an operation of invoking an API. The complete distribution of response times was recorded.

In addition to the above metrics, we measure the load average and several memory-related metrics.

The following are the test parameters.

| Test Parameter | Description | Values |
| --- | --- | --- |
| Scenario Name | The name of the test scenario. | Refer to the above table. |
| Heap Size | The amount of memory allocated to the application | {{ parameters.heap_sizes|join(', ') }} |
| Concurrent Users | The number of users accessing the application at the same time. | {{ parameters.concurrent_users|join(', ') }} |
| GraphQL Query | The GraphQL query number. | {{ parameters.query_numbers|join(', ') }} |
| Back-end Delay (ms) | The delay added by the back-end service. | {{ parameters.backend_sleep_times|join(', ') }} |

The duration of each test is **{{ parameters.test_duration }} seconds**. The warm-up period is **{{ parameters.warmup_time }} seconds**.
The measurement results are collected after the warm-up period.

A [**{{ parameters.wso2am_ec2_instance_type }}** Amazon EC2 instance](https://aws.amazon.com/ec2/instance-types/) was used to install {{ parameters.application_name }}.

The following are the measurements collected from each performance test conducted for a given combination of
test parameters.

| Measurement | Description |
| --- | --- |
| Error % | Percentage of requests with errors |
| Average Response Time (ms) | The average response time of a set of results |
| Standard Deviation of Response Time (ms) | The “Standard Deviation” of the response time. |
| 99th Percentile of Response Time (ms) | 99% of the requests took no more than this time. The remaining samples took at least as long as this |
| Throughput (Requests/sec) | The throughput measured in requests per second. |
| Average Memory Footprint After Full GC (M) | The average memory consumed by the application after a full garbage collection event. |

The following is the summary of performance test results collected for the measurement period.

| {% for column_name in column_names %} {{ column_name }} |{%- endfor %}
| {%- for column_name in column_names %}---{% if not loop.first %}:{% endif%}|{%- endfor %}
{%- for row in rows %}
| {% for column_name in column_names %} {{ row[column_name] }} |{% endfor %}
{%- endfor %}
