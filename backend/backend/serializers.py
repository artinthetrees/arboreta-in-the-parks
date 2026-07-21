from rest_framework import serializers

from backend.models import CommunityArea, RestaurantPermit, Tree
#from .models import CommunityArea, RestaurantPermit

class TreeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tree
        fields = '__all__'  # Or specify list of fields like ['id', 'name']

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
