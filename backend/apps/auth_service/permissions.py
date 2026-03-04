from rest_framework.permissions import BasePermission


class IsLeader(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role in ('leader', 'admin')


class IsAdmin(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'admin'


class IsCitizen(BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'citizen'


class IsNotAnonymous(BasePermission):
    """Deny access to anonymous Firebase users for write operations."""
    message = 'Anonymous users must sign in with a phone number to perform this action.'

    def has_permission(self, request, view):
        if not request.user.is_authenticated:
            return False
        return not getattr(request.user, 'is_anonymous_user', False)
