import http.server
import random
from prometheus_client import start_http_server
from prometheus_client import Counter

# Prometheus metrics must be defined before they are used.
# Here we define a counter called hello_worlds_total.
# It has a help string of Hello Worlds requested.,
# which will appear on the /metrics page to help you understand what the metric means.

# Metrics are automatically registered with the client library in the default registry.
# A registry is a place where metrics are registered, to be exposed

REQUESTS = Counter('hello_worlds_requests',    'Hello Worlds requested.')
WRONG_REQUESTS = Counter('wrong_requests',     'Wrong Requests received.')
EXCEPTIONS = Counter('hello_world_exceptions', 'Exceptions serving Hello World.')


class MyHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/hello':
            # Increment metric
            REQUESTS.inc()
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'Hello World')

            with EXCEPTIONS.count_exceptions():
               if random.random() < 0.2:
                  raise Exception
        else:
            # Increment metric
            WRONG_REQUESTS.inc()
            self.send_error(404)


if __name__ == "__main__":
    start_http_server(8000)
    server = http.server.HTTPServer(('', 8001), MyHandler)
    print('Prometheus metrics available on port 8000 /metrics')
    print('HTTP serveravailable on port 8001')
    server.serve_forever()
