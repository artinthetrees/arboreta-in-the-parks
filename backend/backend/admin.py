from django.contrib import admin
from django.contrib.gis import admin as gis_admin
from backend.models import CommunityArea,RestaurantPermit,Tree,Park,Sample

@admin.register(CommunityArea)
class CommunityAreaAdmin(admin.ModelAdmin):
    list_display = ('name','area_id')

@admin.register(RestaurantPermit)
class RestaurantPermitAdmin(gis_admin.GISModelAdmin):
    list_display = ('permit_id', 'permit_type', 'community_area_id','issue_date','issue_year','location')
    list_filter = ('permit_type','community_area_id','issue_date')

@admin.register(Tree)
class TreeAdmin(gis_admin.GISModelAdmin):
    list_display = ('tree_primary_id', 'geom', 'status','family','genus','common_name','dbh_range','crown_condition','added_date','modified_date')
    list_filter = ('status','family','genus','crown_condition','modified_year')

@admin.register(Park)
class ParkAdmin(gis_admin.GISModelAdmin):
    list_display = ('name','park_id', 'geom')
    #list_filter = ('name')

admin.site.register(Sample)


