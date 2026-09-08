import csv
from datetime import datetime

from django.contrib.gis.geos.error import GEOSException
from django.core.management.base import BaseCommand

from django.contrib.gis.geos import Point
from backend.models import Tree


class Command(BaseCommand):
    help = "Load tree data from a CSV file"

    def add_arguments(self, parser):
        parser.add_argument(
            "csv_file", type=str, help="The path to the CSV file to load"
        )

    def handle(self, *args, **kwargs):
        Tree.objects.all().delete()

        csv_file = kwargs["csv_file"]

        with open(csv_file, "r") as file:
            reader = csv.DictReader(file)

            for row in reader:
                #has_valid_dates = row["application_start_date"] and row["issue_date"]
                has_valid_location = row["Longitude"] and row["Latitude"]
                if not has_valid_location:
                    continue

                try:

                    try:
                        primary_id_int = int(row["Primary ID"])
                    except:
                        primary_id_int = None

                    # try:
                    #     tree_id_int = int(row["Tree Id"])
                    # except:
                    #     tree_id_int = None

                    # handle case where dbh is not provided and is an empty string so can't be directly coerced to integer or is provided as a float (in this case, round to nearest integer)
                    try:
                        dbh_int = int(round(float(row["DBH"])))
                    except:
                        dbh_int = None

                    try:
                        added_date = datetime.strptime(row["Date Added"], "%m/%d/%Y")
                    except:
                        added_date = None

                    try:
                        modified_date=datetime.strptime(row["Last Modified"], "%m/%d/%Y")
                    except:
                        modified_date = None

                    lat = float(row['Latitude'])
                    lon = float(row['Longitude'])
                    # X = Longitude, Y = Latitude
                    location_point = Point(lon, lat, srid=4326)
                    
                    tree = Tree(
                        
                        tree_primary_id=primary_id_int,
                        #tree_id=tree_id_int,
                        geom=location_point,
                        status=row["Status"],
                        common_name=row["Common Name"],
                        latin_name=row["Latin Name"],
                        family=row["Family"],
                        genus=row["Genus"],
                        dbh=dbh_int,
                        dbh_range=row["DBH Range"],
                        crown_condition=row["Crown Condition"],
                        crown_light_exposure=row["Crown Light Exposure"],
                        added_date=added_date,
                        modified_date=modified_date,
                        
                    )
                    tree.save()

                except GEOSException:
                    self.stdout.write(
                        f'Invalid location for ID {row["Primary ID"]}. Skipping...'
                    )
