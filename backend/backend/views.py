from datetime import datetime
import json
  
from django.core.serializers.json import DjangoJSONEncoder
from django.http import JsonResponse

from rest_framework.decorators import api_view
from rest_framework.response import Response

from rest_framework.views import APIView
from rest_framework import viewsets

from django.core.serializers import serialize
from django.http import HttpResponse

from backend.models import CommunityArea, Tree
from backend.serializers import CommunityAreaSerializer

from django.http import HttpResponse

from django.contrib.gis.db.models.functions import AsGeoJSON

from backend.serializers import TreeDRFSerializer


@api_view(['GET'])
def hello_world(request):
    """Hello world endpoint."""
    return Response({'message': f'Hello World: {datetime.now().isoformat()}'})

class MapDataView(APIView):
    def get(self, request):
        community_areas = CommunityArea.objects.all()
        serializer = CommunityAreaSerializer(
            community_areas,
            many=True,
            context={"year": request.query_params.get("year")},
        )
        return Response(serializer.data)
    
# class TreesView(APIView):
#     def get(self, request):
#         trees = Tree.objects.all()
#         serializer = TreeSerializer(
#             trees,
#             many=True,
#         )
#         return Response(serializer.data)

# class TreesView(viewsets.ModelViewSet):
#     queryset = Tree.objects.all()
#     serializer_class = TreeSerializer

class TreeDRFViewSet(viewsets.ModelViewSet):
    queryset = Tree.objects.all()
    serializer_class = TreeDRFSerializer

def tree_geojson(request):
    geojson_data = serialize(
        "geojson", 
        Tree.objects.all(), 
        geometry_field="geom", # Name of your PointField
        fields=("status", "common_name") # Attributes to include
    )
    return HttpResponse(geojson_data, content_type="application/json")    