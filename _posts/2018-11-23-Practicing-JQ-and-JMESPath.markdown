---
layout: post
title:  "Practicing JQ and JMESPath"
date:   2018-11-23 05:00:00
categories: learning
tags: jq,jmespath,json,awscli,aws,ssm
---

I was revisiting some of my old scripts, and found this messy piece of code that attempts to grab the latest "minimal" AWS AMI - HVM that's EBS backed:

```
aws --query 'Images[*].[Name,ImageId]' \
  --output text \
  ec2 describe-images \
    --owners amazon \
    --filters \
      "Name=root-device-type,Values=ebs" \
      "Name=architecture,Values=x86_64" \
      "Name=virtualization-type,Values=hvm" \
      "Name=image-type,Values=machine" \
      "Name=is-public,Values=true" | grep minimal
        | sort | tail -n1 | awk '{print $2}'
```

I knew that there is a better way of doing this, but first I wanted to flex my JQ muscles before googling.

### First attempt

One thing I forgot is to sanitize the "query" portion of the previously used command.

Bad command, notice the `--query`:

```
aws --query 'Images[*].[Name,ImageId]' \
  --output json \
  ec2 describe-images \
    --owners amazon \
    --filters \
      "Name=root-device-type,Values=ebs" \
      "Name=architecture,Values=x86_64" \
      "Name=virtualization-type,Values=hvm" \
      "Name=image-type,Values=machine" \
      "Name=is-public,Values=true"
```

Output I had to deal with:
```
[
  [
    "Windows_Server-2008-R2_SP1-English-64Bit-SQL_2012_RTM_SP2_Enterprise-2018.07.11",
    "ami-ffe1e514"
  ],
  [
    "amzn-ami-hvm-2016.03.2.x86_64-ebs",
    "ami-fff61890"
  ]
]
```

Increase of difficulty, for sure, but not impossible to filter the way I want. To re-iterate: I want a single, latest "minimal" Amazon Linux AMI.

This is what I came up with:

```
aws --query 'Images[*].[Name,ImageId]' \
  --output text \
  ec2 describe-images \
    --owners amazon \
    --filters \
      "Name=root-device-type,Values=ebs" \
      "Name=architecture,Values=x86_64" \
      "Name=virtualization-type,Values=hvm" \
      "Name=image-type,Values=machine" \
      "Name=is-public,Values=true" |
        jq -r '
          [
            .[] | select(.[0] | test("^amzn-ami-minimal-hvm")) |
            {
              ami: .[1],
              name: .[0],
              day: (.[0] | match("\\d{8}") | .string)
            }
          ] | sort_by(.day)[-1].ami
        '
```

Translation:

1. Pick elements that pass the regex test over the name leaving us only with Amazon Linux images: `select(.[0] | test("^amzn-ami-minimal-hvm"))`
1. Instead of list of lists, create a list of objects with k/v pairs.
1. Every object of that list of objects will have a new property .day, which I will craft based on the image Name: `day: (.[0] | match("\\d{8}") | .string)`. Value of the "day" property will have the YYYYMMDD format.
1. Sort the remaining list by values of the newly created "day" property: `sort_by(.day)`
1. Select only the value of the .ami property of the last element of the list: `[-1].ami`

This solves my task, but before I got to optimizing JQ, I noticed the malicious `--query`. I was wondering why the pre-JQ AWS CLI output was so sparse!


### Second attempt

Removing the "malicious" `--query` option shows us that the output we have to deal with is substantial:


```
{
  "Images": [
    {
      "Architecture": "x86_64",
      "CreationDate": "2016-06-03T23:22:31.000Z",
      "ImageId": "ami-fff61890",
      "ImageLocation": "amazon/amzn-ami-hvm-2016.03.2.x86_64-ebs",
      "ImageType": "machine",
      "Public": true,
      "OwnerId": "137112412989",
      "State": "available",
      "BlockDeviceMappings": [
        {
          "DeviceName": "/dev/xvda",
          "Ebs": {
            "DeleteOnTermination": true,
            "SnapshotId": "snap-c70259f1",
            "VolumeSize": 8,
            "VolumeType": "standard",
            "Encrypted": false
          }
        }
      ],
      "Description": "Amazon Linux AMI 2016.03.2 x86_64 HVM EBS",
      "Hypervisor": "xen",
      "ImageOwnerAlias": "amazon",
      "Name": "amzn-ami-hvm-2016.03.2.x86_64-ebs",
      "RootDeviceName": "/dev/xvda",
      "RootDeviceType": "ebs",
      "SriovNetSupport": "simple",
      "VirtualizationType": "hvm"
    },
    ...
  ]
}
```

This allowed me to eliminate JQ. The only reason I previously used JQ was because of the ability to extract matches from the `match()` function. I am not aware whether JMESPath can do this. Let's use a proper `--query` this time!

```
aws --output text \
  ec2 describe-images \
    --owners amazon \
    --filters \
      "Name=root-device-type,Values=ebs" \
      "Name=architecture,Values=x86_64" \
      "Name=virtualization-type,Values=hvm" \
      "Name=image-type,Values=machine" \
      "Name=is-public,Values=true" \
      --query '
        Images[?starts_with(ImageLocation,`amazon/amzn-ami-minimal-hvm-`) == `true`] |
        sort_by(@, &CreationDate)[-1:].ImageId
      '
```

Much better, but the execution time is still 5-ish seconds long. I do most of the processing *after* AWS returns a lot of results.

### Google is your friend

The last thing to do was to check whether someone has done it better. [The first result that came up][Amazon blog post on selecting the latest image] was from an AWS blog post on how to do exactly what I was trying to do.

First thing that I was not aware of is that you can use wildcards in the `--filters`, so I improved my last iteration:

```
aws --output text \
  ec2 describe-images \
    --owners amazon \
    --filters \
      "Name=root-device-type,Values=ebs" \
      "Name=architecture,Values=x86_64" \
      "Name=virtualization-type,Values=hvm" \
      "Name=image-type,Values=machine" \
      "Name=is-public,Values=true" \
      "Name=name,Values=amzn-ami-minimal-hvm-*" \
      --query '
        sort_by(Images, &CreationDate)[-1:].ImageId
      '
```

Execution time is now sub-second, and the code is much cleaner. This is thanks to this line: `"Name=name,Values=amzn-ami-minimal-hvm-*"`

However, and this is the second thing I was not aware of, the blog post shows the most deterministic way to get the latest image as per my spec using SSM. That's how I found out about the [AWS SSM Parameter Store][AWS SSM Parameter Store]. Quite handy!

So, the command I ended up going with is this:

```bash
aws ssm get-parameters \
  --names /aws/service/ami-amazon-linux-latest/amzn-ami-minimal-hvm-x86_64-ebs \
  --query 'Parameters[0].[Value]' \
  --output text
```

Google is your friend, but you end up learning a lot by trying things out for yourself :)


[Amazon blog post on selecting the latest image]: https://aws.amazon.com/blogs/compute/query-for-the-latest-amazon-linux-ami-ids-using-aws-systems-manager-parameter-store/]
[AWS SSM Parameter Store]: https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-paramstore.html
