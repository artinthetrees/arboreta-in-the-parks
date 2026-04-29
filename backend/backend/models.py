from django.db import models
from django.contrib.gis.db import models as gis_models


class CommunityArea(models.Model):
    name = models.CharField(max_length=32, null=True, blank=True)
    area_id = models.IntegerField(null=False, blank=True, primary_key=True, default=999)

    def __str__(self):
        return self.name.title()


class RestaurantPermit(models.Model):
    permit_id = models.CharField(max_length=16, null=True, blank=True)
    permit_type = models.CharField(max_length=64, null=True, blank=True)
    application_start_date = models.DateField(null=True, blank=True)
    issue_date = models.DateField(null=True, blank=True)
    work_description = models.TextField(null=True, blank=True)
    street_number = models.CharField(max_length=16, null=True, blank=True)
    street_direction = models.CharField(max_length=8, null=True, blank=True)
    street_name = models.CharField(max_length=32, null=True, blank=True)
    location = gis_models.PointField(null=True, blank=True)
    # community_area_id = models.CharField(max_length=2, null=True, blank=True)
    # community_area_id = models.ForeignKey(CommunityArea,on_delete=models.SET_DEFAULT,null=False,default=999)
    community_area = models.ForeignKey(CommunityArea,on_delete=models.SET_NULL,null=True,blank=True,related_name='permits')

    # https://stackoverflow.com/questions/22157437/model-field-based-on-other-fields#:~:text=A%20field%20that%20is%20always,16.5k8%2056%2093
    # https://stackoverflow.com/questions/21740782/django-values-get-year-from-datetimefield
    issue_year = models.PositiveSmallIntegerField(null=True,blank=True)
    application_year = models.PositiveSmallIntegerField(null=True,blank=True)

    def save(self, *args, **kwargs):
        #self.score = self.x + self.y + self.z
        self.issue_year = self.issue_date.year
        self.application_year = self.application_start_date.year
        super(RestaurantPermit, self).save(*args, **kwargs) # Call the "real" save() method.
        self.refresh_from_db()