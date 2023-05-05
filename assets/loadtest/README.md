## Load Testing

### Jmeter load test

The `api-loadtest.jmx` file is an [Apache Jmeter](https://jmeter.apache.org/) load test script which simulates a user path for purchasing a concert ticket in the Relecloud application. It executes the required backend API calls neccessary to create a user, browse concerts, purchase a ticket, and view the ticket. The `api-loadtest.jmx` can be viewed, modified, and tested locally using the [Jmeter GUI](https://jmeter.apache.org/usermanual/get-started.html#running).

The Jmeter load test script utilizes the following environment variables, which are required to be configured when executing the test locally, or through the Azure Load Test Service:

Environment Variable | Description
--- | ---
apihost | Hostname of the backend API for the Relecloud environment.
virtualusers | Number of threads/virtual users, recommended maximum of 250 per Azure Load Test Engine instance.
rampup_seconds | Time it takes in seconds the test will take to ramp up to desired virtual users.
duration_seconds | Duration in seconds the test will run.
authtoken | Temporary JWT to authenticate requests to API, to be replaced at later time.