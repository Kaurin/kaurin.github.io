---
layout: single
title:  "CFN + ASG + LifeCycle Hooks"
date:   2015-12-27 00:44:34
categories: aws
tags: ["aws","cfn","autoscaling","asg"]
---

Delay CloudFormation's creation of instances in an AutoScalingGroup by leveraging a custom resource

# Problem

When you use CFN to provision an ASG with LifeCycle events which trigger on instance launches, the issue is that CFN first creates an ASG. ASG immediately starts spinning up instances based on ASG settings. LifeCycle hooks get created usually with some delay.  

This causes some instances to get launched without being "monitored" by the "launch" lifecylce hooks.  


# Solution

*   ASG set to 0/0/0 in CFN
*   Custom resource which has "DependsOn" lifecycle resource for instance launches
*   Lambda function which can perform "updateAutoScalingGroup"(called by custom resource)
*   IAM execution role for lambda (as/updateAutoScalingGroup)

# Requirements

Region which supports Lambda  

# CFN command to create stack

{% highlight bash %}
aws cloudformation update-stack \
    --template-body file://ASG-LifeCycle-DelayFirstInstance.cform  \
    --capabilities CAPABILITY_IAM \
    --parameters file://ASG-LifeCycle-DelayFirstInstance.params  \
    --stack-name MyStackName123
{% endhighlight %}

You can just change "create-stack" -> "update-stack" if you want to update the stack instead of create a new one.  

# Files

[Template]({{ site.url }}/assets/2015-12-27-cfn-asg-post/ASG-LifeCycle-DelayFirstInstance.cform) \| [Parameters]({{ site.url }}/assets/2015-12-27-cfn-asg-post/ASG-LifeCycle-DelayFirstInstance.params) \| [Lambda function]({{ site.url }}/assets/2015-12-27-cfn-asg-post/AsgIncrease.zip)

# Note

You need to upload the lambda function zip to an S3 bucket, and then provide bucket name / object name in parameters