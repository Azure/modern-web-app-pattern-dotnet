# Modern web app pattern for .NET - Plan the implementation

The modern web app pattern provides implementation guidance for modernizing web apps (refactor) in the cloud. Modernizing a web in the cloud can be challenging. The number of services and design patterns to choose from can be overwhelming. It's hard to know the right ones to choose and how to implement them. The modern web app pattern solves this problem.

The modern web app pattern is a set of [principles](mwa-overview.md) to guide your web app modernization. The pattern is applicable to almost every web app and provides a roadmap to overcome the obstacles of web app modernization efforts.

There's a [reference implementation](https://aka.ms/eap/mwa/dotnet) of the modern web app pattern to guide your implementation. The reference implementation is a production-quality web app that you can be easily deploy for learning and experimentation. For context, the guidance follows the journey of a fictional company called Relecloud.

## Architecture

The modern web app pattern uses a hub and spoke architecture. Shared resources are the hub virtual network and application endpoints sit in the spoke virtual network. The modern web app pattern is a set of principles, not a specific architecture. The following diagram (*figure 1*) represents the production architecture of the reference implementation. It's one example that illustrates the principles of the modern web app pattern. Your business context, existing web app, and desired service level objective (SLO) are factors that shape the specific architecture of your web app.

![Diagram showing the production architecture for the reference implementation.](../assets/images/reliable-web-app-dotnet.svg)

## Business context

> ⚠️ The business scenario section is pending review - (Multichannel API Capability experience) covered by #1865953

For business context, the guidance follows the cloud journey of a fictional company called Relecloud. Relecloud sells concert tickets. Their website is currently used by call center operators to buy tickets on behalf of their offline (telephone) customers. Relecloud has experienced increased sales volume over the last quarter with continued increases projected, and senior leadership has decided to invest more in direct customer sales online instead of expanding call center capacity.

*Table 2. Relecloud's short-term and long-term goals.*
|Short-term goals|Long-term goals|
| --- | --- |
|- Open the application directly to online customers <br> - Have multiple web and mobile experiences <br> - Improve availability <br> - Independently scale different components <br> - Maintain security posture <br> | - Reduce feature development time

## Existing web app

> ⚠️ The existing web app section is pending review - (Multichannel API Capability experience) covered by #1865953

The existing web app was an on-premises web app migrated to the cloud with the [Reliable Web App pattern](https://aka.ms/eap/rwa/dotnet/doc). The web app is a monolithic ASP.NET web app. It runs an eCommerce, line-of-business web app on two App Service Plans and has a Azure SQL database. The web app is employee-facing. The only application users are Relecloud's call center employees. Relecloud employees use the application to buy tickets on behalf of Relecloud customers. The on-premises web app suffers from common challenges. These challenges include extended timelines to build and ship new features difficulty scaling different components of the application under a higher load.

## Service level objective

> ⚠️ The service level objective section is pending review - (Multichannel API Capability experience) covered by #1865953

A service level objective (SLO) for availability defines how available you want a web app to be for users. You need to define an SLO and what *available* means for your web app. For example, Relecloud has a target SLO of 99.9% for availability, about 8.7 hours of downtime per year. The definition of *available* for Relecloud is when its call center employees can purchase tickets 99.9% of the time. When you have a definition of *available* for your web app, the next step is to define the critical path of availability. List any dependency that needs to be running for you to meet the web app's definition of *available*. Dependencies should include Azure services and third-party integrations.

For each dependency in the critical path, you need to assign an availability goal. Service level agreements (SLAs) from Azure provide a good starting point. However, SLAs don't factor in (1) downtime that's associated with the application code running on the services (2) deployment and operation methodologies, (3) architecture choices to connect the services. The availability metric you assign to a dependency shouldn't exceed the SLA.

Relecloud used Azure SLAs for Azure services. The following diagram illustrates Relecloud's dependency list with availability goals for each dependency (*see figure 2*).

## Choose the right services

> ⚠️ The Choose the right services section, and the addition of new Azure services introduced for MWA, is pending review - (Multichannel API Capability experience) covered by #1865953

The Azure services you choose should support your short-term and and long-term goals. To accomplish both, you should pick services that (1) meet your immediate business context, (2) SLO requirements, and (3) support future modernization plans.

### Application platform

[Azure App Service](https://learn.microsoft.com/azure/app-service/overview) is an HTTP-based, managed service for hosting web apps, REST APIs, and mobile back ends. Relecloud chose Azure App Service because it meets the following requirements:

- **High SLA.** It has a high SLA that meets the production environment SLO.
- **Reduced management overhead.** It's a fully managed solution that handles scaling, health checks, and load balancing.
- **.NET support.** It supports the version of .NET that the application is written in.
- **Autoscaling.** The web app can automatically scale up, down, in, and out based on user traffic and settings.

Requirements | Azure App Service | Azure Container Apps |
| --- | --- | --- |
| High SLA | &#x2705; | &#x2705; |
| Fully-managed | &#x2705; | &#x2705; |
| .NET support | &#x2705; | &#x2705; |
| Container support | &#x2705; | &#x2705; |
| Autoscaling | &#x2705; | &#x2705; |
| Current platform | &#x2705; | |

For more information, see [Azure compute decision tree](https://learn.microsoft.com/azure/architecture/guide/technology-choices/compute-decision-tree).

### Identity management

[Microsoft Entra ID](https://learn.microsoft.com/azure/active-directory/fundamentals/active-directory-whatis) is a cloud-based identity and access management service. It authenticates and authorizes users based on roles that integrate with our application. Microsoft Entra ID provides the application with the following abilities:

- **Authentication and authorization.** The application needs to authenticate and authorize call center employees.
- **Scalable.** It scales to support larger scenarios.
- **User-identity control.** Call center employees can use their existing enterprise identities.
- **Support authorization protocols.** It supports OAuth 2.0 for managed identities and OpenID Connect for future B2C support.

### Database

[Azure SQL Database](https://learn.microsoft.com/azure/azure-sql/azure-sql-iaas-vs-paas-what-is-overview?view=azuresql) is a general-purpose relational database and managed service in that supports relational and spatial data, JSON, spatial, and XML. The web app uses Azure SQL Database because it meets the following requirements:

- **Reliability.** The general-purpose tier provides a high SLA and multi-region redundancy. It can support a high user load.
- **Reduced management overhead.** It provides a managed SQL database instance.
- **Configuration consistency.** It supports the existing stored procedures, functions, and views.
- **Resiliency.** It supports backups and point-in-time restore.
- **Expertise and minimal rework.** SQL Database takes advantage of in-house expertise and requires minimal rework.

### Application performance monitoring

[Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview) is a feature of Azure Monitor that provides extensible application performance management (APM) and monitoring for live web apps. The web app uses Application Insights for the following reasons:

- **Anomaly detection.** It automatically detects performance anomalies.
- **Troubleshooting.** It helps you diagnose problems in the running app.
- **Telemetry.** It collects information about how users are using the app and allows you to easily track custom events.

Azure Monitor is a comprehensive suite of monitoring tools that collect data from various Azure services. For more information, see:

- [Smart detection in Application Insights](https://learn.microsoft.com/azure/azure-monitor/alerts/proactive-diagnostics)
- [Application Map: Triage distributed applications](https://learn.microsoft.com/azure/azure-monitor/app/app-map?tabs=net)
- [Profile live App Service apps with Application Insights](https://learn.microsoft.com/azure/azure-monitor/profiler/profiler)
- [Usage analysis with Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/usage-overview)
- [Get started with metrics explorer](https://learn.microsoft.com/azure/azure-monitor/essentials/metrics-getting-started)
- [Application Insights Overview dashboard](https://learn.microsoft.com/azure/azure-monitor/app/overview-dashboard)
- [Log queries in Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/logs/log-query-overview)

### Cache

[Azure Cache for Redis](https://learn.microsoft.com/azure/azure-cache-for-redis/cache-overview) is a managed in-memory data store based on the Redis software. The web app's load is heavily skewed toward viewing concerts and venue details. It needs a cache that provides the following benefits:

- **Reduced management overhead.** It's a fully-managed service.
- **Speed and volume.** It has high-data throughput and low latency reads for commonly accessed, slow changing data.
- **Diverse supportability.** It's a unified cache location for all instances of the web app to use.
- **Externalized.** The on-premises application servers performed VM-local caching. This setup didn't offload highly frequented data, and it couldn't invalidate data.
- **Non-sticky sessions.** Externalizing session state supports nonsticky sessions.

### Global load balancer

[Azure Front Door](https://learn.microsoft.com/azure/frontdoor/front-door-overview) is a layer-7 global load balancer that uses the Azure backbone network to route traffic between regions. Relecloud uses Azure Front Door because it provides the following benefits:

- **Cross-region routing.** Front Door provides layer-7 routing between regions. Relecloud needed to a multi-region architecture to meet their 99.9% SLO.
- **Content delivery network.** Front Door positions Relecloud to use a content delivery network. The content delivery network provides site acceleration as the traffic to the web app increases.
- **Routing flexibility.** It allows the application team to configure ingress needs to support future changes in the application.
- **Traffic acceleration.** It uses anycast to reach the nearest Azure point of presence and find the fastest route to the web app.
- **Custom domains.** It supports custom domain names with flexible domain validation.
- **Health probes.** The application needs intelligent health probe monitoring. Azure Front Door uses responses from the probe to determine the best origin for routing client requests.
- **Monitoring support.** It supports built-in reports with an all-in-one dashboard for both Front Door and security patterns. You can configure alerts that integrate with Azure Monitor. It lets the application log each request and failed health probes.
- **Web application firewall.** Front Door integrates natively with Azure Web Application Firewall.
- **DDoS protection.** It has built-in layer 3-4 DDoS protection.

Azure has several load balancers. Evaluate your current system capabilities and the requirements for the new app running on Azure, and then [choose the best load balancer for your app](https://learn.microsoft.com/azure/architecture/guide/technology-choices/load-balancing-overview).

### Web Application Firewall

[Azure Web Application Firewall](https://learn.microsoft.com/azure/web-application-firewall/overview) helps provide centralized protection of your web apps from common exploits and vulnerabilities. It's built into Azure Front Door and helps prevent malicious attacks close to the attack sources before they enter your virtual network. Web Application Firewall provides the following benefits:

- **Global protection.** It provides improved global web app protection without sacrificing performance.
- **Botnet protection.** The team can monitor and configure to address security concerns from botnets.

### Configuration storage

[Azure App Configuration](https://learn.microsoft.com/azure/azure-app-configuration/overview) is a service for centrally managing application settings and feature flags. App Config provides the following benefits:

- **Flexibility.** It supports feature flags. Feature flags allow users to opt in and out of early preview features in a production environment without redeploying the app.
- **Supports Git pipeline.** The source of truth for configuration data needed to be a Git repository. The pipeline needed to update the data in the central configuration store.
- **Supports managed identities.** It supports managed identities to simplify and help secure the connection to the configuration store.

Review [App Configuration best practices](https://learn.microsoft.com/azure/azure-app-configuration/howto-best-practices#app-configuration-bootstrap) to decide whether this service is a good fit for your app.

### Secrets manager

[Azure Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview) provides centralized storage of application secrets to control their distribution. The web app uses Key Vault because it provides the following features:

- **Encryption.** It supports encryption at rest and in transit.
- **Managed identities.** The application services can use managed identities to access the secret store.
- **Monitoring and logging.** It facilitates audit access and generates alerts when stored secrets change.
- **Certificate support.** It supports importing PFX and PEM certificates.
- **Integration.** It provides native integration with the Azure configuration store (App Configuration) and web hosting platform (App Service).

You can incorporate Key Vault in .NET apps by using the [ConfigurationBuilder object](https://learn.microsoft.com/azure/azure-app-configuration/quickstart-dotnet-core-app).

### Endpoint security

[Azure Private Link](https://learn.microsoft.com/azure/private-link/private-link-overview) provides access to PaaS services (such as Azure Cache for Redis and SQL Database) over a private endpoint in your virtual network. Traffic between your virtual network and the service travels across the Microsoft backbone network. The web app uses Private Link for these reasons:

- **Enhanced security communication.** It lets the application privately access services on the Azure platform and reduces the network footprint of data stores to help protect against data leakage.
- **Minimal effort.** The private endpoints support the web app platform and database platform the web app uses.
