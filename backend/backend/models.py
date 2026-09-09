from django.db import models
from django.contrib.gis.db import models as gis_models


class CommunityArea(models.Model):
    name = models.CharField(max_length=32, null=True, blank=True)
    area_id = models.IntegerField(null=False, blank=True, primary_key=True, default=999)

    def __str__(self):
        return self.name.title()

class Park(models.Model):
    name = models.CharField(null=True, blank=True)
    park_id = models.IntegerField(null=False, blank=True, primary_key=True, default=999)
    geom = gis_models.MultiPolygonField(null=True,blank=True)

    def __str__(self):
        return self.name.title()
    
class Tree(models.Model):
    tree_primary_id = models.CharField(null=False, blank=True)
    #tree_id = models.CharField(null=False, blank=True)
    geom = gis_models.PointField(null=True, blank=True)
    status = models.CharField(null=True, blank=True)
    common_name = models.CharField(null=True, blank=True)
    latin_name = models.CharField(null=True, blank=True)
    family = models.CharField(null=True, blank=True)
    genus = models.CharField(null=True, blank=True)
    dbh = models.PositiveSmallIntegerField(null=True,blank=True)
    dbh_range = models.CharField(null=True, blank=True)
    crown_condition = models.CharField(null=True, blank=True)
    crown_light_exposure = models.CharField(null=True, blank=True)
    added_date = models.DateField(null=True, blank=True)
    modified_date = models.DateField(null=True, blank=True)
    added_year = models.PositiveSmallIntegerField(null=True,blank=True)
    modified_year = models.PositiveSmallIntegerField(null=True,blank=True)

    def save(self, *args, **kwargs):
        #self.score = self.x + self.y + self.z
        try:
            self.added_year = self.added_date.year
        except:
            self.added_year = None
        
        try:
            self.modified_year = self.modified_date.year
        except:
            self.modified_year = None
        
        # if self.dbh == "":
        #     self.dbh = None
        super(Tree, self).save(*args, **kwargs) # Call the "real" save() method.
        self.refresh_from_db()

    # def clean(self):
    #     # Convert empty string to None before saving/validation
    #     if self.dbh == "":
    #         self.dbh = None
    #     super().clean()

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

class Sample(models.Model):
    attachment = models.FileField()