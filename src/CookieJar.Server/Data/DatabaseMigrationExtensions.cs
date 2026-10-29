using Microsoft.EntityFrameworkCore;

namespace CookieJar.Server.Data;

public static class DatabaseMigrationExtensions
{
    // Any constant works — it only has to be the same for all replicas
    private const long MigrationLockKey = 0x436F6F6B69654A61; // "CookieJa"

    /// <summary>
    /// Runs the migrations under a PostgreSQL advisory lock. With <c>WithReplicas(2)</c> both replicas
    /// start at the same time — the second one waits until the first is done and then finds nothing to do.
    /// </summary>
    public static async Task MigrateWithLockAsync(this WebApplication app, CancellationToken ct = default)
    {
        await using var scope = app.Services.CreateAsyncScope();
        var db = scope.ServiceProvider.GetRequiredService<CookieJarDbContext>();
        var logger = scope.ServiceProvider.GetRequiredService<ILogger<CookieJarDbContext>>();

        // A session-level advisory lock belongs to one connection — keep it open until the unlock
        await db.Database.OpenConnectionAsync(ct);
        try
        {
            await db.Database.ExecuteSqlAsync($"SELECT pg_advisory_lock({MigrationLockKey})", ct);
            logger.LogInformation("Acquired the migration lock");
            try
            {
                await db.Database.MigrateAsync(ct);
            }
            finally
            {
                await db.Database.ExecuteSqlAsync($"SELECT pg_advisory_unlock({MigrationLockKey})", CancellationToken.None);
                logger.LogInformation("Released the migration lock");
            }
        }
        finally
        {
            await db.Database.CloseConnectionAsync();
        }
    }
}
