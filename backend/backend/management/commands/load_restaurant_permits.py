import csv
from datetime import datetime

from django.contrib.gis.geos.error import GEOSException
from django.core.management.base import BaseCommand

from map.models import RestaurantPermit, CommunityArea


class Command(BaseCommand):
    help = "Load restaurant permit data from a CSV file"

    def add_arguments(self, parser):
        parser.add_argument(
            "csv_file", type=str, help="The path to the CSV file to load"
        )

    def handle(self, *args, **kwargs):
        RestaurantPermit.objects.all().delete()

        csv_file = kwargs["csv_file"]

        with open(csv_file, "r") as file:
            reader = csv.DictReader(file)

            for row in reader:
                has_valid_dates = row["application_start_date"] and row["issue_date"]
                if not has_valid_dates or not row["location"]:
                    continue

                try:
                    # handle case where community area is not provided and is an empty string so can't be directly coerced to integer
                    try:
                        ca_int = int(row["community_area"])
                        ca_obj = CommunityArea.objects.get(area_id=ca_int)
                    except:
                        ca_int = None

                    
                    restaurant = RestaurantPermit(
                        permit_id=row["id"],
                        permit_type=row["permit_type"],
                        application_start_date=datetime.fromisoformat(
                            row["application_start_date"]
                        ),
                        issue_date=datetime.fromisoformat(row["issue_date"]),
                        work_description=row["work_description"],
                        street_number=row["street_number"],
                        street_direction=row["street_direction"],
                        street_name=row["street_name"],
                        location=row["location"],
                        #community_area_id=row["community_area"],
                        community_area_id=ca_int,
                    )
                    restaurant.save()

                except GEOSException:
                    self.stdout.write(
                        f'Invalid location for ID {row["id"]}. Skipping...'
                    )
