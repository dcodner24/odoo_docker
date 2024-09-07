{
    'name': 'HTTPS Upgrade Module',
    'version': '1.0',
    'summary': 'Automatically upgrade HTTP URLs to HTTPS',
    'category': 'Website',
    'description': """
        This module adds a Content Security Policy header to automatically upgrade all HTTP requests to HTTPS.
    """,
    'author': 'Your Name',
    'depends': ['website'],
    'data': [
        'views/header_updates.xml',
    ],
    'installable': True,
    'application': False,
}
