# -*- coding: utf-8 -*-
{
    'name': "HTTPS Override",

    'summary': "Override Odoo's default HTTP behavior to force HTTPS",

    'description': """
        This module forces all URLs within an Odoo instance to  be served over HTTPS without the use of a third party reverse proxy. Only use this module if you are unable to configure your web server to redirect HTTP traffic to HTTPS.
    """,

    'author': "David Codner",
    'website': "https://www.davidcodner.me",

    'category': 'Website',
    'version': '1.0',

    # any module necessary for this one to work correctly
    'depends': ['base'],

    'installable': True,
    'application': False,
    'auto_install': True,
}