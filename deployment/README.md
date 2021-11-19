# Deployment

## Overview

This deployment consists of a CDK stack to deploy the MMT application.

## Pre-requisites

**Note:** You **do not** need to create `config/application.yml` or `config/database.yml` as that will be handled automatically by the `Dockerfile`.

If you create a new stage name (e.g. one with your username in it for development), you must add a configuration for it to the `config/application.yml.maap`, `config/database.yml.maap`, and `config/services.yml` files.

You must also create an environment file in `config/environments/`, e.g.:

```bash
cp config/environments/dit.rb config/environments/aimee.rb
```

## Application deployment

### 1. Initial setup

```bash
# Download forked mmt repo
$ git clone https://github.com/MAAP-Project/mmt
# install cdk dependencies
$ cd deployment/mmt
# create python venv and activate
$ pip install -r requirements.txt
$ npm install
```

### 2. CDK bootstrap

**NOTE: This step is only necessary once per AWS account / region combination.**

```bash
AWS_REGION=us-west-2
AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq .Account -r)
npm run cdk bootstrap aws://${AWS_ACCOUNT_ID}/${AWS_REGION}
```

### 3. Populate Secrets and Parameters

First, check if these secrets have been populated in AWS Secrets Manager (`AWS Console -> Systems Manager -> Parameter Store`). If not, create them as below.

Set the `STAGE` variable to the appropriate stage.

```bash
export MMT_STACK_STAGE=dit
export AWS_REGION=us-west-2

aws ssm put-parameter \
    --type "SecureString" \
    --overwrite \
    --name "/${MMT_STACK_STAGE}-maap-mmt/EARTHDATA_PASSWORD" \
    --value "<the password>"

aws ssm put-parameter \
    --type "SecureString" \
    --overwrite \
    --name "/${MMT_STACK_STAGE}-maap-mmt/CMR_URS_PASSWORD" \
    --value "<the password>"

aws ssm put-parameter \
    --type "SecureString" \
    --overwrite \
    --name "/${MMT_STACK_STAGE}-maap-mmt/SECRET_KEY_BASE" \
    --value "<the secret key base>"

aws ssm put-parameter \
    --type "SecureString" \
    --overwrite \
    --name "/${MMT_STACK_STAGE}-maap-mmt/URS_PASSWORD" \
    --value "<the urs password>"

aws ssm put-parameter \
    --type "String" \
    --overwrite \
    --name "/${MMT_STACK_STAGE}-maap-mmt/EARTHDATA_USERNAME" \
    --value "devseed"

aws ssm put-parameter \
    --type "String" \
    --overwrite \
    --name "/${MMT_STACK_STAGE}-maap-mmt/CUMULUS_REST_API" \
    --value "https://1i4283wnch.execute-api.us-east-1.amazonaws.com/dev/"
```

In the `production` environment, these two will use no value for `MMT_STACK_STAGE` in the hostname value (e.g. `cmr.maap-project.org`):

```bash
aws ssm put-parameter \
    --type "String" \
    --overwrite \
    --name "/${MMT_STACK_STAGE}-maap-mmt/CMR_ROOT" \
    --value "cmr.${MMT_STACK_STAGE}.maap-project.org"

aws ssm put-parameter \
    --type "String" \
    --overwrite \
    --name "/${MMT_STACK_STAGE}-maap-mmt/MMT_ROOT" \
    --value "https://mmt.${MMT_STACK_STAGE}.maap-project.org"
```

### 4. Generate CloudFormation template

This step isn't required, but can be useful to just validate that the configuration.

Synthesize the template to validate it basically works.

```bash
export CDK_DEPLOY_ACCOUNT=$(aws sts get-caller-identity | jq .Account -r)
export CDK_DEPLOY_REGION=$(aws configure get region)
npm run cdk synth
```

### 5. Deploy the application

This deploy step will deploy a CloudFormation Stack for the MMT application.

```bash
export CDK_DEPLOY_ACCOUNT=$(aws sts get-caller-identity | jq .Account -r)
export CDK_DEPLOY_REGION=$(aws configure get region)
export MMT_STACK_STAGE="dit"

$ npm run cdk deploy -- --require-approval never
```

The application stack creates a Postgres database, generates a docker image for the application, configures an ECS Task Definition and Service that uses that Task Definition, configures an application load balancer (ALB) to point to the ECS Service, and configures a custom DNS entry for the service.

### Undeploy (optional)

```bash
export CDK_DEPLOY_ACCOUNT=$(aws sts get-caller-identity | jq .Account -r)
export CDK_DEPLOY_REGION=$(aws configure get region)

$ npm run cdk destroy
```

## Developer notes

The route53 permission is added because we do a lookup for the custom domain. The sts:AssumeRote is added
because the Build step fails without it, but I would have
thought it would have been added by default (this issue has been filed about that https://github.com/aws/aws-cdk/issues/16105).
