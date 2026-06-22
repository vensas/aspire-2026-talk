using System.Text;
using System.Text.Json;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace CookieJar.Server.Services;

public class CookieSensorConsumer(
    IConnection rabbitConnection,
    CookieJarService cookieJarService,
    ILogger<CookieSensorConsumer> logger) : BackgroundService
{
    private const string QueueName = "cookie-taken";

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var channel = await rabbitConnection.CreateChannelAsync(cancellationToken: stoppingToken);
        await channel.QueueDeclareAsync(QueueName, durable: true, exclusive: false, autoDelete: false, cancellationToken: stoppingToken);

        var consumer = new AsyncEventingBasicConsumer(channel);
        consumer.ReceivedAsync += async (_, ea) =>
        {
            var body = Encoding.UTF8.GetString(ea.Body.Span);
            var message = JsonSerializer.Deserialize<CookieTakenMessage>(body);
            var amount = message?.Amount ?? 5;

            logger.LogInformation("Cookie taken event received, amount: {Amount}", amount);
            await cookieJarService.TakeCookieAsync(amount);
            await channel.BasicAckAsync(ea.DeliveryTag, multiple: false, cancellationToken: stoppingToken);
        };

        await channel.BasicConsumeAsync(QueueName, autoAck: false, consumer: consumer, cancellationToken: stoppingToken);

        await Task.Delay(Timeout.Infinite, stoppingToken).ConfigureAwait(ConfigureAwaitOptions.SuppressThrowing);

        await channel.CloseAsync(CancellationToken.None);
    }

    private record CookieTakenMessage(int Amount);
}
