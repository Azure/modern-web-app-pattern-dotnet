targetScope = 'resourceGroup'

/*
** Azure Service Bus
** Copyright (C) 2024 Microsoft, Inc.
** All Rights Reserved
**
***************************************************************************
**
** Creates an Azure Service Bus queue.
*/

// ========================================================================
// PARAMETERS
// ========================================================================

/*
** Common
*/

@description('The name of the primary resource.')
@minLength(1)
@maxLength(260)
param name string

/*
** Dependencies
*/

@description('The name of the Service Bus namespace.')
@minLength(6)
@maxLength(50)
param serviceBusNamespaceName string

/*
** Settings
*/

@description('The maximum size of the queue in megabytes. Default is 1024.')
param maxQueueSizeInMegabytes int = 1024

@description('The maximum size of the message in kilobytes. Default is 1024.')
param maxMessageSizeInKilobytes int = 1024

@description('The number of delivery attempts before a message is moved to the dead letter queue. Default is 10.')
param maxDeliveryCount int = 10

@description('The default time before an idle message is deleted if no time to live is provided in the message. ISO 8601 format. Default is 14 days.')
param defaultMessageTimeToLive string = 'P14D'

@description('The default lock duration for messages. ISO 8601 format. Default is 1 minute.')
param lockDuration string = 'PT1M'

@description('Whether expired messages should be moved to the dead letter queue.')
param enableDeadLetteringOnMessageExpiration bool = false

@description('Whether the queue should monitor messages for duplicates in order to ensure exactly-once delivery.')
param enableDuplicateDetection bool = false

@description('The time window for detecting duplicate messages. ISO 8601 format. Default is 10 minutes.')
param duplicateDetectionHistoryTimeWindow string = 'PT10M'

// ========================================================================
// AZURE RESOURCES
// ========================================================================

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBusNamespaceName
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: name

  properties: {
    maxSizeInMegabytes: maxQueueSizeInMegabytes
    maxMessageSizeInKilobytes: maxMessageSizeInKilobytes
    maxDeliveryCount: maxDeliveryCount
    defaultMessageTimeToLive: defaultMessageTimeToLive
    lockDuration: lockDuration
    deadLetteringOnMessageExpiration: enableDeadLetteringOnMessageExpiration
    requiresDuplicateDetection: enableDuplicateDetection
    duplicateDetectionHistoryTimeWindow: duplicateDetectionHistoryTimeWindow
  }
}

// ========================================================================
// OUTPUTS
// ========================================================================

@description('The ID of the Service Bus queue.')
output id string = serviceBusQueue.id

@description('The Service Bus queue name.')
output name string = serviceBusQueue.name
