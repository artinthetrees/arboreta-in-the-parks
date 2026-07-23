"""
URL configuration for backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.1/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""
from django.contrib import admin
from django.urls import path

from backend.views import hello_world, MapDataView, tree_geojson, TreesInParkView, TreesInParksView

urlpatterns = [
    path("trees/",tree_geojson, name="trees"),
    path("trees-in-parks/", TreesInParksView.as_view(), name="trees_in_parks_data"),
    path("trees-in-park/", TreesInParkView.as_view(), name="trees_in_park_data"),
    path("map-data/", MapDataView.as_view(), name="map_data"),
    path('api/hello-world/', hello_world),
    path('admin/', admin.site.urls),
]