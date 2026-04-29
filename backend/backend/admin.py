from django.contrib import admin
from .models import CommunityArea,RestaurantPermit

@admin.register(CommunityArea)
class CommunityAreaAdmin(admin.ModelAdmin):
    list_display = ('name','area_id')

@admin.register(RestaurantPermit)
class RestaurantPermitAdmin(admin.ModelAdmin):
    list_display = ('permit_id', 'permit_type', 'community_area_id','issue_date','issue_year','location')
    list_filter = ('permit_type','community_area_id','issue_date')


