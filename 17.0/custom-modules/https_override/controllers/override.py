from odoo.http import request, Response

class CustomCSPMiddleware:
    def __call__(self, environ, start_response):
        response = request.make_response()
        response.headers['Content-Security-Policy'] = 'upgrade-insecure-requests'
        return response(environ, start_response)

# Add this middleware to your Odoo application
