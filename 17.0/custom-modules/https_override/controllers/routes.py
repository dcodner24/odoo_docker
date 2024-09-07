from odoo import http
from odoo.http import request

class HTTPSUpgrade(http.Controller):

    @http.route('/', type='http', auth='public', website=True)
    @http.route('/<path:path>', type='http', auth='public', website=True)
    def catch_all(self, path=None, **kwargs):
        response = request.render(path, **kwargs)
        response.headers['Content-Security-Policy'] = "upgrade-insecure-requests"
        return response
