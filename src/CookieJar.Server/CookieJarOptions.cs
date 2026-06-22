namespace CookieJar.Server;

public record CookieJarOptions
{
    public const string SectionName = "CookieJar";
    public int Capacity { get; init; } = 100;
}
