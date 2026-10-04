from django.utils.translation import gettext_lazy as _
from rest_framework.authentication import BaseAuthentication
from rest_framework import exceptions
from .models import ChildDevice


class DeviceTokenAuthentication(BaseAuthentication):
    keyword = "DeviceBearer"

    def authenticate(self, request):
        auth = request.META.get("HTTP_AUTHORIZATION", "").strip()
        if not auth:
            return None
        if not auth.lower().startswith(self.keyword.lower() + " "):
            return None
        try:
            raw = auth.split(" ", 1)[1].strip()
        except Exception:
            raise exceptions.AuthenticationFailed(_("Invalid DeviceBearer header."))

        try:
            device_id_str, raw_token = raw.split(":", 1)
        except ValueError:
            raise exceptions.AuthenticationFailed(_("Invalid DeviceBearer format. Expected device_id:raw_token."))

        try:
            from uuid import UUID
            device_id = UUID(device_id_str)
        except Exception:
            raise exceptions.AuthenticationFailed(_("Invalid device id."))

        try:
            device = ChildDevice.objects.get(id=device_id, is_active=True)
        except ChildDevice.DoesNotExist:
            raise exceptions.AuthenticationFailed(_("Invalid device token or inactive device."))

        if not device.verify_device_token(raw_token):
            raise exceptions.AuthenticationFailed(_("Invalid device token or inactive device."))

        device.update_last_seen()
        # Return parent as user and device as auth object
        return (device.parent, device)

    def authenticate_header(self, request):
        return "DeviceBearer"



