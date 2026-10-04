from rest_framework import permissions


class IsAuthenticatedDevice(permissions.BasePermission):
    """
    Permission for device-authenticated requests (DeviceBearer).
    Requires that authentication returned an auth object that is the device instance.
    """
    def has_permission(self, request, view):
        return request.user is not None and request.auth is not None


class IsParentOfDevice(permissions.BasePermission):
    """
    Permission to ensure that the authenticated user (parent) can only access devices they own.
    For object-level checks, expects view to have the device or to check against object.device.parent.
    For general access, can be used in combination with filtering.
    """
    def has_object_permission(self, request, view, obj):
        # obj might be ChildDevice
        if hasattr(obj, "parent"):
            return obj.parent == request.user
        if hasattr(obj, "device") and hasattr(obj.device, "parent"):
            return obj.device.parent == request.user
        return False

    def has_permission(self, request, view):
        # Basic check - object-level filtering should be done in views/querysets
        return request.user and request.user.is_authenticated
