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
