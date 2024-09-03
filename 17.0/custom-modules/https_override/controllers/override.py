from odoo import http
from werkzeug.utils import redirect

class HttpsRedirectController(http.Controller):

    @http.route('/<path:full_path>', type='http', auth="public", website=True, save_session=False)
    def redirect_to_https(self, full_path, **kwargs):
        # Check if the request is over HTTP
        if http.request.httprequest.environ.get('HTTP_X_FORWARDED_PROTO', 'http') == 'http':
            # Redirect to HTTPS
            url = http.request.httprequest.url.replace('http://', 'https://', 1)
            return redirect(url, code=301)
        # If already on HTTPS, proceed with the request
        return http.request.env['ir.http'].session_info()
