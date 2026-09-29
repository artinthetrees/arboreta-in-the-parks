
- helpful: https://londonappdeveloper.com/deploying-django-with-docker-compose/

- in ec2 instance, all docker containers up
    - force re-build, ignoring cache: ```docker-compose -f docker-compose.backend-deploy.yml build --no-cache```
    - stop all containers: ```docker-compose -f docker-compose.backend-deploy.yml down --volumes```
    - create django superuser: ```docker-compose -f docker-compose.backend-deploy.yml run --rm backend sh -c "python manage.py createsuperuser"``` <-- service name
    - build and run all containers: ```docker-compose -f docker-compose.backend-deploy.yml up -d```
    - list all running containers: ```docker ps```
    - get logs for a specific container: ```docker logs arboreta-in-the-parks_proxy_1``` <-- container name


- in local code (then add, commit, push - then pull to ec2) - in deploy docker compose add volume to django app "backend" service to mirror data from ec2 instance to django app "backend" service container
```
volumes:
    - /home/ec2-user/data:/data
```
- in ec2 instance (ssh in) - create the folder in ec2 instance using sudo 
    - first make sure you're in /home/ec2-user/ folder of ec2 then:
```sudo mkdir data```
```sudo mkdir data/raw/```
- in ec2 instance (ssh in) - give ec2-user write access to that folder
    - first make sure you're in /home/ec2-user/ folder of ec2 then:
```sudo chown -R ec2-user /home/ec2-user/data```
- on local command line - secure copy data from local machine to ec2 folder
```
scp -i path_to_private_ssh_key path_to_data_file_on_local ec2-user@ec2_ip_address:path_to_data_folder_on_ec2
```
``` scp -i C:\Users\Andrea\.ssh\id_ed25519_aws C:\Users\Andrea\project-repositories\arboreta-in-the-parks\data\raw\CPD_Parks_20260722.geojson ec2-user@18.118.46.24:/home/ec2-user/data/raw```

- in ec2 instance (ssh in) - check that data is on ec2
    - first make sure you're in /home/ec2-user/ folder of ec2 then:
```ls data/raw/```
- in django app docker container within ec2 instance (ssh in to ec2 instance first, then open docker shell) - check that data is mirrored in django app "backend" service container
```docker exec -it arboreta-in-the-parks_backend_1 bash``` to open container shell
    - this will take you to the backend folder of the container bc it is set as the working dir, so first cd .. to go up a level then: 
```ls data/raw/```
- in ec2 instance (ssh in) - load data
```docker-compose -f docker-compose.backend-deploy.yml run --rm backend sh -c "python manage.py load_trees ../data/raw/20260719_openlands_treeplotter_trees.csv"```

``` docker-compose -f docker-compose.backend-deploy.yml run --rm backend sh -c "python manage.py load_parks ../data/raw/CPD_Parks_20260722.geojson"```

###################
- i needed to destroy and recreate dev ec2 because had to replace ami
- on attempting to ssh into the recreated ec2 i got a security alert - it's happening because the host key associated with the same elastic ip had changed and that could be indicative of a "man in the middle" attack
- to get around this security notice:
```ssh-keygen -f "C:\Users\Andrea\.ssh\known_hosts" -R "ELASTIC_IP"```

###################
- dev frontend
```docker compose -f docker-compose.frontend.yml up --build --watch```
- deploy frontend
```docker compose -f docker-compose.frontend-deploy.yml up --build```

###################
```aws cloudfront create-invalidation --distribution-id CLOUDFRONT_DIST_ID --paths "/*"```

####################

```aws ec2-instance-connect ssh --instance-id i-1234567890abcdef0 --os-user ec2-user```

