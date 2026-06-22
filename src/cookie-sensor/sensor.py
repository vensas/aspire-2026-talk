import os
import time
import random
import json
import pika

rabbitmq_url = os.environ.get("ConnectionStrings__messaging")
if not rabbitmq_url:
    raise RuntimeError("ConnectionStrings__messaging is not set")

print("Cookie sensor starting, connecting to RabbitMQ...")

parameters = pika.URLParameters(rabbitmq_url)
connection = pika.BlockingConnection(parameters)
channel = connection.channel()

channel.queue_declare(queue="cookie-taken", durable=True)

print("Cookie sensor ready, watching the jar...")

try:
    while True:
        delay = random.uniform(2, 10)
        time.sleep(delay)

        amount = random.randint(3, 10)
        message = json.dumps({"Amount": amount})

        channel.basic_publish(
            exchange="",
            routing_key="cookie-taken",
            body=message,
            properties=pika.BasicProperties(delivery_mode=pika.DeliveryMode.Persistent),
        )
        print(f"Cookie taken! Amount: {amount}")
finally:
    connection.close()
