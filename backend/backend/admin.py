from django.contrib import admin
from backend.models import CommunityArea,RestaurantPermit,Tree

@admin.register(CommunityArea)
class CommunityAreaAdmin(admin.ModelAdmin):
    list_display = ('name','area_id')

@admin.register(RestaurantPermit)
class RestaurantPermitAdmin(admin.ModelAdmin):
    list_display = ('permit_id', 'permit_type', 'community_area_id','issue_date','issue_year','location')
    list_filter = ('permit_type','community_area_id','issue_date')

@admin.register(Tree)
class TreeAdmin(admin.ModelAdmin):
    list_display = ('tree_id', 'geom', 'status','family','genus','common_name','dbh_range','crown_condition','added_year','modified_year')
    list_filter = ('status','family','genus','crown_condition','modified_year')


