import json

from django.core.management.base import BaseCommand
from django.contrib.gis.geos import MultiPolygon,GEOSGeometry

import json

# https://gis.stackexchange.com/questions/311970/load-multipolygons-from-geojson-into-geodjango-model

from backend.models import Park


class Command(BaseCommand):
    help = "Load park data from geojson file"

    def add_arguments(self, parser):
        parser.add_argument(
            "geojson_file", type=str, help="The path to the GeoJSON file to load"
        )

    def handle(self, *args, **kwargs):
        Park.objects.all().delete()

        geojson_file = kwargs["geojson_file"]

        with open(geojson_file, "r") as f:
            parks = json.load(f)

        park_objs = [
            Park(
                name=p["properties"]["park"], 
                park_id=p["properties"]["objectid_1"],
                geom = GEOSGeometry(json.dumps(p['geometry']))
            )
            for p in parks["features"]
        ]

        Park.objects.bulk_create(park_objs)
