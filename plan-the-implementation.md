# Placeholder

⚠️ Pending Work Item: 1864743

## Business scenario

* Todo - pending review

This guide demonstrates how principles from the [Well-Architected Framework](https://docs.microsoft.com/azure/architecture/framework/)
and [Twelve-Factor Applications](https://12factor.net/) can be applied to migrate and modernize a legacy, line-of-business (LOB) web app to the cloud. A reference architecture is included to showcase a production ready solution which can be easily deployed for learning and experimentation.

The reference scenario discussed in this guide is for Relecloud Concerts, a fictional company that sells concert tickets. Their website, currently employee-facing, is an illustrative example of an LOB eCommerce application historically used by call center operators to buy
tickets on behalf of their offline (telephone) customers. Relecloud has experienced increased sales volume over the last quarter with continued
increases projected, and senior leadership has decided to invest more in direct customer sales online instead of expanding call center capacity.

Their call center employee website is a monolithic ASP.NET application with a Microsoft SQL Server database which suffers from common legacy challenges including extended timelines to build and ship new features and difficulty scaling different components of the application under higher load. By applying the changes outlined in the [Reliable Web App](https://github.com/Azure/reliable-web-app-pattern-dotnet/blob/main/business-scenario.md) Relecloud achieved their first set of objectives to modernize the application to sustain additional volume while maturing development team practices for modern development and operations.

In this phase Relecloud will achieve their intermediate goals such as opening the application directly to online customers through multiple web and mobile experiences, improving availability targets, and scaling different components of the system independently to handle traffic spikes without compromising security. Their goal of significantly reducing the time required to deliver new features to the application will be addressed in the next phase of their journey. In this phase they will build on the Azure solution they have deployed to augment their existing solution with Azure's robust global platform and tremendous managed service capabilities that will support Relecloud's growth objectives for years to come.

Continue to the next section to learn more about the solution architecture, and the recommendations they applied to achieve their goals.