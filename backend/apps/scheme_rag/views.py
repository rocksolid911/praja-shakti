from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from .models import Scheme
from .serializers import SchemeSerializer


class SchemeViewSet(viewsets.ReadOnlyModelViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = SchemeSerializer
    filterset_fields = ['category', 'is_active', 'ministry']
    search_fields = ['name', 'short_name', 'description']

    def get_queryset(self):
        return Scheme.objects.filter(is_active=True)
