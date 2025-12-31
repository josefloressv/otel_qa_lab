
import random
from bs4 import BeautifulSoup
from locust import HttpUser, task, between
from faker import Faker

from opentelemetry import trace
from opentelemetry.semconv.trace import SpanAttributes
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

# Setup the TracerProvider which is the main entry to the tracing API.
provider = TracerProvider()

# Set up the exporter that sends the trace data to an OpenTelemetry collector.
# OTLPSpanExporter uses the OpenTelemetry Protocol over HTTP.
processor = BatchSpanProcessor(OTLPSpanExporter())

# The BatchSpanProcessor gathers spans and batches them for efficient sending.
provider.add_span_processor(processor)

# Set the global default TracerProvider. This is a necessary step to make the created Tracer available globally.
trace.set_tracer_provider(provider)

# Get a Tracer instance from the global TracerProvider. This is used to start manual spans.
tracer = trace.get_tracer("simulate.tracer")

class WebsiteUser(HttpUser):
    wait_time = between(5, 10)

    @task
    def index_page(self):
        # Start a manual span named "index_page".
        with tracer.start_as_current_span("index_page") as index_page:
            # Attach standard attributes to the span to provide context about the operation.
            index_page.set_attribute(SpanAttributes.HTTP_METHOD, "GET")
            index_page.set_attribute(SpanAttributes.HTTP_URL, "/")

            response = self.client.get("/")

            # Create a nested span to provide granularity on the "extract_links" operation.
            with tracer.start_as_current_span("extract_links") as extract_links:
                soup = BeautifulSoup(response.text, "lxml")
                links = [a['href'] for a in soup.select("ul.menu.simple li a") if '/user/' in a['href']]

                # Attach a custom attribute to the span.
                extract_links.set_attribute('extracted.links', len(links))

                with tracer.start_as_current_span("user_selection") as user_selection:
                    if links:
                        user_detail = random.choice(links)
                        user_selection.set_attribute(SpanAttributes.HTTP_METHOD, "GET")
                        user_selection.set_attribute(SpanAttributes.HTTP_URL, "/")
                        user_selection.set_attribute("selected.link", user_detail)
                        self.client.get(user_detail)

    @task
    def post(self):
        # Start a manual span named "post_page". 
        # This describes the operations involved with posting a new post with the API.
        with tracer.start_as_current_span("post_page") as post_page:
            fake = Faker(['ja_JP']) 
            # Attach standard attributes to the span to provide context about the operation.
            post_page.set_attribute(SpanAttributes.HTTP_METHOD, "POST")
            post_page.set_attribute(SpanAttributes.HTTP_URL, "/post")

            gen_data = { 'title': fake.sentence(), "user_id": random.randint(1, 100), "content": fake.text() }
            response = self.client.post("/post", data=gen_data)

            # Attach standard and custom attributes to the span.
            post_page.set_attribute(SpanAttributes.HTTP_STATUS_CODE, response.status_code)
            post_page.set_attribute("user.id", gen_data["user_id"])
            post_page.set_attribute("post.length", len(gen_data["content"]))


