# Modern web app pattern for .NET - Plan the implementation
The modern web app pattern provides essential implementation guidance for web apps moving to the cloud. It defines how you should incrementally apply updates (refactor) your web app to be successful in the cloud.

There are two articles on the modern web app pattern for .NET. This article explains important decisions to plan the implementation of the pattern. The companion article provides code and architecture guidance to [apply the pattern](./apply-the-pattern.md). There's a [reference implementation](https://aka.ms/eap/mwa/dotnet) (sample web app) of the pattern that you can deploy.

## Architecture

> ⚠️ The architecture section is pending review - (Multichannel API Capability experience) covered by #1865953

The modern web app pattern is a set of principles with implementation guidance. It's not a specific architecture. Your business context, existing web app, and desired service level objective (SLO) are critical factors that shape the architecture of your web app. The following diagram (figure 1) represents the architecture of the [reference implementation](https://aka.ms/eap/mwa/dotnet). It's one example that illustrates the principles of the modern web app pattern. It's important that your web app adheres to the principles of the modern web app pattern, not necessarily this specific architecture.

![Diagram showing the architecture of the reference implementation.](../docs/images/relecloud-solution-diagram.png)

## Principles and implementation

> ⚠️ The principles and implementation section is pending review - (Multichannel API Capability experience) covered by #1865953

The following table lists the principles of the modern web app pattern and how to implement those principles in your web app. For more information, see the [Modern web app pattern overview](https://aka.ms/eap/mwa/dotnet/doc).

*Table 1. Pattern principles and how to implement them.*

| Modern web app pattern principles | How to implement the principles |
| --- | --- |
| *Modern web app pattern principles:*<br>▪ Mature dev team practices for modern development<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Accelerate feature development with vertical slice development <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Evolutionary design changes instead of re-write<br>▪ Managed services<br>▪ Focused on vertical slice development to support<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Non-functional requirements<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Parallel workstream opportunities<br><br>*Well Architected Framework principles:*<br>▪ Cost optimized<br>▪ Observable<br>▪ Ingress secure<br>▪ Infrastructure as code<br>▪ Identity-centric security|▪ Backends for Frontends pattern <br>▪ Cache-aside pattern <br>▪ Federated Identity pattern<br>▪ Queue-Based Load Leveling pattern<br>▪ Gateway Routing pattern<br>▪ Rate Limiting pattern<br>▪ Strangler Fig pattern <br>▪ Rightsized resources <br>▪ Managed identities <br>▪ Private endpoints <br>▪ Secrets management <br>▪ Bicep deployment <br>▪ Telemetry, logging, monitoring |


## Business scenario

> ⚠️ The business scenario section is pending review - (Multichannel API Capability experience) covered by #1865953

This guide demonstrates how principles from the [Well-Architected Framework](https://docs.microsoft.com/azure/architecture/framework/)
and [Twelve-Factor Applications](https://12factor.net/) can be applied to migrate and modernize a legacy, line-of-business (LOB) web app to the cloud. A reference architecture is included to showcase a production ready solution which can be easily deployed for learning and experimentation.

The reference scenario discussed in this guide is for Relecloud Concerts, a fictional company that sells concert tickets. Their website, currently employee-facing, is an illustrative example of an LOB eCommerce application historically used by call center operators to buy
tickets on behalf of their offline (telephone) customers. Relecloud has experienced increased sales volume over the last quarter with continued
increases projected, and senior leadership has decided to invest more in direct customer sales online instead of expanding call center capacity.

Their call center employee website is a monolithic ASP.NET application with a Microsoft SQL Server database which suffers from common legacy challenges including extended timelines to build and ship new features and difficulty scaling different components of the application under higher load. By applying the changes outlined in the [Modern Web App](https://github.com/Azure/modern-web-app-pattern-dotnet/blob/main/business-scenario.md) Relecloud achieved their first set of objectives to modernize the application to sustain additional volume while maturing development team practices for modern development and operations.

In this phase Relecloud will achieve their intermediate goals such as opening the application directly to online customers through multiple web and mobile experiences, improving availability targets, and scaling different components of the system independently to handle traffic spikes without compromising security. Their goal of significantly reducing the time required to deliver new features to the application will be addressed in the next phase of their journey. In this phase they will build on the Azure solution they have deployed to augment their existing solution with Azure's robust global platform and tremendous managed service capabilities that will support Relecloud's growth objectives for years to come.

Continue to the next section to learn more about the solution architecture, and the recommendations they applied to achieve their goals.

## Existing web app

> ⚠️ The existing web app section is pending review - (Multichannel API Capability experience) covered by #1865953

The existing web app was an on-premises web app migrated to the cloud with the [Reliable Web App pattern](https://aka.ms/eap/rwa/dotnet/doc). The web app is a monolithic ASP.NET web app. It runs an eCommerce, line-of-business web app on two App Service Plans and has a Azure SQL database. The web app is employee-facing. The only application users are Relecloud's call center employees. Relecloud employees use the application to buy tickets on behalf of Relecloud customers. The on-premises web app suffers from common challenges. These challenges include extended timelines to build and ship new features difficulty scaling different components of the application under a higher load.

## Service level objective

> ⚠️ The service level objective section is pending review - (Multichannel API Capability experience) covered by #1865953

A service level objective (SLO) for availability defines how available you want a web app to be for users. You need to define an SLO and what *available* means for your web app. Relecloud has a target SLO of 99.9% for availability, about 8.7 hours of downtime per year. For Relecloud, the web app is available when call center employees can purchase tickets 99.9% of the time. When you have a definition of *available*, list all the dependencies on the critical path of availability. Dependencies should include Azure services and third-party integrations.

## Choose the right services

> ⚠️ The Choose the right services section, and the addition of new Azure services introduced for MWA, is pending review - (Multichannel API Capability experience) covered by #1865953

The Azure services you choose should support your short-term objectives. They should also prepare you to reach any long-term goals. To accomplish both, you should pick services that (1) meet your SLO, (2) require minimal re-platforming effort, and (3) support future modernization plans.

When you move a web app to the cloud, you should select Azure services that mirror key on-premises features. The alignment helps minimize the re-platforming effort. For example, you should keep the same database engine (from SQL Server to Azure SQL Database) and app hosting platform (from IIS on Windows Server to Azure App Service). Containerization of your application typically doesn't meet the short-term objectives of the modern web app pattern, but the application platform you choose now should support containerization if that's a long-term goal.

### Application platform

[Azure App Service](https://learn.microsoft.com/azure/app-service/overview) is an HTTP-based, managed service for hosting web apps, REST APIs, and mobile back ends. Azure has many viable compute options. For more information, see the [compute decision tree](https://learn.microsoft.com/azure/architecture/guide/technology-choices/compute-decision-tree). The web app uses Azure App Service because it meets the following requirements:

- **High SLA.** It has a high SLA that meets the production environment SLO.
- **Reduced management overhead.** It's a fully managed solution that handles scaling, health checks, and load balancing.
- **.NET support.** It supports the version of .NET that the application is written in.
- **Containerization capability.** The web app can converge on the cloud without containerizing, but the application platform also supports containerization without changing Azure services.
- **Autoscaling.** The web app can automatically scale up, down, in, and out based on user traffic and settings.

### Identity management

[Microsoft Entra ID](https://learn.microsoft.com/azure/active-directory/fundamentals/active-directory-whatis) is a cloud-based identity and access management service. It authenticates and authorizes users based on roles that integrate with our application. Microsoft Entra ID provides the application with the following abilities:

- **Authentication and authorization.** The application needs to authenticate and authorize call center employees.
- **Scalable.** It scales to support larger scenarios.
- **User-identity control.** Call center employees can use their existing enterprise identities.
- **Support authorization protocols.** It supports OAuth 2.0 for managed identities and OpenID Connect for future B2C support.

### Database

[Azure SQL Database](https://learn.microsoft.com/azure/azure-sql/azure-sql-iaas-vs-paas-what-is-overview?view=azuresql) is a general-purpose relational database and managed service in that supports relational and spatial data, JSON, spatial, and XML. The web app used SQL Server on-premises, and the team wants to use the existing database schema, stored procedures, and functions. Several SQL products are available on Azure, but the web app uses Azure SQL Database because it meets the following requirements:

- **Reliability.** The general-purpose tier provides a high SLA and multi-region redundancy. It can support a high user load.
- **Reduced management overhead.** It provides a managed SQL database instance.
- **Migration support.** It supports database migration from on-premises SQL Server.
- **Consistency with on-premises configurations.** It supports the existing stored procedures, functions, and views.
- **Resiliency.** It supports backups and point-in-time restore.
- **Expertise and minimal rework.** SQL Database takes advantage of in-house expertise and requires minimal rework.

### Application performance monitoring

[Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview) is a feature of Azure Monitor that provides extensible application performance management (APM) and monitoring for live web apps. The web app uses Application Insights for the following reasons:

- **Anomaly detection.** It automatically detects performance anomalies.
- **Troubleshooting.** It helps you diagnose problems in the running app.
- **Telemetry.** It collects information about how users are using the app and allows you to easily track custom events.
- **Solving an on-premises visibility gap.** The on-premises solution didn't have APM. Application Insights provides easy integration with the application platform and code.

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

- **Reduced management overhead.** It's a fully managed service.
- **Speed and volume.** It has high-data throughput and low latency reads for commonly accessed, slow changing data.
- **Diverse supportability.** It's a unified cache location for all instances of the web app to use.
- **Externalized.** The on-premises application servers performed VM-local caching. This setup didn't offload highly frequented data, and it couldn't invalidate data.
- **Non-sticky sessions.** Externalizing session state supports nonsticky sessions.

### Global load balancer

[Azure Front Door](https://learn.microsoft.com/azure/frontdoor/front-door-overview) is a layer-7 global load balancer that uses the Azure backbone network to route traffic between regions. Relecloud needed to a multi-region architecture to meet their 99.9% SLO. They needed Front Door to provide layer-7 routing between regions. Front Door also provides extra features, such as Web Application Firewall, and positions Relecloud to use a content delivery network. The content delivery network provides site acceleration as the traffic to the web app increases. The web app uses Azure Front Door because it provides the following benefits:

- **Routing flexibility.** It allows the application team to configure ingress needs to support future changes in the application.
- **Traffic acceleration.** It uses anycast to reach the nearest Azure point of presence and find the fastest route to the web app.
- **Custom domains.** It supports custom domain names with flexible domain validation.
- **Health probes.** The application needs intelligent health probe monitoring. Azure Front Door uses responses from the probe to determine the best origin for routing client requests.
- **Monitoring support.** It supports built-in reports with an all-in-one dashboard for both Front Door and security patterns. You can configure alerts that integrate with Azure Monitor. It lets the application log each request and failed health probes.
- **DDoS protection.** It has built-in layer 3-4 DDoS protection.

Azure has several load balancers. Evaluate your current system capabilities and the requirements for the new app running on Azure, and then [choose the best load balancer for your app](https://learn.microsoft.com/azure/architecture/guide/technology-choices/load-balancing-overview).

### Web Application Firewall

[Azure Web Application Firewall](https://learn.microsoft.com/azure/web-application-firewall/overview) helps provide centralized protection of your web apps from common exploits and vulnerabilities. It's built into Azure Front Door and helps prevent malicious attacks close to the attack sources before they enter your virtual network. Web Application Firewall provides the following benefits:

- **Global protection.** It provides improved global web app protection without sacrificing performance.
- **Botnet protection.** The team can monitor and configure to address security concerns from botnets.
- **Parity with on-premises.** The on-premises solution was running behind a web application firewall managed by IT.

### Configuration storage

[Azure App Configuration](https://learn.microsoft.com/azure/azure-app-configuration/overview) is a service for centrally managing application settings and feature flags. The goal is to replace the file-based configuration with a central configuration store that integrates with the application platform and code. App Config provides the following benefits:

- **Flexibility.** It supports feature flags. Feature flags allow users to opt in and out of early preview features in a production environment without redeploying the app.
- **Supports Git pipeline.** The source of truth for configuration data needed to be a Git repository. The pipeline needed to update the data in the central configuration store.
- **Supports managed identities.** It supports managed identities to simplify and help secure the connection to the configuration store.

Review [App Configuration best practices](https://learn.microsoft.com/azure/azure-app-configuration/howto-best-practices#app-configuration-bootstrap) to decide whether this service is a good fit for your app.

### Secrets manager

[Azure Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview) provides centralized storage of application secrets to control their distribution. It supports X.509 certificates, connection strings, and API keys to integrate with third-party services. Managed identities are the preferred solution for intra-Azure service communication, but the application still has secrets to manage. The on-premises web app stored secrets on-premises in code configuration files, but it's a better security practice to externalize secrets. The web app uses Key Vault because it provides the following features:

- **Encryption.** It supports encryption at rest and in transit.
- **Managed identities.** The application services can use managed identities to access the secret store.
- **Monitoring and logging.** It facilitates audit access and generates alerts when stored secrets change.
- **Certificate support.** It supports importing PFX and PEM certificates.
- **Integration.** It provides native integration with the Azure configuration store (App Configuration) and web hosting platform (App Service).

You can incorporate Key Vault in .NET apps by using the [ConfigurationBuilder object](https://learn.microsoft.com/azure/azure-app-configuration/quickstart-dotnet-core-app).


### Endpoint security

[Azure Private Link](https://learn.microsoft.com/azure/private-link/private-link-overview) provides access to PaaS services (such as Azure Cache for Redis and SQL Database) over a private endpoint in your virtual network. Traffic between your virtual network and the service travels across the Microsoft backbone network. Azure DNS with Azure Private Link enables your solution to communicate via an enhanced security link with Azure services like SQL Database. The web app uses Private Link for these reasons:

- **Enhanced security communication.** It lets the application privately access services on the Azure platform and reduces the network footprint of data stores to help protect against data leakage.
- **Minimal effort.** The private endpoints support the web app platform and database platform the web app uses. Both platforms mirror existing on-premises configurations for minimal change.
