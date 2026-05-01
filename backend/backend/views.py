from datetime import datetime

from rest_framework.decorators import api_view
from rest_framework.response import Response

from rest_framework.views import APIView

from backend.models import CommunityArea
from backend.serializers import CommunityAreaSerializer


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