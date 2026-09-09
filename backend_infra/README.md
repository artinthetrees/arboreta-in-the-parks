# Terraform Data
- get ec2 ssh key pair: name of ec2 ssh key pair already imported manually
- get ec2 ami: latest version of amazon linux 2023 ami
- get vpc: get default vpc for my aws account
- get vpc subnets list: get subsets associated with default vpc for my aws account
- get route53 zone: zone for domain the ec2 will be on (e.g. rooteddata.org)

# Terraform Resources
- create a ec2 security group 
    - ingress: 
        - ssh from anywhere (**ART NOTE**: should change this to just my machine IP for security, though of course it also requires the ssh key file which is on my machine..)
        - http from anywhere (**ART NOTE**: should change this to just my cloudfront distribution for security)
        - https from anywhere (**ART NOTE**: should change this to just my cloudfront distribution for security)
    - egress: 
        - allow all outbound

- create a ec2 instance
    - use ec2 ami from above
    - associate ec2 ssh key pair from above
    - associate ec2 security group from above
    - associate first subnet from vpc subnets list from above

- create a elastic ip
    - bind elastic ip to ec2 instance from above
    - this means the ec2 instance ip will be static

- request a acm/ssl certificate 
    - request in us-east-1 because cloudfront requires certificate from us-east-1
    - request it for the subdomain that will be used to access the ec2 (e.g. backend.rooteddata.org)
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

- create cloudfront distribution
    - will be "in front of" the ec2 instance so that requests to the ec2 will be routed through the cloudfront distribution
    - set origin to ec2 elastic ip address from above
    - set alias to subdomain name you want to use to access the ec2 instance (e.g. backend.rooteddata.org)
    - viewer certificate property depends on acm certificate validation resource from above; this is an implicit "depends on" so that cloudfront distribution will not be created before acm certificate validation is complete and resource is created
    - **ART NOTE**: currently allowed methods include put, post, patch, delete; may want to make this more restrictive for security reasons?

- create a route53 record 
    - A record routing subdomain (e.g. backend.rooteddata.org) to domain name of cloudfront distribution from above
    - together the whole setup means that 
        - backend.rooteddata.org has an ssl cert, so http or https requests will work
        - backend.rooteddata.org routes to cloudfront distribution
        - requests to ec2 elastic ip address or to subdomain (e.g. backend.rooteddata.org) are routed to the cloudfront distribution, which in turn sources and caches from the ec2 

# Terraform Outputs

- ec2 public ip
- cloudfront domain name
- app url

* all of these should route to the app on the ec2
* If you want to secure your application and prevent users from bypassing CloudFront (which exposes your raw Elastic IP and can break Django ALLOWED_HOSTS or host header checks), restrict your EC2 security group's inbound HTTP/HTTPS rules to only accept traffic coming from CloudFront (using managed prefix lists) or place your EC2 instance in a private subnet using a VPC origin. [1] (https://www.reddit.com/r/aws/comments/n0cyc6/hosting_several_apis_on_a_single_ec2_instance_and/), [2] (https://www.reddit.com/r/aws/comments/1jjt0wg/is_there_a_way_to_get_ssl_for_my_ec2_instance/) 





- 
- set up route53 hosted zone for rooteddata.org
    - output nameservers (4)
    - on namecheap, switch from basic dns to custom dns and add the 4 aws nameserver addresses from output above
- create route53 records:
    - A record to direct apex to github pages servers
    - C record to direct www subdomain to github pages
    - **NOTE:** I had to [clear my computer DNS cache and restart](https://support.ucsd.edu/services?id=kb_article_view&sysparm_article=KB0033298) before all of above changes would resolve
    - MX record to direct email to apex domain to google email servers
    - TXT record (spf) to prevent any email server other than google email server from sending from email at apex domain
    - TXT record (DKIM) to prevent any email server other than google email server from sending from email at apex domain

- i only used deploy to prod for this set-up so far

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