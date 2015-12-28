---
layout: page
title: Pastedump
permalink: /pd/
---
## Misc

### Test SSL cert for a domain before flipping DNS

{% highlight bash %}
curl https://some.domain.net --resolve some.domain.net:443:1.1.1.1
{% endhighlight %}

Where 1.1.1.1 is the current IP address where the cert we are testing is located.

## JSON & friends

### CFN EBS volume tagging

If you want to tag EC2 instance root volume based on the EC2 instance tag, you can use something like this.

Note: 

* This is script that runs post-stack creation. 
* Stack creates a single instance
* We are using CFN Outputs to get the InstanceID
* This is much better done with cloudformer

{% highlight bash %}
##!/bin/bash

## Known variables
STACKNAME="dgdgssgdgsgsdgsd"
TAGKEY="test"

## Get Instsance ID from $STACKNAME
INSTANCEID=$(aws cloudformation describe-stacks --stack-name $STACKNAME | jq -r '.Stacks[].Outputs[].OutputValue')

## Get Volume ID from $INSTANCEID
VOLUMEID=$(aws ec2 describe-instances --instance-ids $INSTANCEID | jq -r '.Reservations[].Instances[].BlockDeviceMappings[].Ebs.VolumeId')

## Get the tag value based on the key we already know. 
## Use of "--arg" is of interest here. Basically, we assign a JQ variable $TAGKEY with the bash variable $TAGKEY. 
## This is because the JQ expression is in single quotes, and we wouldn't be able to bash-substitute within the brackets.
TAGVALUE=$(aws ec2 describe-instances --instance-ids $INSTANCEID | jq -r --arg TAGKEY $TAGKEY '.Reservations[].Instances[].Tags[] | select(.Key == $TAGKEY) | .Value' )

## Create tag on the volume 
aws ec2 create-tags --resources $VOLUMEID --tags "[ { \"Key\" : \"$TAGKEY\" , \"Value\" : \"$TAGVALUE\" } ]"
{% endhighlight %}

### Fine grained CloudTrail parsing with custom output

Parse large amounts of CT logs:

{% highlight bash %}
cd month1
find . -name '*.gz' | while read line
do
    zcat "$line" |
        jq '.Records[] |
            select(.requestParameters.roleName == "NAME-OF-THE-ROLE-I-WAS-INTERESTED-IN")'
done > out.txt
{% endhighlight %}

Note: I did the above for both months in parallel as CPU (core) was the bottleneck. Doing it for the larger month alone (984MB) took almost 12 minutes.

After this, I parsed individual out.txt files in a few different ways until I was happy with outputting only PutRolePolicy or DeleteRolePolicy, and formatted the output a little bit, in a way it was presentable to the customer:

{% highlight bash %}
cat out.txt| jq '
    select(.eventName ## "PutRolePolicy" or .eventName "DeleteRolePolicy") |
        {
            Policy: .requestParameters.policyName ,
            Time: .eventTime ,
            Action: .eventName,
            ARN: .userIdentity.arn
        } '
{% endhighlight %}


'''Similar to above''', but in one step and using a jq argument (import shell variable). Use case: "Who removed rules from "sg-xxxxxxxx":

{% highlight bash %}
cd month1

SG="sg-xxxxxxxx"

find . -name '*.gz' | while read line
do
    zcat "$line" |
        jq --arg SG $SG '.Records[] |
            select(.requestParameters.groupId == $SG) |
            select(.eventName ## "RevokeSecurityGroupEgress" or .eventName "RevokeSecurityGroupIngress") |
            {
                GroupId: .requestParameters.groupId ,
                Time: .eventTime ,
                Action: .eventName,
                ARN: .userIdentity.arn
            } '
done
{% endhighlight %}

### Adding values via JQ

Script that parses a json, structures it im key: value structure where value is integer.
A friend needed to put a sum at the bottom. My last line in this JQ is what did what he wanted:

{% highlight bash %}
##!/bin/bash

URL="https://example.com/input.json"

FILTER='.data|
        to_entries|
        map(
            select((.key|match("-(str1|str2|str3|(st3(4|5|6)))@literalsuffix")) and (.value["total"] > 0))
        )|
        [
            .[]|
            {"key" : .key,"value" : .value["total"]}
        ]|
        sort|
        from_entries | 
        . + {"Total" : (. |add) }
'

curl -s "$URL" | jq "$FILTER"
{% endhighlight %}

Example output:
{% highlight javascript %}
{
  "str1@literalsuffix": 12,
  "str2@literalsuffix": 12,
  "str3@literalsuffix": 12,
  "str4@literalsuffix": 12,
  "str5@literalsuffix": 12,
  "str6@literalsuffix": 12,
  "Total": 72
}
{% endhighlight %}

### Filter AWS IP ranges by service & region(s)

Requires JQ 1.5:
https://github.com/stedolan/jq/releases

{% highlight bash %}
curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq -r '
                .prefixes[] |
                select ( 
                         (.service | match("EC2")) and 
                         (.region | match("us-east-1|us-west-2")) 
                       ) |
                .ip_prefix'
{% endhighlight %}


### Filter then catenate all CloudTrail gzip logs into one text file with output time sorted

{% highlight bash %}
##!/bin/bash
 
find . -name '*.gz' | while read line
do
    zcat "$line"  | jq '.Records[]
    |
    select(.userIdentity.arn == "arn:aws:sts::000000000000:assumed-role/Something/someguy@whatever.com" )
    '
done | jq -s ' sort_by(.eventTime) '
{% endhighlight %}

### Finding highest offenders

Again, in this example, we try to do as much as possible on each iteration of .gz files to avoid crashing the desktop

{% highlight bash %}
##!/bin/bash

echo "Processing highest API offenders"
 
find . -name '*.gz' | while read line
do
    zcat "$line"  | jq '.Records[]
    |
    (.eventSource + "-" + .eventName)
    '
done | sort | uniq -c | sort -n
{% endhighlight %}

## Database stuff

### MySQL Basics

#### Useful MySQL commands

When creating MySQL users, make sure that your .mysql_history file does not log anything. There are two ways:

* Permanently: ```ln -s /dev/null $HOME/.mysql_history```
* Temporarily: ```MYSQL_HISTFILE=/dev/null && mysql <your parameters here>```

And now for some general tips:

{% highlight mysql %}
## List all users
SELECT User, Host FROM mysql.user;

## Create user
CREATE USER 'jeffrey'@'localhost' IDENTIFIED BY 'mypass';

## Show Grants
SHOW GRANTS FOR 'jeffrey'@'localhost';

## Grant all perms to db1 DB and it's tables:
GRANT ALL ON db1.* TO 'jeffrey'@'localhost';

## Grant select on table invoice of db2:
GRANT SELECT ON db2.invoice TO 'jeffrey'@'localhost';

## No privileges for all databases/tables with rate limiting
GRANT USAGE ON *.* TO 'jeffrey'@'localhost' WITH MAX_QUERIES_PER_HOUR 90;

## Grant, require SSL
GRANT USAGE ON *.* TO 'jeffrey'@'%' REQUIRE SSL ; 

## Common permissions
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE ON `db_jeffrey`.* TO 'jeffrey'@'%' ;

## Change user password
SET PASSWORD FOR user@'host' = PASSWORD('somepass');
{% endhighlight %}

#### SSL for MySQL (RDS example)
{% highlight bash %}
MyPath="/home/myuser/Documents/rds"
mkdir -p "$MyPath"
wget http://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem -O "$MyPath/rds-ssl-ca-cert.pem"
mysql --ssl_ca="$MyPath/rds-ssl-ca-cert.pem" --ssl-verify-server-cert -h <hostname> -P <port> -u <username> -p
## You'll be prompted for the password
{% endhighlight %}

MySQL workbench also supports SSL. When creating a connection go to the Advanced tab and just fill in the CA field. [Relevant RDS doc](http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html#MySQL.Concepts.SSLSupport)

## CloudFormation

### AWS CLI basics

#### Command
{% highlight bash %}aws cloudformation update-stack \
--template-body file://~/Desktop/cfn/ASG-LifeCycle-DelayFirstInstance.cform  \
--capabilities CAPABILITY_IAM \
--parameters file://~/Desktop/cfn/ASG-LifeCycle-DelayFirstInstance.params  \
--stack-name asjdaad4233{% endhighlight %}

#### Example Parameters file
{% highlight javascript %}[
    {
        "ParameterKey": "InstanceAmi",
        "ParameterValue": "ami-xxxxxxx"
    },
    {
        "ParameterKey": "InstanceType",
        "ParameterValue": "t2.micro"
    }
]{% endhighlight %}

## CodeDeploy

### Create a deployment with AWS CLI

{% highlight bash %}
APP="asdad"
DG="dasasdads"
COMMIT="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
REPO="myrepo/codedeploy-app"

aws deploy create-deployment \
--application-name "$APP" \
--deployment-group-name "$DG" \
--github-location commitId="$COMMIT",repository="$REPO"
{% endhighlight %}
