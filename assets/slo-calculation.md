# Calculating Solution Service Level Objective

The requirement for the web application is that the combined service level objective for all components in the hot path is greater than 99.9%.  The components in the hot path comprise of any service that is used to process user requests to purchase or view tickets.

## Development

With a development environment, network isolation is not used and regionally redundant services are not deployed.  The following services are considered:

| Service                  | Azure SLA |
|:-------------------------|----------:|
| Azure Front Door         | 99.990%   |
| Entra ID                 | 99.990%   |
| Azure App Service        | 99.950%   |
| Azure App Service        | 99.950%   |
| Azure Container Apps     | 99.950%   |
| Azure Container Registry | 99.900%   |
| Azure Cache for Redis    | 99.900%   |
| Azure SQL                | 99.995%   |
| Azure Storage            | 99.900%   |
| Azure Key Vault          | 99.990%   |
| App Configuration        | 99.900%   |
| Azure Service Bus        | 99.900%   |
| **Combined SLA**         | **99.317%** |

## Production

When operating in production, network isolation is used and application resources are deployed to two redundant regions to improve availability. We need to calculate the effective SLO for the shared (hub) services and the regional (spoke) services separately and then combine them.

### Global services

| Service                   | Azure SLA   |
|:--------------------------|------------:|
| Azure Front Door          | 99.9900%    |
| Front Door Private Link   | 99.9900%    |
| Entra ID                  | 99.9900%    |
| Private DNS Zone          | 100.000%    |
| Azure Key Vault           | 99.9900%    |
| Key Vault Private Link    | 99.9900%    |
| Azure Container Registry* | 99.9999%    |
| **Combined global SLO**   | **99.9499%** |

* Note that the Azure Container Registry is deployed in two regions which allows its usual 99.9% SLA to increase to 99.9999% in total.

### Regional services

| Service               | Azure SLA |
|:----------------------|----------:|
| Azure App Service     | 99.950%   |
| - Private Link        | 99.990%   |
| Azure App Service     | 99.950%   |
| - Private Link        | 99.990%   |
| Azure Container App   | 99.950%   |
| - Private Link        | 99.990%   |
| Azure Cache for Redis | 99.900%   |
| - Private Link        | 99.990%   |
| Azure SQL             | 99.995%   |
| - Private Link        | 99.990%   |
| Azure Storage         | 99.900%   |
| - Private Link        | 99.990%   |
| App Configuration     | 99.900%   |
| - Private Link        | 99.990%   |
| Azure Service Bus     | 99.900%   |
| **Combined regional SLO**    | **99.377%** |

### Total production SLO

Because there are two redundant regions, the *total* regional SLO for the two regions combined is calculated as `1 - (1 - SLO)^2` where SLO is the SLO for a single regional spoke deployment. This gives us a total combined regional service SLO of **99.996%**.

This total regional SLO is combined with the global SLO to give the total SLO for the production environment: **99.946%**.

By having redundant resources in two regions, the total SLO for the production environment (99.946%) exceeds the requirement of 99.9%.

For more information on how to calculate effective SLO, please refer to [the Well Architected Framework](https://learn.microsoft.com/azure/well-architected/reliability/metrics).
