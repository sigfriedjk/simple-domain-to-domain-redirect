# Simple Domain Redirect

A very simple AWS setup that can redirect one domain to another. Comes with edge caching, redirect from HTTP to HTTPs, and an ACM certificate for HTTPs traffic

### Usage

1. Create an input file: `cp example.tfvars real.tfvars` (real.tfvars is gitignored)
2. Fill in the values in `real.tfvars`; see comments in this file for details
3. `terraform apply -var-file="real.tfvars`

### Requirements
For ease of use, the system requires that a Route 53 hosted zone exists for the domain to redirect **from**. This allows the system to easily create both a record for the redirect, but also DNS validation records in the creation of the certificate.  


### AWS Services
1. CloudFront
2. S3
3. Certificate Manager
4. Route53

### Help
For help finding the hosted zone id, use an AWS CLI like:
```
aws route53 list-hosted-zones
```