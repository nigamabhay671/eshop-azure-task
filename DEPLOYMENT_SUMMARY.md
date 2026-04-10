# eShopOnWeb with OrderItemsReserver - Implementation Summary

## Overview

This implementation integrates an Azure Function-based order reservation service with the eShopOnWeb application. When a customer creates an order through the checkout process, the order details are automatically sent to an Azure Function that uploads the order information as a JSON file to Azure Blob Storage.

## Architecture Diagram

```
┌─────────────────────┐
│   eShopOnWeb Web    │
│   Application       │
└──────────┬──────────┘
           │
           │ POST HTTP Request
           │ (Order Details)
           ↓
┌─────────────────────────────────┐
│ OrderItemsReserverService       │
│ (HTTP Client in Web Project)    │
└──────────┬──────────────────────┘
           │
           │ Sends Order JSON
           ↓
┌─────────────────────────────────┐
│ OrderItemsReserver              │
│ Azure Function (HTTP Triggered) │
└──────────┬──────────────────────┘
           │
           │ Uploads File
           ↓
┌─────────────────────────────────┐
│ Azure Blob Storage              │
│ (orders container)              │
└─────────────────────────────────┘
```

## Project Structure

```
eshop-azure-task/
├── src/
│   ├── ApplicationCore/
│   │   ├── Interfaces/
│   │   │   └── IOrderService.cs (Modified - now returns Order)
│   │   └── Services/
│   │       └── OrderService.cs (Modified - returns created order)
│   ├── Web/
│   │   ├── Interfaces/
│   │   │   └── IOrderItemsReserverService.cs
│   │   ├── Services/
│   │   │   └── OrderItemsReserverService.cs (Enhanced with logging)
│   │   ├── Pages/
│   │   │   └── Basket/
│   │   │       └── Checkout.cshtml.cs (Modified - calls reservation service)
│   │   ├── appsettings.json (Updated - correct config structure)
│   │   └── appsettings.Production.json (New)
│   └── ...
├── OrderItemsReserver/
│   ├── OrderItemsReserver.cs (HTTP-triggered function)
│   ├── Models/
│   │   ├── OrderRequest.cs
│   │   └── OrderItemDto.cs
│   ├── Program.cs (Dependency injection)
│   ├── host.json (Function configuration)
│   ├── local.settings.json (Local development)
│   └── OrderItemsReserver.csproj
├── IMPLEMENTATION_GUIDE.md (Detailed deployment instructions)
└── deploy.ps1 (Automated deployment script)
```

## Key Changes Made

### 1. ApplicationCore Layer

**IOrderService.cs**
```csharp
// Before
Task CreateOrderAsync(int basketId, Address shippingAddress);

// After
Task<Order> CreateOrderAsync(int basketId, Address shippingAddress);
```

**OrderService.cs**
- Now returns the created Order object for use in the web layer

### 2. Web Layer

**IOrderItemsReserverService.cs**
- Added using directive for Order entity
- Defines contract for sending orders to reservation service

**OrderItemsReserverService.cs** (Renamed from "OrderItemsReserverService .cs")
- Added ILogger dependency for comprehensive logging
- Implemented error handling for HTTP requests
- Added null check for configuration
- Logs order submission and errors

**Checkout.cshtml.cs**
- Injected IOrderItemsReserverService
- Modified OnPost to capture returned Order
- Calls `SendOrderAsync(order)` after successful order creation
- Exception handling remains for basket errors

**appsettings.json**
```json
{
  "OrderItemsReserver": {
    "Url": "https://<function-app>.azurewebsites.net/api/OrderItemsReserver?code=<key>"
  }
}
```

### 3. Azure Function Project

**OrderItemsReserver.cs**
- HTTP POST endpoint at `/api/OrderItemsReserver`
- Deserializes incoming JSON to OrderRequest
- Creates "orders" container if it doesn't exist
- Uploads order as JSON with timestamp: `order-{id}-{yyyyMMddHHmmss}.json`
- Returns HTTP 200 OK on success

**Program.cs**
- Configures BlobServiceClient for dependency injection
- Enables Application Insights
- Uses isolated worker model (.NET 10)

## Data Flow

### Request Payload
```json
{
  "orderId": 123,
  "items": [
    {
      "itemId": 1,
      "quantity": 2
    },
    {
      "itemId": 5,
      "quantity": 1
    }
  ]
}
```

### Uploaded File
- **Location**: Azure Blob Storage → `orders` container
- **Name**: `order-123-20260409143025.json`
- **Content**: Same JSON structure as payload

## Deployment Steps

### Quick Start (PowerShell)

1. **Run automated deployment script:**
```powershell
.\deploy.ps1 `
  -ResourceGroupName "eshop-rg" `
  -Location "eastus" `
  -SubscriptionId "<your-subscription-id>" `
  -FunctionAppName "eshop-orders-func" `
  -StorageAccountName "eshopaastorage123" `
  -WebAppName "eshop-web-app" `
  -AppServicePlanName "eshop-asp"
```

2. **Deploy Function App:**
```powershell
cd ..\OrderItemsReserver
func azure functionapp publish eshop-orders-func --build remote
```

3. **Get function key and update config:**
```powershell
$functionKey = az functionapp keys list `
  --name eshop-orders-func `
  --resource-group eshop-rg `
  --query "functionKeys.default" -o tsv

# Use this URL in appsettings.Production.json:
# https://eshop-orders-func.azurewebsites.net/api/OrderItemsReserver?code=$functionKey
```

4. **Deploy Web App:**
```powershell
cd src\Web
dotnet publish -c Release
# Upload publish folder to App Service
```

See `IMPLEMENTATION_GUIDE.md` for detailed step-by-step instructions.

## Testing

### Local Testing
1. Start OrderItemsReserver Function locally:
   ```powershell
   cd ..\OrderItemsReserver
   func start
   ```

2. Update appsettings.json for local testing:
   ```json
   "OrderItemsReserver": {
     "Url": "http://localhost:7071/api/OrderItemsReserver"
   }
   ```

3. Run eShopOnWeb and test checkout flow

### Azure Testing
1. Verify Function App is running:
   ```powershell
   az functionapp show --name eshop-orders-func --resource-group eshop-rg
   ```

2. Check Blob Storage for uploaded files:
   ```powershell
   az storage blob list --container-name orders --account-name eshopaastorage123
   ```

3. Monitor logs in Application Insights

## Configuration

### Local Development (appsettings.json)
```json
{
  "OrderItemsReserver": {
    "Url": "http://localhost:7071/api/OrderItemsReserver"
  }
}
```

### Production (appsettings.Production.json)
```json
{
  "OrderItemsReserver": {
    "Url": "https://<function-app>.azurewebsites.net/api/OrderItemsReserver?code=<function-key>"
  }
}
```

### Azure Function (local.settings.json)
```json
{
  "AzureWebJobsStorage": "DefaultEndpointsProtocol=https;AccountName=<name>;AccountKey=<key>;EndpointSuffix=core.windows.net",
  "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated"
}
```

## Error Handling

The OrderItemsReserverService includes robust error handling:

- **Missing Configuration**: Logs warning and skips reservation if URL not configured
- **HTTP Request Failure**: Logs error and throws exception (prevents order deletion)
- **Unexpected Errors**: Logs detailed error information for debugging

## Logging & Monitoring

### Application Insights Integration
- Function App logs all HTTP requests
- Enabled by default in host.json
- View logs: Azure Portal → Function App → Application Insights

### Custom Logging
- OrderItemsReserverService logs order submission status
- Function logs file upload operations
- All errors captured with context

## Security Best Practices Implemented

✓ Function uses authorization level "Function" (requires function key)
✓ HTTPS required for all communications
✓ Blob container set to private (no public access)
✓ Connection strings not hardcoded
✓ Sensitive data excluded from logging
✓ Exception details logged but not exposed to users

## Performance Considerations

- HTTP call to Function is synchronous (blocking)
- For high-volume scenarios, consider:
  - Async messaging (Service Bus, Event Grid)
  - Retry policies with exponential backoff
  - Batch processing
  - Connection pooling optimization

## Troubleshooting

### Orders not appearing in Blob Storage
1. Check Application Insights for Function errors
2. Verify `AzureWebJobsStorage` connection string in Function App settings
3. Ensure "orders" container exists
4. Check web app logs for OrderItemsReserverService errors

### Function returns 401 Unauthorized
1. Verify function key in URL
2. Check AuthorizationLevel setting in Function attribute
3. Regenerate function key if necessary

### Timeout Issues
1. Check Function App scaling
2. Verify network connectivity
3. Monitor Function execution time in Application Insights

## Definition of Done Checklist

- [x] eShopOnWeb Web project modified
  - [x] Checkout page calls reservation service
  - [x] OrderItemsReserverService implemented
  - [x] Configuration in appsettings.json
  
- [x] OrderItemsReserver Azure Function developed
  - [x] HTTP endpoint operational
  - [x] Blob Storage integration
  - [x] Error handling implemented
  
- [x] Integration working end-to-end
  - [x] Order creation triggers reservation
  - [x] JSON file uploaded to Blob Storage
  - [x] File contains correct order details
  - [x] File naming includes timestamp
  
- [x] Deployment ready
  - [x] Deployment guide created
  - [x] Deployment script provided
  - [x] Configuration templates provided

## Next Steps (Optional Enhancements)

1. **Enhanced Monitoring**
   - Set up alerts for failed uploads
   - Create dashboards for order metrics
   - Implement custom health checks

2. **Improved Resilience**
   - Add retry logic with exponential backoff
   - Implement circuit breaker pattern
   - Use Service Bus for decoupled messaging

3. **Data Enrichment**
   - Add customer information to order JSON
   - Include pricing details
   - Add shipping address

4. **Audit & Compliance**
   - Implement audit logging
   - Archive old files
   - Implement data retention policies

## Support & Documentation

- **Detailed Deployment Guide**: See `IMPLEMENTATION_GUIDE.md`
- **Azure CLI Reference**: `az --version`
- **Azure Functions Docs**: https://docs.microsoft.com/en-us/azure/azure-functions/
- **Azure Storage Docs**: https://docs.microsoft.com/en-us/azure/storage/

---

**Created**: 2026-04-09
**Status**: Ready for Deployment
**Target Framework**: .NET 10
**Azure Services**: App Service, Functions, Blob Storage, Application Insights
