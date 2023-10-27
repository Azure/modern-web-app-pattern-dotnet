# Simulating the patterns
Using the following guidance we’ll use Azure Load Testing to measure the web app’s performance and understand the scalability characteristics in the process. In the second part of the test we’ll compare existing performance enhancements with the performance challenge that was solved with Queue-based load leveling. Comparing the results side-by-side demonstrates the performance efficiency achieved by the pattern.

In the next section we’ll evaluate the performance criteria of the web app as it responds to the previously cached data from the API tier by storing data from Azure SQL in Azure Cache for Redis. In this section.

## Simulating the pattern: Queue-Based Load Leveling pattern

> ⚠️ The Queue-Based Load Leveling pattern section is pending review - (Queue-based ticket rendering experience) covered by #1865953
> The intent is to showcase that the site has different behavioral characteristics for the same load profile and that the additional complexity of the pattern is rewarded with cheaper hosting costs (fewer app service instances are needed to respond to the same load pattern) and builds an experience that is more responsive to end-users.

Step 1: Run the load test
Step 2: Observe the results
Step 3: Change a feature flag to toggle "bad" behavior
Step 4: Run the load test
Step 5: Use Azure Load Test platform features to compare behavior

At this point we have a defined baseline and a new load test result which shows the behavioral differences between two approaches. One approach, the first/default one, uses Queue-based load leveling and should have better performance characteristics that we can repeatably highlight with the load test.

## Simulating the pattern: Cache Aside pattern with APIM

> ⚠️ The Cache Aside pattern with APIM section is pending review - (Multichannel API Capability experience) covered by #1865950

Step 1: Run the load test
Step 2: Observe the results
Step 3: Change a behavior of the ConcertDetails page in APIM to cache the result
Step 4: Run the load test
Step 5: Use Azure Load Test platform features to compare behavior

At this point we have a defined baseline and a new load test result which shows the behavioral differences between two approaches. One approach, the first/default one, does not use any caching and the second approach does. The second approach should have better performance characteristics that we can repeatably highlight with the load test.

The intent of this demonstration is to show how an operations team can respond to trends observed in production without changing code.

## Simulating the pattern: End-to-end traceability and Error handling

> ⚠️ The Simulating the pattern: End-to-end traceability and Error handling section is pending review - (Business reporting experience) covered by #1865962

In this scenario we will describe how a reader can use the dashboards, tools, and Application Insights to diagnose a bug in the web app.
