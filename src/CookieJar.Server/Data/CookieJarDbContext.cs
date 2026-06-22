using Microsoft.EntityFrameworkCore;

namespace CookieJar.Server.Data;

public class CookieJarDbContext(DbContextOptions<CookieJarDbContext> options) : DbContext(options)
{
    public DbSet<CookieJarState> CookieJarStates => Set<CookieJarState>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<CookieJarState>().HasData(
            new CookieJarState { Id = 1, Level = 100, LastUpdated = new DateTime(2026, 1, 1, 0, 0, 0, DateTimeKind.Utc) }
        );
    }
}

public record CookieJarState
{
    public int Id { get; set; }
    public int Level { get; set; }
    public DateTime LastUpdated { get; set; }
}
