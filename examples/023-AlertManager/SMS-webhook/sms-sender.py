import os, sys, re
import http.server
import logging
import ssl
from urllib.parse import urlencode
from urllib import request

from prometheus_client import start_http_server
from prometheus_client import Counter

# Prometheus metrics must be defined before they are used.
# Here we define a counter called hello_worlds_total.
# It has a help string of Hello Worlds requested.,
# which will appear on the /metrics page to help you understand what the metric means.

# Metrics are automatically registered with the client library in the default registry.
# A registry is a place where metrics are registered, to be exposed

REQUESTS = Counter('sms_sender_received_requests',           'SMS Sender received requested.')
WRONG_REQUESTS = Counter('sms_sender_wrong_requests'  ,      'SMS Sender wrong requests')
SUCCEEDED_REQUESTS = Counter('sms_sender_succeeded_requests','SMS Sender succeeded requests')
EXCEPTIONS = Counter('sms_sender_failed_requests',           'SMS Sender failed requests')

###############################################################################
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)
handler = logging.StreamHandler(sys.stdout)
handler.setLevel(logging.DEBUG)

formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)


###############################################################################
class MyHandler(http.server.BaseHTTPRequestHandler):

    ###########################################################################
    def __init__(self, request, client_address, server) :

        self._id = os.getenv('ID')
        self._key = os.getenv('KEY')
        self._routes = {"/send": {"template": "https://smsapi.free-mobile.fr/sendmsg?"}}
        logging.info(f'ROUTES : {self._routes}')
        http.server.BaseHTTPRequestHandler.__init__(self, request, client_address, server)

    ###########################################################################
    # Send message to freemobile service
    def _send_sms(self, msg):
        f = { 'user' : self._id, 'pass' : self._key, 'msg' : msg}
        url = self._routes[self.path]['template']
        logging.info(f'URL base {url}')

        # Encode
        service_url = url + urlencode(f)
        logging.info(service_url)

        # Ignore Certificates (to avoid man in the middle issue)
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

        # Send to freemobile service
        response = request.urlopen(service_url, context=ctx)
        logging.info(f'{response.msg} {response.status}')
        response.close()

    ###########################################################################
    # Handle the POST requests
    def do_POST(self):
        try:
               REQUESTS.inc()
               # Get data size
               content_length = int(self.headers['Content-Length'])
               # Get data
               message = self.rfile.read(content_length)
               # Log request
               logging.info("POST request,\nPath: %s\nHeaders:\n%s\nBody:\n%s\n",
                            str(self.path),
                            str(self.headers),
                            message.decode('utf-8'))

               self._send_sms(message)

               # Return response
               SUCCEEDED_REQUESTS.inc()
               self.send_response(200)
               self.send_header('Content-type', 'text/html')
               self.end_headers()
        except:
            EXCEPTIONS.inc()
            self.send_error(404, "{}".format(sys.exc_info()[0]))
            logging.info(sys.exc_info())

###############################################################################
if __name__ == "__main__":


    logging.info('Starting metrics server [9089]...\n')
    start_http_server(9089)

    logging.info('Starting httpd server [9088]...\n')
    server = http.server.HTTPServer(('', 9088), MyHandler)
    server.serve_forever()
