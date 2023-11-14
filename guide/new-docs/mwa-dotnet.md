# Modern web app pattern for .NET - Plan the implementation

The modern web app pattern provides implementation guidance for modernizing web apps (refactor) in the cloud. Modernizing a web in the cloud can be challenging. The number of services and design patterns to choose from is overwhelming. It's hard to know the right ones to choose and how to implement them. The modern web app pattern solves this problem.

The modern web app pattern is a set of [principles](mwa-overview.md) to guide your web app modernization. The guidance is applicable to almost every web app and covers architecture and code design. To make the guidance concrete, there's a [reference implementation](https://aka.ms/eap/mwa/dotnet) of the modern web app pattern to guide your implementation.  (*figure 1*).

![Diagram showing the architecture of the reference implementation.](../docs/images/relecloud-solution-diagram.png)

The reference implementation is a production-quality web app that you can be easily deploy for learning and experimentation. It's important that your web app adheres to the principles of the modern web app pattern, not necessarily this specific architecture. Your business scenario, existing web app, and service level objective (SLO) should shape the architecture of your web app.

## Business scenario

> ⚠️ The business scenario section is pending review - (Multichannel API Capability experience) covered by #1865953

The modern web app pattern is applicable to anyone that wants to modernize a monolithic .NET web app in the cloud.

## Existing web app

> ⚠️ The existing web app section is pending review - (Multichannel API Capability experience) covered by #1865953

The web app is a monolithic ASP.NET web app. It started as an on-premises web app but Relecloud migrated it the cloud using the [Reliable Web App pattern](https://aka.ms/eap/rwa/dotnet/doc). It runs an eCommerce, line-of-business web app on two App Service Plans and has a Azure SQL database. The web app is employee-facing. The only application users are Relecloud's call center employees. Relecloud employees use the application to buy tickets on behalf of Relecloud customers. The on-premises web app suffers from common challenges. These challenges include extended timelines to build and ship new features difficulty scaling different components of the application under a higher load.

## Service level objective

> ⚠️ The service level objective section is pending review - (Multichannel API Capability experience) covered by #1865953

A service level objective (SLO) for availability defines how available you want a web app to be for users. You need to define an SLO and what *available* means for your web app. Relecloud has a target SLO of 99.9% for availability, about 8.7 hours of downtime per year. For Relecloud, the web app is available when call center employees can purchase tickets 99.9% of the time. When you have a definition of *available*, list all the dependencies on the critical path of availability. Dependencies should include Azure services and third-party integrations.


## Apply the pattern

The modern web app pattern provides implementation guidance for modernizing web apps (refactor) in the cloud.

> ⚠️ The entire architecture and code section is pending review - (Multichannel API Capability experience) covered by #1865953

The modern web app pattern provides both code and architecture guidance. The guidance is structured around the five pillars of workload design from the Azure Well-Architected Framework. It reinforces the close relationship between code and architecture. This guidance uses the reference implementation architecture to illustrate the principles of the modern web app pattern (*see figure 1*). The modern web app pattern is a set of principles with implementation guidance. It's not a specific architecture. It's important that your web app adheres to the principles of the pattern, not this specific architecture.

![Diagram showing the architecture of the reference implementation.](../docs/images/relecloud-solution-diagram.png)
*Figure 1. The architecture of the reference implementation.*

## Principles and implementation

> ⚠️ The entire principles and implementation section is pending review - (Multichannel API Capability experience) covered by #1865953

The following table lists the principles of the modern web app pattern and how to implement those principles in your web app. For more information, see the [modern web app pattern overview](https://aka.ms/eap/mwa/dotnet/doc).

*Table 1. Pattern principles and how to implement them.*

| Modern web app pattern principles | How to implement the principles |
| --- | --- |
| *Modern web app pattern principles:*<br>▪ Mature dev team practices for modern development<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Accelerate feature development with vertical slice development <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Evolutionary design changes instead of re-write<br>▪ Managed services<br>▪ Focused on vertical slice development to support<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Non-functional requirements<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Parallel workstream opportunities<br><br>*Well Architected Framework principles:*<br>▪ Cost optimized<br>▪ Observable<br>▪ Ingress secure<br>▪ Infrastructure as code<br>▪ Identity-centric security|▪ Backends for Frontends pattern <br>▪ Cache-aside pattern <br>▪ Federated Identity pattern<br>▪ Queue-Based Load Leveling pattern<br>▪ Gateway Routing pattern<br>▪ Rate Limiting pattern<br>▪ Strangler Fig pattern <br>▪ Rightsized resources <br>▪ Managed identities <br>▪ Private endpoints <br>▪ Secrets management <br>▪ Bicep deployment <br>▪ Telemetry, logging, monitoring |

## Evolutionary design changes

> ⚠️ Pending task Strangler Fig discussion - (Queue-based ticket rendering experience) covered by #1864681
> In this section we will describe how the team approached updating the solution without rewriting it as part of the larger conversation for an application that 1) adds new features and 2) is sitting between monolith and microservices.

<!-- #1 Reliability pillar -->
## Reliability

A modern web application is one that is both resilient and available. Resiliency is the ability of the system to recover from failures and continue to function. The goal of resiliency is to return the application to a fully functioning state after a failure occurs. Availability is a measure of whether your users can access your web application when they need to. You should use the Rate Limiting and Queue-Based Load Leveling patterns as steps toward improving application reliability. These design patterns address high throughput scenarios and help your application maximize the reliability features of the cloud.

### Queue-Based Load Leveling pattern

> ⚠️ Pending task Queue-based Load Leveling pattern - (Queue-based ticket rendering experience) covered by  #1865952
> This section will talk about how moving work out of the request processing stream will  create more bandwidth for request throughput by reducing long running operations that tie up CPU, RAM, and network connections. Improved request bandwidth provides additional benefits for scaling, and will smooth out edge case scenarios such as a user buying 20 tickets, that can lead to reliability problems as requests become queued during high throughput scenarios.

### Rate Limiting pattern

> ⚠️ Pending task Rate Limiting pattern - (Multichannel API Capability experience) covered by #1864671

<!-- #2 Security pillar -->
## Security

Cloud applications are often composed of multiple Azure services. Communication between those services needs to be secure. Enforcing secure authentication, authorization, and accounting practices in your application is essential to your security posture. At this phase in the cloud journey, you should use managed identities, secrets management, and private endpoints. Here are the security recommendations for the modern web app pattern.

### Apply Federated Identity pattern for website authentication

> ⚠️ Pending task Document the way Federated Identity Pattern was applied - (Public facing website experience) covered by  #1908023


### Secure Azure resources at the identity layer

> ⚠️ Pending task Document recommended approach for Identity Layer - (Multichannel API Capability experience) covered by  #1865959


### Secure Azure resources with network isolation

> ⚠️ Pending task Queue-based Load Leveling Pattern - (Multichannel API Capability experience) covered by  #1865959


<!-- #3 Cost optimization pillar -->
## Cost optimization

> ⚠️ The entire cost optimization section is pending review - (Business reporting experience) covered by #1865960

Cost optimization principles balance business goals with budget justification to create a cost-effective web application. Cost optimization is about reducing unnecessary expenses and improving operational efficiency. Here are our recommendations for cost optimization. The code changes optimize for horizontal scale to reduce costs rather than optimizing existing business processes. The latter can lead to higher risks.

*Reference implementation:* The checkout process in the reference implementation has a hot path of rendering ticket images during request processing. You can isolate the checkout process to improve cost optimization and performance efficiency, but this change is beyond the scope of the modern web app pattern. You should address it in future modernizations.

### Rightsize resources for each environment

Production environments need SKUs that meet the service level agreements (SLA), features, and scale needed for production. But non-production environments don't normally need the same capabilities. You can optimize costs in non-production environments by using cheaper SKUs that have lower capacity and SLAs. You should consider Azure Dev/Test pricing and Azure Reservations. How or whether you use these cost-saving methods depends on your environment.

**Consider Azure Dev/Test pricing.** Azure Dev/Test pricing gives you access to select Azure services for non-production environments at discounted pricing under the Microsoft Customer Agreement. The plan reduces the costs of running and managing applications in development and testing environments, across a range of Microsoft products. For more information, see [Dev/Test pricing options](https://azure.microsoft.com/pricing/dev-test/#overview).

**Consider Azure Reservations or an Azure savings plan.** You can combine an Azure savings plan with Azure Reservations to optimize compute cost and flexibility. Azure Reservations help you save by committing to one-year or three-year plans for multiple products. The Azure savings plan for compute is the most flexible savings plan. It generates savings on pay-as-you-go prices. Pick a one-year or three-year commitment for compute services, regardless of region, instance size, or operating system. Eligible compute services include virtual machines, dedicated hosts, container instances, Azure Functions Premium, and Azure app services. For more information, see [Azure Reservations](https://learn.microsoft.com/azure/cost-management-billing/reservations/save-compute-costs-reservations) and [Azure savings plans for compute](https://learn.microsoft.com/azure/cost-management-billing/savings-plan/savings-plan-compute-overview).

*Reference implementation:* The reference implementation uses Bicep parameters to trigger resource deployment configurations. One of these parameters tells Azure Resource Manager which SKUs to select. The following code gives Azure Cache for Redis different SKUs for production and non-production environments:

> ⚠️ Pending review of code sample - (Business reporting experience) covered by #1865960
```bicep
var redisCacheSkuName = isProd ? 'Standard' : 'Basic'
var redisCacheFamilyName = isProd ? 'C' : 'C'
var redisCacheCapacity = isProd ? 1 : 0
```

The web app uses the Standard C1 SKU for the production environment and the Basic C0 SKU for the non-production environment. The Basic C0 SKU costs less than the Standard C1 SKU. It provides the behavior needed for testing without the data capacity or availability targets needed for the production environment (see following table). For more information, see [Azure Cache for Redis pricing](https://azure.microsoft.com/pricing/details/cache/).

*Table 2. Reference implementation SKU differences between the development and production environments.*

> ⚠️ Pending review of SKU - (Business reporting experience) covered by #1865960

|   | Standard C1 SKU | Basic C0 SKU|
| --- | --- | --- |
|**SKU Features**| 1-GB cache <br> Dedicated service <br> Availability SLA <br> As many as 1,000 connections |250-MB cache <br> Shared infrastructure <br> No SLA <br> As many as 256 connections

### Automate scaling the environment

You should use autoscale to automate horizontal scaling for production environments. Autoscaling adapts to user demand to save you money. Horizontal scaling automatically increases compute capacity to meet user demand and decreases compute capacity when demand drops. Don't increase the size of your application platform (vertical scaling) to meet frequent changes in demand. It's less cost efficient. For more information, see [Scaling in Azure App Service](https://learn.microsoft.com/azure/app-service/manage-scale-up) and [Autoscale in Microsoft Azure](https://learn.microsoft.com/azure/azure-monitor/autoscale/autoscale-overview).

*Reference implementation:* The reference implementation uses the following configuration in the Bicep template. It creates an autoscale rule for the Azure App Service. The rule scales up to 10 instances and defaults to one instance.

```csharp
resource webAppScaleRule 'Microsoft.Insights/autoscalesettings@2021-05-01-preview' = if (isProd) {
  name: '${resourceToken}-web-plan-autoscale'
  location: location
  properties: {
    targetResourceUri: webAppServicePlan.id
    enabled: true
    profiles: [
      {
        name: 'Auto scale from one to ten'
        capacity: {
          maximum: '10'
          default: '1'
          minimum: '1'
        }
        rules: [
          ...
        ]
      }
    ]
  }
}
```

### Delete non-production environments

Infrastructure as Code (IaC) is often considered an operational best practice, but it's also a way to manage costs. IaC can create and delete entire environments. You should delete non-production environments after hours or during holidays to optimize cost.

### Leverage and reuse resources for shared responsibilities

> ⚠️Pending documentation associated with - (Multichannel API Capability experience) covered by #1908512
> In this section of the guide we would discuss the shared resources in the solution. The decision criteria that were considered and the associated cost savings from having consolidated services and the reduced operational costs associated with management and monitoring a single resource.

<!-- #4 Operational excellence pillar -->
## Operational excellence

A DevOps methodology provides a greater return on investment for application teams in the cloud. IaC is a key tenet of DevOps. The modern web app pattern requires the use of IaC to deploy application infrastructure, configure services, and set up application telemetry. Monitoring operational health requires telemetry to measure security, cost, reliability, and performance gains. The cloud offers built-in features to capture telemetry. When this telemetry is fed into a DevOps framework, it can help you rapidly improve your application.

### Gateway Routing pattern

> ⚠️ Pending implementation and documentation associated with - (Multichannel API Capability experience) covered by #1864679

### Distributed tracing and logging

> ⚠️ Pending implementation and documentation associated with - (Business Reporting experience) covered by #1865961

### Load testing

> ⚠️ Pending implementation and documentation associated with - (Load testing the API experience) covered by #1865967


<!-- #5 Performance efficiency pillar -->
## Performance efficiency

Performance efficiency is the ability of a workload to scale and meet the demands placed on it by users in an efficient manner. In cloud environments, a workload should anticipate increases in demand to meet business requirements. You should use the Cache-Aside pattern to manage application data while improving performance and optimizing costs.

### Apply the Backends for Frontends pattern

> ⚠️ Pending documentation of Backends for Frontends pattern - (Public facing website experience) covered by  #1865974

### Use the Cache-Aside pattern

> ⚠️ Pending documentation of infrastructure cache replaces code cache - (Multichannel API Capability experience) covered by #1865950

### Queue-based Load Leveling pattern

> ⚠️ Pending task Queue-based Load Leveling pattern - (Queue-based ticket rendering experience) covered by  #1865952
> This section will talk about how applying the Queue-based Load leveling pattern changes our scaling paradigm so that we no longer need to plan for peak workloads. Autoscaling provides alignment with user load and Queue-based Load Leveling provides additional smoothing of the resource demands for our solution. This reduces waste by reducing scaling events and helping us plan for our expected consumption in a more consistent approach.

![Diagram that shows the abstraction choices and their impacts on system costs.](../docs/images/choice-of-abstraction.png)

- Learn more by reading about [Consumption and fixed cost models](https://learn.microsoft.com/azure/well-architected/cost/design-price)

## Next steps

You can deploy the reference implementation by following the instructions in the [modern web app pattern for .NET repository](https://aka.ms/eap/mwa/dotnet). The repository has everything you need. Follow the deployment guidelines to deploy the code to Azure and local development. The following resources can help you learn cloud best practices, discover migration tools, and learn about .NET.

**Introduction to web apps on Azure.** For a hands-on introduction to .NET web applications on Azure, see this [guidance for deploying a basic .NET web application](https://github.com/Azure-Samples/app-templates-dotnet-azuresql-appservice).

**Cloud best practices.** For Azure adoption and architectural guidance, see:

- [Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/overview). Can help your organization prepare and execute a strategy to build solutions on Azure.
- [Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/). A set of guiding tenets that can be used to improve the quality of a workload.

For applications that require a higher SLO than the modern web app pattern, see [mission-critical workloads](https://learn.microsoft.com/azure/architecture/framework/mission-critical/mission-critical-overview).

**Migration guidance.** The following tools and resources can help you migrate on-premises resources to Azure.

- [Azure Migrate](https://learn.microsoft.com/azure/migrate/migrate-services-overview) provides a simplified migration, modernization, and optimization service for Azure that handles assessment and migration of web apps, SQL Server, and virtual machines.
- [Azure Database Migration Guides](https://learn.microsoft.com/data-migration/) provides resources for different database types, and different tools designed for your migration scenario.
- [Azure App Service landing zone accelerator](https://learn.microsoft.com/azure/cloud-adoption-framework/scenarios/app-platform/app-services/landing-zone-accelerator) provides guidance for hardening and scaling App Service deployments.

**Upgrading .NET Framework applications.** The reference implementation deploys to an App Service that runs Windows, but it can run on Linux. The App Service Windows platform enables you to move .NET Framework web apps to Azure without upgrading to newer framework versions. For information about Linux App Service plans or new features and performance improvements added to the latest versions of .NET, see the following guidance.

- [Overview of porting from .NET Framework to .NET](https://learn.microsoft.com/dotnet/core/porting/). Get guidance based on your specific type of .NET app.
- [Overview of the .NET Upgrade Assistant](https://learn.microsoft.com/dotnet/core/porting/upgrade-assistant-overview). Learn about a console tool that can help you automate many of the tasks associated with upgrading .NET Framework projects.
- [Migrating from ASP.NET to ASP.NET Core in Visual Studio](https://devblogs.microsoft.com/dotnet/introducing-project-migrations-visual-studio-extension/). Learn about a Visual Studio extension that can help you with incremental migrations of web apps.