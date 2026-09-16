terraform {
  backend "s3" {
    #bucket       = "my_tf_state_bucket_name"
    key          = "arboreta-in-the-parks-backend/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}

