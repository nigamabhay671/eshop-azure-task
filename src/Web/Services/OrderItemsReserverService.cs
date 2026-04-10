using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.Web.Interfaces;

namespace Microsoft.eShopWeb.Web.Services;

public class OrderItemsReserverService: IOrderItemsReserverService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _config;
    private readonly ILogger<OrderItemsReserverService> _logger;

    public OrderItemsReserverService(HttpClient httpClient, IConfiguration config, ILogger<OrderItemsReserverService> logger)
    {
        _httpClient = httpClient;
        _config = config;
        _logger = logger;
    }

    public async Task SendOrderAsync(Order order)
    {
        try
        {
            var request = new
            {
                OrderId = order.Id,
                Items = order.OrderItems.Select(x => new
                {
                    ItemId = x.ItemOrdered.CatalogItemId,
                    Quantity = x.Units
                })
            };

            var url = _config["OrderItemsReserver:Url"];

            if (string.IsNullOrEmpty(url))
            {
                _logger.LogWarning("OrderItemsReserver URL is not configured. Skipping order reservation.");
                return;
            }

            _logger.LogInformation("Sending order {OrderId} to reservation service", order.Id);

            var response = await _httpClient.PostAsJsonAsync(url, request);
            response.EnsureSuccessStatusCode();

            _logger.LogInformation("Order {OrderId} successfully sent to reservation service", order.Id);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Failed to send order {OrderId} to reservation service", order.Id);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while sending order {OrderId} to reservation service", order.Id);
            throw;
        }
    }
}

