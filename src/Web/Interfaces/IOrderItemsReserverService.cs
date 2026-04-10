using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;

namespace Microsoft.eShopWeb.Web.Interfaces;

public interface IOrderItemsReserverService
{
    Task SendOrderAsync(Order order);
}
