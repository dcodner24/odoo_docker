# -*- coding: utf-8 -*-
{
    'name': "HTTPS Override",

    'summary': "Modify all responses to include the 'upgrade-insecure-requests' Content-Security-Policy header.",

    'description': """
    This module allows for mixed content to be served over HTTPS by adding the 'upgrade-insecure-requests' Content-Security-Policy header to all responses.""",

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