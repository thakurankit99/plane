# Django imports
from django.conf import settings


def get_email_logo_url():
    """
    Get the logo URL for email templates.
    Returns the full URL to the AadyaBoard logo.
    """
    web_url = getattr(settings, 'WEB_URL', 'https://jira.aadyatechnovate.com')
    return f"{web_url}/assets/plane-logos/aadya-logo-dark.svg"


def add_logo_to_context(context):
    """
    Add logo_url to the email template context.
    
    Args:
        context (dict): The existing context dictionary
        
    Returns:
        dict: Context with logo_url added
    """
    context['logo_url'] = get_email_logo_url()
    return context
