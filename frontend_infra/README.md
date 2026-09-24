# Terraform Data
- get route53 zone: zone for domain the ec2 will be on (e.g. rooteddata.org)

# Terraform Resources
- create s3 bucket to host the app/website

- create s3 bucket public access block 
    - apply it to app/website s3 bucket created above
    - buckets are private access only by default but good to be explicit

- create s3 bucket policy
    - apply it to the app/website s3 bucket created above
    - allows only cloudfront distribution we create here to access the s3 bucket

- create cloudfront origin access control
    - apply it to the cloudfront distribution we will create below
    - tells the cloudfront dist to sign traffic it forwards to s3 so that the s3 bucket policy above will recognize that the traffic comes from cloudfront (see [here](https://oneuptime.com/blog/post/2026-02-12-cloudfront-origin-access-control-oac-s3/view))

- create s3 object(s)
    - to upload all frontend static files from npm build to app/website s3 bucket

- create cloudfront distribution
    - will be "in front of" the s3 bucket so that requests to the s3 bucket will be routed through the cloudfront distribution
    - set origin to id of website/app s3 bucket from above
    - set alias to subdomain name you want to use to access the s3 bucket (e.g. app.rooteddata.org)
    - viewer certificate property depends on acm certificate validation resource we create below; this is an implicit "depends on" so that cloudfront distribution will not be created before acm certificate validation is complete and resource is created
    
- request a acm/ssl certificate 
    - request in us-east-1 because cloudfront requires certificate from us-east-1
    - request it for the subdomain that will be used to access the s3 (e.g. app.rooteddata.org)
    - set validation method to dns
    - set create before destory to true

- set up route53 record creation for acm/ssl certificate request validation procedure
    - the request for acm/ssl certificate above will issue a validation challenge that asks me to create a new dns record with a specific value; the certificate authority (acm) will only issue the certificate if the requested dns record is created
    - this set up checks to see which dns record the certificate authority wants me to create and then creates it

- set up acm certificate validation
    - depends on the requested certificate resource from above
    - depends on the route53 record creation for acm/ssl certificate request validation procedure from above
    - created when requested certificate is issued by acm following confirmation of the validation route53 records by acm
    - **ART NOTE**: ssl cert expires every 90 days; with this setup acm handles the renewal in the background

- create a route53 record 
    - A record routing subdomain (e.g. app.rooteddata.org) to domain name of cloudfront distribution from above
    - together the whole setup means that 
        - app.rooteddata.org has an ssl cert, so http or https requests will work
        - app.rooteddata.org routes to cloudfront distribution
        - requests to subdomain (e.g. app.rooteddata.org) are routed to the cloudfront distribution, which in turn sources and caches from the s3
        - requests directly to s3 url will not work

# Terraform Outputs

- cloudfront domain name
- app url

#####################################################################

# Deploy to dev

- Initialize and target the dev S3 bucket
```terraform init -backend-config="environments/dev-backend.tfvars" -reconfigure```

- Run plan using the dev infrastructure variables
```terraform plan -var-file="environments/dev.tfvars"```

- Run apply using the dev infrastructure variables
```terraform apply -var-file="environments/dev.tfvars"```

# Deploy to prod

- Initialize and target the prod S3 bucket
```terraform init -backend-config="environments/prod-backend.tfvars" -reconfigure```

- Run plan using the prod infrastructure variables
```terraform plan -var-file="environments/prod.tfvars"```

- Run apply using the prod infrastructure variables
```terraform apply -var-file="environments/prod.tfvars"```

- To destroy:
```terraform init -backend-config="environments/prod-backend.tfvars" -reconfigure```
```terraform plan -destroy -var-file="environments/prod.tfvars" -out=destroy.tfplan```
```terraform apply destroy.tfplan```

**NOTE:** The -reconfigure flag tells Terraform to ignore any locally cached state settings from your previous run and strictly bind to the new bucket specified in the backend file. This guarantees that you don't accidentally copy or migrate dev state data into your production bucket when switching contexts.

- ran main.tf to create route53 zone for rooteddata.org, and to create records to point apex and www.rooteddata.org to github pages, and to output the nameservers namecheap should point rooteddata.org to at amazon
- after running i need to
    - at namecheap, delete:
        - 4 A records pointing apex (@) to github pages nameservers
        - C record pointing www subdomain (www) to artinthetrees.github.io
        - txt record that proves to github pages that i own the domain (?)
    - at namecheap, add
        - 4 A records pointing apex (@) to aws nameservers per previous step
- 