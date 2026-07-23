from rest_framework import serializers
from rest_framework_gis.serializers import GeoFeatureModelSerializer

from rest_framework_gis.fields import GeometryField

from backend.models import CommunityArea, RestaurantPermit, Tree, Park
#from .models import CommunityArea, RestaurantPermit

# class TreeSerializer(serializers.ModelSerializer):
#     class Meta:
#         model = Tree
#         fields = '__all__'  # Or specify list of fields like ['id', 'name']

# class TreeSerializer(GeoFeatureModelSerializer):
#     class Meta:
#         model = Tree
#         geo_field = "geom"  # Your PointField name
#         fields = ("id", "status","common_name","dbh_range","crown_condition")

# class TreeDRFSerializer(serializers.ModelSerializer):
#     geom = GeometryField(precision=8)
    
#     class Meta:
#         model = Tree
#         fields = [
#             "id",
#             "status",
#             "common_name",
#             "dbh_range",
#             "crown_condition",
#             "geom",
#         ]

class TreeGeoSerializer(GeoFeatureModelSerializer):
    """ A class to serialize locations as GeoJSON compatible data """

    class Meta:
        model = Tree
        geo_field = "geom"

        # you can also explicitly declare which fields you want to include
        # as with a ModelSerializer.
        fields = ("id","status","common_name","dbh_range","crown_condition")

class ParkGeoSerializer(GeoFeatureModelSerializer):
  contained_trees = serializers.SerializerMethodField()

  class Meta:
    model = Park
    geo_field = "geom"
    fields = ['name', 'contained_trees']

  def get_contained_trees(self, obj):
    trees = Tree.objects.filter(geom__within=obj.geom)
    # This embeds a full GeoJSON FeatureCollection of points inside the properties
    return TreeGeoSerializer(trees, many=True).data

class CommunityAreaSerializer(serializers.ModelSerializer):
    class Meta:
        model = CommunityArea
        fields = ["name", "area_id","num_permits","percent_permits"]

    num_permits = serializers.SerializerMethodField(method_name='get_num_permits')
    percent_permits = serializers.SerializerMethodField(method_name='get_percent_permits')


    def get_num_permits(self, obj):

        current_area_id = obj.area_id
        current_year = self.context["year"]
        restaurant_permits = RestaurantPermit.objects.filter(community_area_id=current_area_id,issue_year=current_year)

        return restaurant_permits.count()

    def get_percent_permits(self,obj):

        # Fetch the restaurant permits associated with the community area using filter
        current_area_id = obj.area_id
        current_year = self.context["year"]
        restaurant_permits = RestaurantPermit.objects.filter(community_area_id=current_area_id,issue_year=current_year)
        restaurant_permits_all = RestaurantPermit.objects.filter(issue_year=current_year)
        
        return 100*(restaurant_permits.count()/restaurant_permits_all.count())   
