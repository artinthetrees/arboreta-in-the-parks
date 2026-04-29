import json

from django.core.management.base import BaseCommand

from map.models import CommunityArea


class Command(BaseCommand):
    help = "Load restaurant permit data from a CSV file"

    def add_arguments(self, parser):
        parser.add_argument(
            "geojson_file", type=str, help="The path to the GeoJSON file to load"
        )

    def handle(self, *args, **kwargs):
        CommunityArea.objects.all().delete()

        geojson_file = kwargs["geojson_file"]

        with open(geojson_file, "r") as f:
            community_areas = json.load(f)

        community_area_objs = [
            CommunityArea(
                name=c["properties"]["community"], area_id=c["properties"]["area_numbe"]
            )
            for c in community_areas["features"]
        ]

        CommunityArea.objects.bulk_create(community_area_objs)
