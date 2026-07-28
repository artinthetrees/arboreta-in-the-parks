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

from backend.models import CommunityArea, Tree, Park
from backend.serializers import CommunityAreaSerializer, ParkGeoSerializer, TreeGeoSerializer, ParkNamesSerializer

from django.http import HttpResponse

from django.contrib.gis.db.models.functions import AsGeoJSON

#from backend.serializers import TreeDRFSerializer


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

class TreesInParkView(APIView):
    def get(self, request):
        park_name = request.query_params.get("name")
        print("requested park name: ",park_name)
        #parks = Park.objects.all()
        requested_park = Park.objects.filter(name=park_name)
        print("requested park object: ",requested_park)
        serializer = ParkGeoSerializer(
            requested_park,
            many=True,
        )
        return Response(serializer.data)

class TreesInParksView(APIView):
    def get(self, request):
        parks = Park.objects.all()
        serializer = ParkGeoSerializer(
            parks,
            many=True,
        )
        return Response(serializer.data)
    
class ParkNamesView(APIView):
    def get(self, request):
        parks = Park.objects.all().order_by('name')
        serializer = ParkNamesSerializer(
            parks,
            many=True,
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

# class TreeDRFViewSet(viewsets.ModelViewSet):
#     queryset = Tree.objects.all()
#     serializer_class = TreeDRFSerializer

def tree_geojson(request):
    geojson_data = serialize(
        "geojson", 
        Tree.objects.all(), 
        geometry_field="geom", # Name of your PointField
        fields=("status", "common_name") # Attributes to include
    )
    return HttpResponse(geojson_data, content_type="application/json")    