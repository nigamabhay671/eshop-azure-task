# In-Memory Database Implementation

## Overview
The eShop Web project is now configured to use Entity Framework Core's In-Memory Database with dummy data for development and testing.

## Configuration

### 1. **appsettings.json** Configuration
```json
"UseOnlyInMemoryDatabase": true
```
This flag controls whether to use in-memory database or SQL Server.

### 2. **Program.cs** Database Setup
```csharp
var useInMemory = builder.Configuration.GetValue<bool>("UseOnlyInMemoryDatabase");

if (useInMemory)
{
    builder.Services.AddDbContext<CatalogContext>(options =>
        options.UseInMemoryDatabase("Catalog"));

    builder.Services.AddDbContext<AppIdentityDbContext>(options =>
        options.UseInMemoryDatabase("Identity"));
}
else
{
    builder.Services.AddDatabaseContexts(builder.Environment, builder.Configuration);
}
```

## Seeding Data

### Catalog Data
The in-memory database is automatically seeded with:

**Catalog Brands:**
- Azure
- .NET
- Visual Studio
- SQL Server
- Other

**Catalog Types:**
- Mug
- T-Shirt
- Sheet
- USB Memory Stick

**Sample Catalog Items (12 products):**
1. .NET Bot Black Sweatshirt - $19.50
2. .NET Black & White Mug - $8.50
3. Prism White T-Shirt - $12.00
4. .NET Foundation Sweatshirt - $12.00
5. Roslyn Red Sheet - $8.50
6. .NET Blue Sweatshirt - $12.00
7. Roslyn Red T-Shirt - $12.00
8. Kudu Purple Sweatshirt - $8.50
9. Cup<T> White Mug - $12.00
10. .NET Foundation Sheet - $12.00
11. Cup<T> Sheet - $8.50
12. Prism White TShirt - $12.00

### Identity/User Data
The in-memory Identity database is automatically seeded with:

**Roles:**
- Administrators
- Product Managers

**Demo Users:**
1. **Regular User**
   - Email: demouser@microsoft.com
   - Password: (see AuthorizationConstants.DEFAULT_PASSWORD)

2. **Product Manager**
   - Email: productmgr@microsoft.com
   - Role: Product Managers
   - Password: (see AuthorizationConstants.DEFAULT_PASSWORD)

3. **Admin User**
   - Email: admin@microsoft.com
   - Role: Administrators
   - Password: (see AuthorizationConstants.DEFAULT_PASSWORD)

## Data Seeding Process

When the application starts with `UseOnlyInMemoryDatabase: true`:

```csharp
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var catalogContext = services.GetRequiredService<CatalogContext>();
    var identityContext = services.GetRequiredService<AppIdentityDbContext>();
    var logger = services.GetRequiredService<ILogger<Program>>();

    if (useInMemory)
    {
        // Seed in-memory database
        await CatalogContextSeed.SeedAsync(catalogContext, logger);

        // Seed Identity database with users and roles
        var userManager = services.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = services.GetRequiredService<RoleManager<IdentityRole>>();
        await AppIdentityDbContextSeed.SeedAsync(identityContext, userManager, roleManager);
    }
    else
    {
        // Seed SQL database
        await app.SeedDatabaseAsync();
    }
}
```

## Benefits

✅ **No SQL Server Required**: Develop without installing SQL Server locally
✅ **Fast Startup**: In-memory database initializes quickly
✅ **Consistent Data**: Same seed data every startup
✅ **Easy Testing**: Perfect for unit and integration tests
✅ **Reversible**: Simply change `UseOnlyInMemoryDatabase` to `false` to use SQL Server

## Switching Back to SQL Server

To use SQL Server instead:

1. Update `appsettings.json`:
```json
"UseOnlyInMemoryDatabase": false
```

2. Ensure connection strings are configured:
```json
"ConnectionStrings": {
    "CatalogConnection": "Server=(localdb)\\mssqllocaldb;...",
    "IdentityConnection": "Server=(localdb)\\mssqllocaldb;..."
}
```

## Related Files

- `src/Web/Program.cs` - Main configuration and seeding logic
- `src/Web/appsettings.json` - Configuration settings
- `src/Infrastructure/Data/CatalogContext.cs` - Catalog DbContext
- `src/Infrastructure/Data/CatalogContextSeed.cs` - Catalog seeding logic
- `src/Infrastructure/Identity/AppIdentityDbContext.cs` - Identity DbContext
- `src/Infrastructure/Identity/AppIdentityDbContextSeed.cs` - Identity seeding logic
