from odoo import http
from odoo.http import request

class HTTPSUpgrade(http.Controller):

    @http.route('/<path:path>', type='http', auth="public", website=True)
    def catch_all(self, path, **kwargs):
        response = request.render(path, **kwargs)

        # Set the Content-Security-Policy header
        response.headers['Content-Security-Policy'] = "upgrade-insecure-requests"

        return response
