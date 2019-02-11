#!/bin/bash

#_=''

if [ $# -ne 7 ]
then

	echo "Provide only six positional parameters"
	exit 1

fi

if [ -z $1 ]
then
	echo "Provide valid Image-id"
	exit 1
fi


if [ -z $2 ]
then
	echo "Provide valid Key-name"
	exit 1
fi


if [ -z $3 ]
then
	echo "Provide valid Security-Group"
	exit 1
fi


if [ -z $4 ]
then
    echo "Provide Instance Count"
	exit 1
fi


if [ -z $5 ]
then
	echo "Provide valid ELB-name"
	exit 1
fi


if [ -z $6 ]
then
	echo "Provide valid S3-bucket-name"
	exit 1
fi

if [ -z $7 ]
then
	echo "Provide valid IAM Role"
	exit 1
fi

############

echo "creating RDS"

groupid=`aws ec2 describe-security-groups --group-names $3 --query "SecurityGroups[*].GroupId" --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

temprdsval=`aws rds create-db-instance --allocated-storage 5 --backup-retention-period 1 --db-instance-class db.t2.micro --db-instance-identifier bhavin-mp2-db --engine mysql --master-username dbuser --master-user-password dbpassword --availability-zone us-west-2b --vpc-security-group-ids $groupid`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

echo "Waiting for RDS to be available"

aws rds wait db-instance-available --db-instance-identifier bhavin-mp2-db

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

rdsDBAddress=`aws rds describe-db-instances --db-instance-identifier bhavin-mp2-db --filters '[{"Name": "db-instance-id","Values": ["bhavin-mp2-db"]}]' --query "DBInstances[*].Endpoint.Address" --output text`


echo $rdsDBAddress

echo "RDS created"


############

#Creating read replica for DBInstances

echo "Creating Read Replica for DB"

temprdsreplica=`aws rds create-db-instance-read-replica --db-instance-identifier bhavin-mp2-db-read --source-db-instance-identifier bhavin-mp2-db`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

echo "Waiting for RDS Replica to be available"

aws rds wait db-instance-available --db-instance-identifier bhavin-mp2-db-read

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

#This is required for safety

aws rds wait db-instance-available --db-instance-identifier bhavin-mp2-db

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

rdsreplicaDBAddress=`aws rds describe-db-instances --db-instance-identifier bhavin-mp2-db --filters '[{"Name": "db-instance-id","Values": ["bhavin-mp2-db-read"]}]' --query "DBInstances[*].Endpoint.Address" --output text`


echo $rdsreplicaDBAddress

echo "DB Read Replica created"


############

#Creating SQS

echo "Creating SQS"

queueName=`aws sqs create-queue --queue-name bpatel68-sqs-mp2-msg --query 'QueueUrl' --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

sleep 5

echo "SQS Created"

############

#Creating S3 bucket-name

echo "Creating S3 bucket"

aws s3api create-bucket --bucket $6 --acl public-read --region us-west-2 --create-bucket-configuration LocationConstraint=us-west-2

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

aws s3api wait bucket-exists --bucket $6

echo "Bucket Created"

############

echo "Open ports 3306-db and 3000-node and 6379-redis"

aws ec2 authorize-security-group-ingress --group-name $3 --protocol tcp --port 3306 --cidr 0.0.0.0/0 > /dev/null 2>&1

aws ec2 authorize-security-group-ingress --group-name $3 --protocol tcp --port 3000 --cidr 0.0.0.0/0 > /dev/null 2>&1

aws ec2 authorize-security-group-ingress --group-name $3 --protocol tcp --port 6379 --cidr 0.0.0.0/0 > /dev/null 2>&1

############

#Creating ElastiCache

echo "Creating ElastiCache"

elastioutput=`aws elasticache create-cache-cluster --cache-cluster-id bpatel68-mp3-cache --preferred-availability-zone us-west-2b --engine redis --num-cache-nodes 1 --cache-node-type cache.t1.micro --security-group-ids $groupid`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi


echo "Waiting for Cache to be Available"

aws elasticache wait cache-cluster-available --cache-cluster-id bpatel68-mp3-cache


echo "ElastiCache Redis Created"


############


#Create EC2 Instance

#InstanceIdList=`aws ec2 run-instances --image-id $1 --count $4 --instance-type t2.micro --key-name $2 --security-groups $3 --query 'Instances[*].InstanceId' --output text`

InstanceIdList=`aws ec2 run-instances --image-id $1 --count $4 --instance-type t2.micro --key-name $2 --security-groups $3 --iam-instance-profile Name=$7 --placement AvailabilityZone=us-west-2b --user-data "file://./create-env-mp3.sh" --query 'Instances[*].InstanceId' --output text` 

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

echo "Created Instances $InstanceIdList"

declare -a arrInstanceList=(${InstanceIdList})
# get length of an arrInstanceList
arrInstanceListLength=${#arrInstanceList[@]}

#Fetch Instance Ids in a variable if required

#aws ec2 describe-instances --filters '[{"Name": "image-id", "Values": ["'$1'"]},{"Name": "instance-state-name","Values": ["pending"] }]' --query 'Reservations[*].Instances[*].InstanceId' --output text

############


#Creating tags for created instances to identify later on

aws ec2 create-tags --resources $InstanceIdList --tags Key="InstanceOwnerStudent",Value="A20410380"

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi


#Wait command to check if instances are running


echo "Waiting for instances to run."
aws ec2 wait instance-running --instance-ids $InstanceIdList

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

############

#Creating EBS Volumes

echo "Creating Volumnes"

for (( i=1; i<${arrInstanceListLength}+1; i++ ));
do
  echo "Creating and attaching Volume for Instance ID ${arrInstanceList[$i-1]}"
  
  volumeId=`aws ec2 create-volume --availability-zone us-west-2b --size 10 --tag-specifications 'ResourceType=volume, Tags=[{Key=InstanceOwnerStudent,Value=A20410380}]' --query 'VolumeId' --output text`
  
  if [ "$?" -ne "0" ]
  then
	echo "Terminate Script"
	exit 1;
  fi
  
  aws ec2 wait volume-available --volume-ids $volumeId
  
  if [ "$?" -ne "0" ]
  then
	echo "Terminate Script"
	exit 1;
  fi
  
  tempebsval=`aws ec2 attach-volume --volume-id $volumeId --instance-id ${arrInstanceList[$i-1]} --device /dev/xvdh`  
  
  if [ "$?" -ne "0" ]
  then
	echo "Terminate Script"
	exit 1;
  fi
  
  echo "Volume Created and attached for Instance ID ${arrInstanceList[$i-1]}"
  
done

############

echo "Instances are running. Waiting for System status ok and Instance status ok."


#Wait command to check if system status is ok

aws ec2 wait system-status-ok --instance-ids $InstanceIdList
echo "system status ok"

#Wait command to check if instance status is ok

aws ec2 wait instance-status-ok --instance-ids $InstanceIdList
echo "Instance status ok"



############

echo "Creating Load balancer now."

#Create load balancer


#aws elb create-load-balancer --load-balancer-name $5 --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --availability-zones us-west-2b --security-groups $groupid

loadBalUrl=`aws elb create-load-balancer --load-balancer-name $5 --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --availability-zones us-west-2b --security-groups $groupid --query 'DNSName' --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

aws elb create-load-balancer-listeners --load-balancer-name $5 --listeners "Protocol=TCP,LoadBalancerPort=3000,InstanceProtocol=TCP,InstancePort=3000"

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

############


#Creating tags for load balancer

aws elb add-tags --load-balancer-name $5 --tags "Key=InstanceOwnerStudent,Value=A20410380"

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi


echo "Load balancer created. Registering instances now."

#aws elb configure-health-check --load-balancer-name $5 --health-check Target=TCP:80,Interval=30,UnhealthyThreshold=10,HealthyThreshold=10,Timeout=5

############

#Registering instances with load balancer

aws elb register-instances-with-load-balancer --load-balancer-name $5 --instances $InstanceIdList

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

echo "Instances registered with load balancer."

############

#Create stickiness policy


aws elb create-lb-cookie-stickiness-policy --load-balancer-name $5 --policy-name $5-cookie-policy --cookie-expiration-period 60

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

echo "stickiness policy created"

############

#Apply stickiness policy

aws elb set-load-balancer-policies-of-listener --load-balancer-name $5 --load-balancer-port 80 --policy-names $5-cookie-policy

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

echo "Stickiness policy applied to load balancer."


############

#Creating Auto Scaling Group

#Create Launch Configuration

echo "Creating launch configurations"

aws autoscaling create-launch-configuration --launch-configuration-name bhavin-mp3-launch-config --key-name $2 --image-id $1 --security-groups $3 --instance-type t2.micro --user-data "file://./create-env-mp3.sh" --iam-instance-profile $7 --block-device-mappings "[{\"DeviceName\": \"/dev/xvdh\",\"Ebs\":{\"VolumeSize\":10}}]"

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

echo "Launch configurations created"

#Create auto scaling group-ids

echo "Creating auto scaling group"

aws autoscaling create-auto-scaling-group --auto-scaling-group-name bhavin-mp3-auto-scaling --launch-configuration-name bhavin-mp3-launch-config --load-balancer-names $5 --health-check-type ELB --health-check-grace-period 120 --min-size 2 --max-size 6 --desired-capacity 3 --default-cooldown 300 --availability-zones us-west-2b

echo "Auto scaling group created"


############

#Creating standalone instance for job processing

jobInstanceid=`aws ec2 run-instances --image-id $1 --count 1 --instance-type t2.micro --key-name $2 --security-groups $3 --iam-instance-profile Name=$7 --placement AvailabilityZone=us-west-2b --user-data "file://./create-env-mp3-standalone.sh" --query 'Instances[*].InstanceId' --output text`

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

echo "Waiting for standalone instance to run."
aws ec2 wait instance-running --instance-ids $jobInstanceid

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

echo "standalone is running. Waiting for System status ok and Instance status ok."

aws ec2 wait system-status-ok --instance-ids $jobInstanceid
echo "standalone system status ok"

aws ec2 wait instance-status-ok --instance-ids $jobInstanceid
echo "standalone Instance status ok"

############

#Waiting for Success message from Load Balancer

echo "Waiting for instances to be in service."

aws elb wait instance-in-service --load-balancer-name $5 --instances $InstanceIdList

if [ "$?" -ne "0" ]
then
	echo "Terminate Script"
	exit 1;
fi

echo "Load Balancer is Up now. Please use below URL."
echo $loadBalUrl":3000/messages"

echo "End of Create Script"